// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interface/IGroup.sol";
import {Storage} from "./lib/LibraryStorage.sol";
import {Error} from "./lib/Error.sol";

contract Group is IGroup {
    using Error for *;

    mapping(address => mapping(Storage.Role => Storage.Permission))
        private permissionsAssigned;
    mapping(address => Storage.Role) private roleAssigned;

    Storage.Group private group;

    constructor(
        address _admin,
        string memory _name,
        string memory _description
    ) {
        group.groupAddress = address(this);
        group.name = _name;
        group.description = _description;

        roleAssigned[_admin] = Storage.Role.ADMIN;

        group.members.push(
            Storage.Member({memberAdress: _admin, role: Storage.Role.ADMIN})
        );
    }

    modifier onlyAdmin() {
        if (roleAssigned[msg.sender] != Storage.Role.ADMIN) {
            revert Error.ForbiddenError("Unauthorized access");
        }
        _;
    }

    modifier onlyAdminOrModerator() {
        Storage.Role role = roleAssigned[msg.sender];
        if (role != Storage.Role.ADMIN && role != Storage.Role.MODERATOR) {
            revert Error.ForbiddenError("Unauthorized access");
        }
        _;
    }

    function addMember(address memberAddress) external onlyAdminOrModerator {
        require(
            roleAssigned[memberAddress] == Storage.Role(0),
            "Already a member"
        );

        group.members.push(
            Storage.Member({
                memberAdress: memberAddress,
                role: Storage.Role.MEMBER
            })
        );

        roleAssigned[memberAddress] = Storage.Role.USER;

        emit MemberAdded(memberAddress, Storage.Role.USER);
    }

    function removeMember(address memberAddress) external onlyAdminOrModerator {
        uint indexToRemove = type(uint).max;
        for (uint i = 0; i < group.members.length; i++) {
            if (group.members[i].memberAdress == memberAddress) {
                indexToRemove = i;
                break;
            }
        }
        if (indexToRemove == type(uint).max)
            revert Error.ConflictError("Member not found");

        Storage.Role role = Storage.Role.USER;

        group.members[indexToRemove] = group.members[group.members.length - 1];
        group.members.pop();

        delete roleAssigned[memberAddress];

        emit MemberRemoved(memberAddress, role);
    }

    function getGroup() external view returns (Storage.Group memory) {
        return group;
    }

    function getMembers() external view returns (Storage.Member[] memory) {
        return group.members;
    }

    function assignRole(
        address memberAddress,
        Storage.Role role
    ) external onlyAdmin {
        roleAssigned[memberAddress] = role;

        for (uint i = 0; i < group.members.length; i++) {
            if (group.members[i].memberAdress == memberAddress) {
                group.members[i].role = role;
                break;
            }
        }

        emit RoleAssigned(memberAddress, role);
    }

    function revokeRole(
        address memberAddress,
        Storage.Role
    ) external onlyAdmin {
        roleAssigned[memberAddress] = Storage.Role.USER;

        for (uint i = 0; i < group.members.length; i++) {
            if (group.members[i].memberAdress == memberAddress) {
                group.members[i].role = Storage.Role.USER;
                break;
            }
        }

        emit RoleRevoked(memberAddress, Storage.Role.USER);
    }

    function assignPermission(
        address memberAddress,
        Storage.Permission permission
    ) external onlyAdmin {
        permissionsAssigned[memberAddress][
            roleAssigned[memberAddress]
        ] = permission;
        emit PermissionAssigned(memberAddress, permission);
    }

    function revokePermission(
        address memberAddress,
        Storage.Permission permission
    ) external onlyAdmin {
        permissionsAssigned[memberAddress][
            roleAssigned[memberAddress]
        ] = Storage.Permission(0);
        emit PermissionRevoked(memberAddress, permission);
    }
}
