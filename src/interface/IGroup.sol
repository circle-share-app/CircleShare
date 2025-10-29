// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Storage} from "../lib/LibraryStorage.sol";

interface IGroup {
    event MemberRemoved(address memberAddress, Storage.Role role);
    event MemberAdded(address memberAddress, Storage.Role role);
    event RoleAssigned(address memberAddress, Storage.Role role);
    event RoleRevoked(address memberAddress, Storage.Role role);
    event PermissionAssigned(
        address memberAddress,
        Storage.Permission permission
    );
    event PermissionRevoked(
        address memberAddress,
        Storage.Permission permission
    );

    function addMember(address memberAddress) external;

    function removeMember(address memberAddress) external;

    function getGroup() external view returns (Storage.Group memory group);

    function getMembers()
        external
        view
        returns (Storage.Member[] memory members);

    function assignRole(address memberAddress, Storage.Role role) external;

    function revokeRole(address memberAddress, Storage.Role role) external;

    function assignPermission(
        address memberAddress,
        Storage.Permission permission
    ) external;

    function revokePermission(
        address memberAddress,
        Storage.Permission permission
    ) external;
}
