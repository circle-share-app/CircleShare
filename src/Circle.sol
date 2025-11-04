// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICircle} from "./interface/ICircle.sol";
import {Storage} from "./lib/LibraryStorage.sol";
import {Error} from "./lib/Error.sol";

contract Circle is ICircle {
    using Error for *;

    mapping(address => mapping(Storage.Permission => bool)) private permissionsAssigned;
    mapping(address => Storage.Role) private roleAssigned;
    mapping(address => bool) private _isMember;
    mapping(address => Storage.Invitation) private pendingInvitations;
    mapping(address => int256) private balances;

    Storage.Circle private circle;
    Storage.Expense[] private expenses;
    address[] private pendingInvitees;
    uint256 private nextExpenseId;
    uint256 private constant MAX_MEMBERS = 50;
    uint256 private constant MAX_DESCRIPTION_LENGTH = 200;

    constructor(address _admin, string memory _name, string memory _description) {
        circle.circleAddress = address(this);
        circle.name = _name;
        circle.description = _description;
        circle.active = true;
        circle.creator = _admin;

        roleAssigned[_admin] = Storage.Role.ADMIN;

        circle.members.push(Storage.Member({memberAddress: _admin, role: Storage.Role.ADMIN, nickname: ""}));
        _isMember[_admin] = true;
        nextExpenseId = 1;
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

    modifier onlyActive() {
        if (!circle.active) {
            revert Error.CircleInactiveError("Circle is inactive");
        }
        _;
    }

    modifier onlyCreator() {
        if (msg.sender != circle.creator) {
            revert Error.ForbiddenError("Only creator can perform this action");
        }
        _;
    }

    modifier onlyAdminOrCreator() {
        if (msg.sender != circle.creator && roleAssigned[msg.sender] != Storage.Role.ADMIN) {
            revert Error.ForbiddenError("Only creator or admin can perform this action");
        }
        _;
    }

    function addMember(address memberAddress) external onlyAdminOrModerator onlyActive {
        if (memberAddress == address(0)) {
            revert Error.ConflictError("Invalid member address");
        }
        if (_isMember[memberAddress]) {
            revert Error.ConflictError("Already a member");
        }
        if (circle.members.length >= MAX_MEMBERS) {
            revert Error.ConflictError("Maximum members reached");
        }

        circle.members.push(Storage.Member({memberAddress: memberAddress, role: Storage.Role.MEMBER, nickname: ""}));

        roleAssigned[memberAddress] = Storage.Role.MEMBER;
        _isMember[memberAddress] = true;

        emit MemberAdded(memberAddress, Storage.Role.MEMBER);
    }

    function removeMember(address memberAddress) external onlyAdminOrModerator onlyActive {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }

        uint256 indexToRemove = type(uint256).max;
        for (uint256 i = 0; i < circle.members.length; i++) {
            if (circle.members[i].memberAddress == memberAddress) {
                indexToRemove = i;
                break;
            }
        }
        if (indexToRemove == type(uint256).max) {
            revert Error.ConflictError("Member not found");
        }

        Storage.Role role = roleAssigned[memberAddress];

        circle.members[indexToRemove] = circle.members[circle.members.length - 1];
        circle.members.pop();

        delete roleAssigned[memberAddress];
        _isMember[memberAddress] = false;
        permissionsAssigned[memberAddress][Storage.Permission.REMOVE_USER] = false;
        permissionsAssigned[memberAddress][Storage.Permission.ADD_USER] = false;

        emit MemberRemoved(memberAddress, role);
    }

    function getCircle() external view onlyMember returns (Storage.Circle memory) {
        return circle;
    }

    function getMembers() external view onlyMember returns (Storage.Member[] memory) {
        return circle.members;
    }

    function assignRole(address memberAddress, Storage.Role role) external onlyAdmin {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }
        if (role == Storage.Role.USER) {
            revert Error.ConflictError("Invalid role");
        }

        roleAssigned[memberAddress] = role;

        for (uint256 i = 0; i < circle.members.length; i++) {
            if (circle.members[i].memberAddress == memberAddress) {
                circle.members[i].role = role;
                break;
            }
        }

        emit RoleAssigned(memberAddress, role);
    }

    function revokeRole(address memberAddress, Storage.Role role) external onlyAdmin {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }
        if (roleAssigned[memberAddress] != role) {
            revert Error.ConflictError("Role mismatch");
        }

        roleAssigned[memberAddress] = Storage.Role.MEMBER;

        for (uint256 i = 0; i < circle.members.length; i++) {
            if (circle.members[i].memberAddress == memberAddress) {
                circle.members[i].role = Storage.Role.MEMBER;
                break;
            }
        }

        emit RoleRevoked(memberAddress, role);
    }

    function assignPermission(address memberAddress, Storage.Permission permission) external onlyAdmin {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }

        permissionsAssigned[memberAddress][permission] = true;
        emit PermissionAssigned(memberAddress, permission);
    }

    function revokePermission(address memberAddress, Storage.Permission permission) external onlyAdmin {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }

        delete permissionsAssigned[memberAddress][permission];
        emit PermissionRevoked(memberAddress, permission);
    }

    function getRole(address memberAddress) external view onlyMember returns (Storage.Role) {
        return roleAssigned[memberAddress];
    }

    function isMember(address memberAddress) external view returns (bool) {
        return _isMember[memberAddress];
    }

    function hasPermission(address memberAddress, Storage.Permission permission)
        external
        view
        onlyMember
        returns (bool)
    {
        return permissionsAssigned[memberAddress][permission];
    }

    // Deactivate/Reactivate Circle Functions
    function deactivateCircle() external onlyAdminOrCreator {
        if (!circle.active) {
            revert Error.ConflictError("Circle is already inactive");
        }
        circle.active = false;
        emit CircleDeactivated(msg.sender, block.timestamp);
    }

    function reactivateCircle() external onlyAdminOrCreator {
        if (circle.active) {
            revert Error.ConflictError("Circle is already active");
        }
        circle.active = true;
        emit CircleReactivated(msg.sender, block.timestamp);
    }

    function isActive() external view returns (bool) {
        return circle.active;
    }

    // Invitation Functions
    function inviteMember(address invitee, string memory nickname) external onlyCreator onlyActive {
        if (invitee == address(0)) {
            revert Error.InvalidInputError("Invalid invitee address");
        }
        if (_isMember[invitee]) {
            revert Error.ConflictError("Already a member");
        }
        if (
            pendingInvitations[invitee].inviter != address(0) && !pendingInvitations[invitee].accepted
                && !pendingInvitations[invitee].rejected
        ) {
            revert Error.ConflictError("Invitation already pending");
        }
        if (circle.members.length >= MAX_MEMBERS) {
            revert Error.ConflictError("Maximum members reached");
        }

        pendingInvitations[invitee] = Storage.Invitation({
            inviter: msg.sender,
            invitee: invitee,
            nickname: nickname,
            timestamp: block.timestamp,
            accepted: false,
            rejected: false
        });

        pendingInvitees.push(invitee);

        emit InvitationSent(msg.sender, invitee, nickname, block.timestamp);
    }

    function acceptInvitation() external onlyActive {
        Storage.Invitation storage invitation = pendingInvitations[msg.sender];

        if (invitation.inviter == address(0)) {
            revert Error.NotFoundError("No invitation found");
        }
        if (invitation.accepted) {
            revert Error.ConflictError("Invitation already accepted");
        }
        if (invitation.rejected) {
            revert Error.ConflictError("Invitation already rejected");
        }
        if (_isMember[msg.sender]) {
            revert Error.ConflictError("Already a member");
        }
        if (circle.members.length >= MAX_MEMBERS) {
            revert Error.ConflictError("Maximum members reached");
        }

        invitation.accepted = true;

        circle.members.push(
            Storage.Member({memberAddress: msg.sender, role: Storage.Role.MEMBER, nickname: invitation.nickname})
        );

        roleAssigned[msg.sender] = Storage.Role.MEMBER;
        _isMember[msg.sender] = true;

        _removePendingInvitee(msg.sender);

        emit InvitationAccepted(msg.sender, block.timestamp);
        emit MemberAdded(msg.sender, Storage.Role.MEMBER);
    }

    function rejectInvitation() external {
        Storage.Invitation storage invitation = pendingInvitations[msg.sender];

        if (invitation.inviter == address(0)) {
            revert Error.NotFoundError("No invitation found");
        }
        if (invitation.accepted) {
            revert Error.ConflictError("Invitation already accepted");
        }
        if (invitation.rejected) {
            revert Error.ConflictError("Invitation already rejected");
        }

        invitation.rejected = true;

        _removePendingInvitee(msg.sender);

        emit InvitationRejected(msg.sender, block.timestamp);
    }

    function getPendingInvitations() external view onlyCreator returns (Storage.Invitation[] memory) {
        Storage.Invitation[] memory invitations = new Storage.Invitation[](pendingInvitees.length);

        for (uint256 i = 0; i < pendingInvitees.length; i++) {
            invitations[i] = pendingInvitations[pendingInvitees[i]];
        }

        return invitations;
    }

    function _removePendingInvitee(address invitee) private {
        for (uint256 i = 0; i < pendingInvitees.length; i++) {
            if (pendingInvitees[i] == invitee) {
                pendingInvitees[i] = pendingInvitees[pendingInvitees.length - 1];
                pendingInvitees.pop();
                break;
            }
        }
    }

    // Expense Functions
    function addExpense(string memory description, uint256 amount, address[] memory participants)
        external
        onlyMember
        onlyActive
    {
        if (bytes(description).length > MAX_DESCRIPTION_LENGTH) {
            revert Error.InvalidInputError("Description too long");
        }
        if (bytes(description).length == 0) {
            revert Error.InvalidInputError("Description cannot be empty");
        }
        if (amount == 0) {
            revert Error.InvalidInputError("Amount must be greater than zero");
        }
        if (participants.length == 0) {
            revert Error.InvalidInputError("Must have at least one participant");
        }

        // Validate all participants are members
        for (uint256 i = 0; i < participants.length; i++) {
            if (!_isMember[participants[i]]) {
                revert Error.NotFoundError("Participant is not a member");
            }
        }

        // Check for duplicates
        for (uint256 i = 0; i < participants.length; i++) {
            for (uint256 j = i + 1; j < participants.length; j++) {
                if (participants[i] == participants[j]) {
                    revert Error.ConflictError("Duplicate participants");
                }
            }
        }

        uint256 splitAmount = amount / participants.length;
        uint256 remainder = amount % participants.length;

        Storage.Expense memory expense = Storage.Expense({
            id: nextExpenseId,
            description: description,
            amount: amount,
            payer: msg.sender,
            participants: participants,
            timestamp: block.timestamp,
            splitAmount: splitAmount,
            remainder: remainder
        });

        expenses.push(expense);

        // Update balances
        // Payer gets credited for the full amount
        balances[msg.sender] += int256(amount);

        // Each participant gets debited for their share
        for (uint256 i = 0; i < participants.length; i++) {
            balances[participants[i]] -= int256(splitAmount);
        }

        // Handle remainder by charging first participant(s)
        if (remainder > 0) {
            for (uint256 i = 0; i < remainder; i++) {
                balances[participants[i]] -= 1;
            }
        }

        emit ExpenseAdded(nextExpenseId, msg.sender, amount, description, participants.length, block.timestamp);

        nextExpenseId++;
    }

    function getExpenses() external view onlyMember returns (Storage.Expense[] memory) {
        return expenses;
    }

    function getExpense(uint256 expenseId) external view onlyMember returns (Storage.Expense memory) {
        if (expenseId == 0 || expenseId >= nextExpenseId) {
            revert Error.NotFoundError("Expense not found");
        }

        for (uint256 i = 0; i < expenses.length; i++) {
            if (expenses[i].id == expenseId) {
                return expenses[i];
            }
        }

        revert Error.NotFoundError("Expense not found");
    }

    function getBalance(address memberAddress) external view onlyMember returns (int256) {
        if (!_isMember[memberAddress]) {
            revert Error.NotFoundError("Member not found");
        }
        return balances[memberAddress];
    }
}
