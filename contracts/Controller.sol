//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./libraries/StringUtils.sol";
import "./Registrar.sol";

contract Controller {
    using StringUtils for string;
    using ECDSA for bytes32;

    Registrar private registrar;
    uint256 public immutable commitTime;
    uint256 public immutable durationTime;
    uint256 public immutable ethPerLen;
    uint8 public immutable maxNameLength;

    mapping(bytes32 => uint256) internal _commitments;
    mapping(bytes32 => uint256) internal _lockedAmounts;

    event Committed(bytes32 commitment);
    event Registered(
        uint256 indexed id,
        address indexed owner,
        uint256 expires,
        address payer,
        uint256 price
    );
    event Renewed(
        uint256 indexed id,
        uint256 expires,
        address payer,
        uint256 price
    );

    constructor(
        Registrar _registrar,
        uint256 _commitTime,
        uint256 _durationTime,
        uint256 _ethPerLen,
        uint8 _maxNameLength
    ) {
        registrar = _registrar;
        commitTime = _commitTime;
        durationTime = _durationTime;
        ethPerLen = _ethPerLen;
        maxNameLength = _maxNameLength;
    }

    /**
     * @dev getFeePrice used to calculate fee price for vanity name
     * @param name a vanity name parameter for fee calculation
     * @return calculated fee price
     */
    function getFeePrice(string calldata name) public view returns (uint256) {
        uint256 length = name.strlen();
        require(length >= maxNameLength, "VC: Length too short");
        return name.strlen() * ethPerLen;
    }

    function _getNameKey(string calldata name) internal pure returns (bytes32) {
        return keccak256(bytes(name));
    }

    function _getTokenId(string calldata name) internal pure returns (uint256) {
        return uint256(_getNameKey(name));
    }

    function _createLockHash(string calldata name, address owner)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_getNameKey(name), owner));
    }

    function _createCommitment(
        string calldata name,
        address owner,
        bytes32 secret
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_getNameKey(name), owner, secret));
    }

    function _consumeCommitment(string calldata name, bytes32 commitment)
        internal
        returns (uint256)
    {
        require(
            _commitments[commitment] + commitTime >= block.timestamp,
            "VC: Commit expired"
        );

        require(registrar.available(_getTokenId(name)), "VC: Not available");

        delete (_commitments[commitment]);

        uint256 price = getFeePrice(name);
        require(msg.value >= price, "VC: Not enough amount");

        return price;
    }

    function _refund(uint256 amount) internal {
        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        }
    }

    function commit(bytes32 commitment) public {
        require(
            _commitments[commitment] + commitTime < block.timestamp,
            "VC: Already reserved"
        );
        _commitments[commitment] = block.timestamp;
        emit Committed(commitment);
    }

    function register(
        string calldata name,
        address owner,
        bytes32 secret
    ) external payable {
        bytes32 commitment = _createCommitment(name, owner, secret);
        uint256 price = _consumeCommitment(name, commitment);
        _lockedAmounts[_createLockHash(name, msg.sender)] += price;

        uint256 tokenId = _getTokenId(name);
        uint256 expires = registrar.register(tokenId, owner, durationTime);

        _refund(price);

        emit Registered(tokenId, owner, expires, msg.sender, price);
    }

    function renew(string calldata name) external payable {
        uint256 price = getFeePrice(name);
        require(msg.value >= price, "VC: Not enough amount");

        _lockedAmounts[_createLockHash(name, msg.sender)] += price;

        uint256 tokenId = _getTokenId(name);
        uint256 expires = registrar.renew(tokenId, durationTime);

        _refund(price);

        emit Renewed(tokenId, expires, msg.sender, price);
    }

    function unlock(string calldata name) external {
        require(registrar.available(_getTokenId(name)), "VC: Not available");

        bytes32 lockHash = _createLockHash(name, msg.sender);
        uint256 lockedAmount = _lockedAmounts[lockHash];
        require(lockedAmount > 0, "VC: Nothing to unlock");

        _lockedAmounts[lockHash] = 0;

        payable(msg.sender).transfer(lockedAmount);
    }
}
