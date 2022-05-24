//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Registrar is ERC721, Ownable {
    mapping(uint256 => uint256) public expiries;
    mapping(address => bool) public controllers;

    event Registered(
        uint256 indexed id,
        address indexed owner,
        uint256 expires
    );
    event Renewed(uint256 indexed id, uint256 expires);

    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);

    constructor() ERC721("Vanity registrar", "VR") {}

    modifier onlyController() {
        require(controllers[msg.sender], "VR: Controller not found");
        _;
    }

    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
        emit ControllerAdded(controller);
    }

    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
        emit ControllerRemoved(controller);
    }

    function available(uint256 id) public view returns (bool) {
        return expiries[id] < block.timestamp;
    }

    function register(
        uint256 id,
        address owner,
        uint256 duration
    ) public onlyController returns (uint256) {
        require(available(id), "VR: Not expired");
        uint256 expire = block.timestamp + duration;
        require(expire > block.timestamp, "VR: Zero duration");

        expiries[id] = expire;
        if (_exists(id)) {
            _burn(id);
        }
        _mint(owner, id);

        emit Registered(id, owner, expire);

        return expire;
    }

    function renew(uint256 id, uint256 duration)
        public
        onlyController
        returns (uint256)
    {
        require(expiries[id] >= block.timestamp, "VR: Expired");
        require(expiries[id] + duration > duration, "VR: Zero duration");

        expiries[id] += duration;

        emit Renewed(id, expiries[id]);

        return expiries[id];
    }
}
