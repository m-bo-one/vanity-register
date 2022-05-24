//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./libraries/StringUtils.sol";
import "./Registrar.sol";
import "./WithLock.sol";

contract Controller is WithLock {
    using StringUtils for string;
    using ECDSA for bytes32;

    Registrar private registrar;
    uint256 public immutable commitTime;
    uint256 public immutable durationTime;
    uint256 public immutable ethPerLen;
    uint8 public immutable minNameLength;

    mapping(bytes32 => uint256) internal _commitments;

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
        uint8 _minNameLength
    ) {
        registrar = _registrar;
        commitTime = _commitTime;
        durationTime = _durationTime;
        ethPerLen = _ethPerLen;
        minNameLength = _minNameLength;
    }

    /**
     * @dev getFeePrice used to calculate fee price for vanity name
     * @param name a vanity name parameter for fee calculation
     * @return calculated fee price
     */
    function getFeePrice(string calldata name) public view returns (uint256) {
        uint256 length = name.strlen();
        require(length >= minNameLength, "VC: Length too short");
        return name.strlen() * ethPerLen;
    }

    function getTokenId(string calldata name) internal pure returns (uint256) {
        return uint256(getNameKey(name));
    }

    function createCommitment(
        string calldata name,
        address owner,
        bytes32 secret
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(getNameKey(name), owner, secret));
    }

    function consumeCommitment(string calldata name, bytes32 commitment)
        internal
        returns (uint256)
    {
        require(
            _commitments[commitment] + commitTime >= block.timestamp,
            "VC: Commit expired"
        );

        require(registrar.available(getTokenId(name)), "VC: Not available");

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
        bytes32 commitment = createCommitment(name, owner, secret);
        uint256 price = consumeCommitment(name, commitment);

        uint256 tokenId = getTokenId(name);
        uint256 expires = registrar.register(tokenId, owner, durationTime);

        addLock(name, msg.sender, price, expires);

        _refund(price);

        emit Registered(tokenId, owner, expires, msg.sender, price);
    }

    function renew(string calldata name) external payable {
        uint256 price = getFeePrice(name);
        require(msg.value >= price, "VC: Not enough amount");

        uint256 tokenId = getTokenId(name);
        uint256 expires = registrar.renew(tokenId, durationTime);

        addLock(name, msg.sender, price, expires);

        _refund(price);

        emit Renewed(tokenId, expires, msg.sender, price);
    }

    function unlock(string calldata name) external {
        uint256 tokenId = getTokenId(name);
        LockedAmount[] storage amounts = getLocks(name, msg.sender);

        for (uint256 i = 0; i < amounts.length; i++) {
            LockedAmount storage lockedAmount = amounts[i];
            if (lockedAmount.time <= block.timestamp) {
                lockedAmount.claimed = true;
                payable(msg.sender).transfer(lockedAmount.value);
                emit Unlock(tokenId, msg.sender, lockedAmount.value);
            }
        }
    }
}
