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
    event CircleDeactivated(address deactivatedBy, uint256 timestamp);
    event CircleReactivated(address reactivatedBy, uint256 timestamp);
    event InvitationSent(
        address inviter,
        address invitee,
        string nickname,
        uint256 timestamp
    );
    event InvitationAccepted(address invitee, uint256 timestamp);
    event InvitationRejected(address invitee, uint256 timestamp);
    event ExpenseAdded(
        uint256 indexed expenseId,
        address payer,
        uint256 amount,
        string description,
        uint256 participantCount,
        uint256 timestamp
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

    function deactivateCircle() external;

    function reactivateCircle() external;

    function inviteMember(
        address invitee,
        string memory nickname
    ) external;

    function acceptInvitation() external;

    function rejectInvitation() external;

    function addExpense(
        string memory description,
        uint256 amount,
        address[] memory participants
    ) external;

    function getExpenses()
        external
        view
        returns (Storage.Expense[] memory);

    function getExpense(
        uint256 expenseId
    ) external view returns (Storage.Expense memory);

    function getPendingInvitations()
        external
        view
        returns (Storage.Invitation[] memory);

    function getBalance(address memberAddress) external view returns (int256);

    function isActive() external view returns (bool);
}
