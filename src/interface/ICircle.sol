// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Storage} from "../lib/LibraryStorage.sol";

interface ICircle {
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

    function getCircle() external view returns (Storage.Circle memory circle);

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

    function getRole(address memberAddress)
        external
        view
        returns (Storage.Role role);

    function isMember(address memberAddress) external view returns (bool);

    function hasPermission(
        address memberAddress,
        Storage.Permission permission
    ) external view returns (bool);
}
