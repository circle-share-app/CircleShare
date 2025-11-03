// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICircle} from "./interface/ICircle.sol";
import {Storage} from "./lib/LibraryStorage.sol";
import {Error} from "./lib/Error.sol";

contract Circle is ICircle {
    using Error for *;

    mapping(address => mapping(Storage.Permission => bool))
        private permissionsAssigned;
    mapping(address => Storage.Role) private roleAssigned;
    mapping(address => bool) private _isMember;

    Storage.Circle private circle;

    constructor(
        address _admin,
        string memory _name,
        string memory _description
    ) {
        circle.circleAddress = address(this);
        circle.name = _name;
        circle.description = _description;

        roleAssigned[_admin] = Storage.Role.ADMIN;

        circle.members.push(
            Storage.Member({
                memberAddress: _admin,
                role: Storage.Role.ADMIN
            })
        );
        _isMember[_admin] = true;
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

    modifier onlyMember() {
        if (!_isMember[msg.sender]) {
            revert Error.ForbiddenError("Unauthorized access");
        }
        _;
    }

    function addMember(address memberAddress) external onlyAdminOrModerator {
        if (memberAddress == address(0)) {
            revert Error.ConflictError("Invalid member address");
        }
        if (_isMember[memberAddress]) {
            revert Error.ConflictError("Already a member");
        }

        circle.members.push(
            Storage.Member({
                memberAddress: memberAddress,
                role: Storage.Role.MEMBER
            })
        );

        roleAssigned[memberAddress] = Storage.Role.MEMBER;
        _isMember[memberAddress] = true;

        emit MemberAdded(memberAddress, Storage.Role.MEMBER);
    }

    function removeMember(address memberAddress) external onlyAdminOrModerator {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }

        uint indexToRemove = type(uint).max;
        for (uint i = 0; i < circle.members.length; i++) {
            if (circle.members[i].memberAddress == memberAddress) {
                indexToRemove = i;
                break;
            }
        }
        if (indexToRemove == type(uint).max)
            revert Error.ConflictError("Member not found");

        Storage.Role role = roleAssigned[memberAddress];

        circle.members[indexToRemove] = circle.members[circle.members.length - 1];
        circle.members.pop();

        delete roleAssigned[memberAddress];
        _isMember[memberAddress] = false;
        permissionsAssigned[memberAddress][
            Storage.Permission.REMOVE_USER
        ] = false;
        permissionsAssigned[memberAddress][
            Storage.Permission.ADD_USER
        ] = false;

        emit MemberRemoved(memberAddress, role);
    }

    function getCircle()
        external
        view
        onlyMember
        returns (Storage.Circle memory)
    {
        return circle;
    }

    function getMembers()
        external
        view
        onlyMember
        returns (Storage.Member[] memory)
    {
        return circle.members;
    }

    function assignRole(
        address memberAddress,
        Storage.Role role
    ) external onlyAdmin {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }
        if (role == Storage.Role.USER) {
            revert Error.ConflictError("Invalid role");
        }

        roleAssigned[memberAddress] = role;

        for (uint i = 0; i < circle.members.length; i++) {
            if (circle.members[i].memberAddress == memberAddress) {
                circle.members[i].role = role;
                break;
            }
        }

        emit RoleAssigned(memberAddress, role);
    }

    function revokeRole(
        address memberAddress,
        Storage.Role role
    ) external onlyAdmin {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }
        if (roleAssigned[memberAddress] != role) {
            revert Error.ConflictError("Role mismatch");
        }

        roleAssigned[memberAddress] = Storage.Role.MEMBER;

        for (uint i = 0; i < circle.members.length; i++) {
            if (circle.members[i].memberAddress == memberAddress) {
                circle.members[i].role = Storage.Role.MEMBER;
                break;
            }
        }

        emit RoleRevoked(memberAddress, role);
    }

    function assignPermission(
        address memberAddress,
        Storage.Permission permission
    ) external onlyAdmin {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }

        permissionsAssigned[memberAddress][permission] = true;
        emit PermissionAssigned(memberAddress, permission);
    }

    function revokePermission(
        address memberAddress,
        Storage.Permission permission
    ) external onlyAdmin {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }

        delete permissionsAssigned[memberAddress][permission];
        emit PermissionRevoked(memberAddress, permission);
    }

    function getRole(
        address memberAddress
    ) external view onlyMember returns (Storage.Role) {
        return roleAssigned[memberAddress];
    }

    function isMember(address memberAddress) external view returns (bool) {
        return _isMember[memberAddress];
    }

    function hasPermission(
        address memberAddress,
        Storage.Permission permission
    ) external view onlyMember returns (bool) {
        return permissionsAssigned[memberAddress][permission];
    }
}
