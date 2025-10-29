// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Group.sol";
import {Error} from "./lib/Error.sol";

contract GroupFactory {
    using Error for *;

    event GroupCreated(
        address indexed groupAddress,
        string name,
        string description,
        address indexed admin
    );

    address[] public allGroups;
    mapping(string => address) public groupByName;
    mapping(bytes32 => bool) private nameExists;

    function createGroup(
        string memory name,
        string memory description
    ) external returns (address groupAddress) {
        bytes32 hash = keccak256(abi.encodePacked(name));
        if (nameExists[hash]) revert Error.ConflictError("Name already exists");

        Group newGroup = new Group(msg.sender, name, description);

        groupAddress = address(newGroup);
        allGroups.push(groupAddress);
        groupByName[name] = groupAddress;
        nameExists[hash] = true;

        emit GroupCreated(groupAddress, name, description, msg.sender);
    }

    function getAllGroups() external view returns (address[] memory) {
        return allGroups;
    }

    function getGroupByName(
        string memory name
    ) external view returns (address) {
        return groupByName[name];
    }
}
