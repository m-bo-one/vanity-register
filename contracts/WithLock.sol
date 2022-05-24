//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract WithLock {
    struct LockedAmount {
        uint256 value;
        uint256 time;
        bool claimed;
    }
    mapping(bytes32 => LockedAmount[]) private _lockedAmounts;

    event Unlock(uint256 indexed id, address indexed owner, uint256 amount);

    function getNameKey(string calldata name) internal pure returns (bytes32) {
        return keccak256(bytes(name));
    }

    function getLockKey(string calldata name, address payer)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(getNameKey(name), payer));
    }

    function getLocks(string calldata name, address payer)
        internal
        view
        returns (LockedAmount[] storage)
    {
        return _lockedAmounts[getLockKey(name, payer)];
    }

    function addLock(
        string calldata name,
        address payer,
        uint256 value,
        uint256 time
    ) internal {
        _lockedAmounts[getLockKey(name, payer)].push(
            LockedAmount(value, time, false)
        );
    }
}
