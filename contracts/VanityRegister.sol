//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./libraries/StringUtils.sol";

contract VanityRegister {
    using StringUtils for string;
    using ECDSA for bytes32;

    uint256 public preLockTime = 300; // 5 min
    uint256 public commitLockTime = 3600; // 1 hour
    uint256 public lockAmount = 0.1 ether;
    uint256 public ethPerLen = 0.001 ether;
    bytes32 internal EMPTY_HASH = keccak256("");

    struct VanityData {
        address owner;
        bytes32 session;
        uint256 amount;
        uint256 expireTime;
    }

    mapping(bytes32 => VanityData) internal registry;
    mapping(bytes32 => bool) internal usedVanity;

    event Reserved(address indexed reservator, bytes32 vanityHash);
    event Revealed(
        address indexed reservator,
        bytes32 vanityHash,
        string vanityName
    );

    /**
     * @dev getFeePrice used to calculate fee price for vanity name
     * @param _vanityName a parameter for fee calculation
     * @return calculated fee price
     */
    function getFeePrice(string calldata _vanityName)
        public
        view
        returns (uint256)
    {
        return _vanityName.strlen() * ethPerLen;
    }

    /**
     * @dev getVanityId used to get hash for signed message
     * @param _vanityHash a keccak256 from vanity name
     * @param _userDataHash a keccak256 from tx payload
     * @return vanityId
     */
    function getVanityId(bytes32 _vanityHash, bytes32 _userDataHash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_vanityHash, _userDataHash));
    }

    function reserve(
        bytes32 _vanityHash,
        bytes32 _userDataHash,
        bytes calldata _signature
    ) public payable {
        require(_vanityHash != EMPTY_HASH, "VR: Empty string");
        require(msg.value == lockAmount, "VR: Insufficient lock amount");
        bytes32 vanityId = getVanityId(_vanityHash, _userDataHash);
        require(!usedVanity[vanityId], "VR: Vanity in use");

        address signer = vanityId.toEthSignedMessageHash().recover(_signature);
        require(msg.sender == signer, "VR: Wrong signer");

        VanityData memory data = registry[_vanityHash];
        require(data.expireTime > block.timestamp, "VR: Locked");

        registry[_vanityHash] = VanityData(
            signer,
            _userDataHash,
            msg.value,
            block.timestamp
        );

        // in case we already had reserve, we should return back locked funds
        if (data.amount > 0) {
            payable(data.owner).transfer(data.amount);
        }

        emit Reserved(signer, _vanityHash);
    }

    function reveal(string calldata _vanityName) public {
        bytes32 _vanityHash = keccak256(abi.encodePacked(_vanityName));
        VanityData storage data = registry[_vanityHash];
        uint256 _expireTime = data.expireTime;

        bytes32 vanityId = getVanityId(_vanityHash, data.session);
        require(usedVanity[vanityId], "VR: Vanity not found");

        require(data.owner != address(0), "VR: Should be reserved first");
        require(_expireTime <= block.timestamp, "VR: Expired");

        uint256 feePrice = getFeePrice(_vanityName);
        require(data.amount >= feePrice, "VR: Big vanity length");

        uint256 deltaPay = data.amount - feePrice;
        data.amount = feePrice;
        data.expireTime = _expireTime + commitLockTime;

        // return rest from reserve
        if (deltaPay > 0) {
            payable(data.owner).transfer(deltaPay);
        }
    }

    function revoke(string calldata _vanityName) public {
        bytes32 _vanityHash = keccak256(abi.encodePacked(_vanityName));
        VanityData memory data = registry[_vanityHash];
        uint256 _amount = data.amount;

        bytes32 vanityId = getVanityId(_vanityHash, data.session);
        require(usedVanity[vanityId], "VR: Vanity not found");

        require(data.owner != address(0), "VR: Should be reserved first");
        require(data.expireTime <= block.timestamp, "VR: Expired");

        delete registry[_vanityHash];

        payable(data.owner).transfer(_amount);
    }
}
