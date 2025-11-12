// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Circle} from "../src/Circle.sol";
import {Storage} from "../src/lib/LibraryStorage.sol";
import {Error} from "../src/lib/Error.sol";

contract CircleTest is Test {
    Circle private circle;

    address private constant ADMIN = address(0xA11CE);
    address private constant MODERATOR = address(0xCAFE);
    address private constant MEMBER = address(0xB0B);
    address private constant STRANGER = address(0xDEAD);

    string private constant NAME = "Builders";
    string private constant DESCRIPTION = "Circle for builders";

    function setUp() public {
        vm.prank(ADMIN);
        circle = new Circle(ADMIN, NAME, DESCRIPTION);
    }

    function testConstructorAssignsAdminAndMembership() public {
        vm.prank(ADMIN);
        Storage.Circle memory metadata = circle.getCircle();
        assertEq(metadata.name, NAME, "circle name mismatch");
        assertEq(metadata.description, DESCRIPTION, "circle description mismatch");
        assertEq(metadata.members.length, 1, "expected single member");
        assertEq(metadata.members[0].memberAddress, ADMIN, "admin not registered");
        assertEq(uint256(metadata.members[0].role), uint256(Storage.Role.ADMIN), "admin role incorrect");
        assertTrue(circle.isMember(ADMIN), "admin should be member");

        vm.prank(ADMIN);
        Storage.Role adminRole = circle.getRole(ADMIN);
        assertEq(uint256(adminRole), uint256(Storage.Role.ADMIN), "admin role mismatch");
    }

    function testNonMembersCannotViewCircleOrMembers() public {
        vm.startPrank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Unauthorized access"));
        circle.getCircle();

        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Unauthorized access"));
        circle.getMembers();

        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Unauthorized access"));
        circle.getRole(ADMIN);

        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Unauthorized access"));
        circle.hasPermission(ADMIN, Storage.Permission.ADD_USER);
        vm.stopPrank();
    }

    function testAddMemberByAdmin() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        assertTrue(circle.isMember(MEMBER), "member flag not set");

        vm.prank(ADMIN);
        Storage.Role role = circle.getRole(MEMBER);
        assertEq(uint256(role), uint256(Storage.Role.MEMBER), "default role incorrect");

        vm.prank(ADMIN);
        Storage.Member[] memory members = circle.getMembers();
        assertEq(members.length, 2, "expected two members");
    }

    function testAddMemberRejectsZeroAddress() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Invalid member address"));
        circle.addMember(address(0));
    }

    function testAddMemberRejectsDuplicate() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Already a member"));
        circle.addMember(MEMBER);
    }

    function testAddMemberByModerator() public {
        vm.startPrank(ADMIN);
        circle.addMember(MODERATOR);
        circle.assignRole(MODERATOR, Storage.Role.MODERATOR);
        vm.stopPrank();

        vm.prank(MODERATOR);
        circle.addMember(MEMBER);

        assertTrue(circle.isMember(MEMBER), "moderator failed to add member");
    }

    function testAddMemberOnlyAdminOrModerator() public {
        vm.prank(ADMIN);
        circle.addMember(MODERATOR);

        vm.prank(MODERATOR);
        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Unauthorized access"));
        circle.addMember(STRANGER);
    }

    function testRemoveMemberByAdmin() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        circle.removeMember(MEMBER);

        assertFalse(circle.isMember(MEMBER), "member flag not cleared");

        vm.prank(ADMIN);
        Storage.Member[] memory members = circle.getMembers();
        assertEq(members.length, 1, "member should be removed from list");
    }

    function testRemoveMemberByModerator() public {
        vm.startPrank(ADMIN);
        circle.addMember(MODERATOR);
        circle.assignRole(MODERATOR, Storage.Role.MODERATOR);
        circle.addMember(MEMBER);
        vm.stopPrank();

        vm.prank(MODERATOR);
        circle.removeMember(MEMBER);

        assertFalse(circle.isMember(MEMBER), "member should be removed by moderator");
    }

    function testRemoveMemberRequiresMembership() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.NotFoundError.selector, "Member not found"));
        circle.removeMember(MEMBER);
    }

    function testRemoveMemberClearsPermissions() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        circle.assignPermission(MEMBER, Storage.Permission.ADD_USER);

        vm.prank(ADMIN);
        circle.removeMember(MEMBER);

        vm.prank(ADMIN);
        bool hasPerm = circle.hasPermission(MEMBER, Storage.Permission.ADD_USER);
        assertFalse(hasPerm, "permission should be cleared on removal");
    }

    function testAssignRoleUpdatesState() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        circle.assignRole(MEMBER, Storage.Role.MODERATOR);

        vm.prank(ADMIN);
        Storage.Role memberRole = circle.getRole(MEMBER);
        assertEq(uint256(memberRole), uint256(Storage.Role.MODERATOR), "role not updated");
    }

    function testAssignRoleRejectsInvalidRole() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Invalid role"));
        circle.assignRole(MEMBER, Storage.Role.USER);
    }

    function testAssignRoleRequiresMembership() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.NotFoundError.selector, "Member not found"));
        circle.assignRole(MEMBER, Storage.Role.MODERATOR);
    }

    function testAssignRoleRestrictedToAdmin() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(MEMBER);
        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Unauthorized access"));
        circle.assignRole(MEMBER, Storage.Role.MODERATOR);
    }

    function testRevokeRoleHappyPath() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        circle.assignRole(MEMBER, Storage.Role.MODERATOR);

        vm.prank(ADMIN);
        circle.revokeRole(MEMBER, Storage.Role.MODERATOR);

        vm.prank(ADMIN);
        Storage.Role memberRole = circle.getRole(MEMBER);
        assertEq(uint256(memberRole), uint256(Storage.Role.MEMBER), "role should default to member");
    }

    function testRevokeRoleRequiresMembership() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.NotFoundError.selector, "Member not found"));
        circle.revokeRole(MEMBER, Storage.Role.MODERATOR);
    }

    function testRevokeRoleRequiresExactMatch() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Role mismatch"));
        circle.revokeRole(MEMBER, Storage.Role.MODERATOR);
    }

    function testAssignPermissionSetsFlag() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        circle.assignPermission(MEMBER, Storage.Permission.ADD_USER);

        vm.prank(ADMIN);
        bool hasPerm = circle.hasPermission(MEMBER, Storage.Permission.ADD_USER);
        assertTrue(hasPerm, "permission flag not set");
    }

    function testAssignPermissionRequiresMembership() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.NotFoundError.selector, "Member not found"));
        circle.assignPermission(MEMBER, Storage.Permission.ADD_USER);
    }

    function testRevokePermissionClearsFlag() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.startPrank(ADMIN);
        circle.assignPermission(MEMBER, Storage.Permission.ADD_USER);
        circle.revokePermission(MEMBER, Storage.Permission.ADD_USER);
        vm.stopPrank();

        vm.prank(ADMIN);
        bool hasPerm = circle.hasPermission(MEMBER, Storage.Permission.ADD_USER);
        assertFalse(hasPerm, "permission flag not cleared");
    }

    function testAssignPermissionRestrictedToAdmin() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(MEMBER);
        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Unauthorized access"));
        circle.assignPermission(MEMBER, Storage.Permission.ADD_USER);
    }

    function testHasPermissionRestrictedToMembers() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Unauthorized access"));
        circle.hasPermission(MEMBER, Storage.Permission.ADD_USER);
    }

    function testDeactivateCircleByAdmin() public {
        assertTrue(circle.isActive(), "circle should start active");

        vm.prank(ADMIN);
        circle.deactivateCircle();

        assertFalse(circle.isActive(), "circle should be inactive");
    }

    function testDeactivateCircleByCreator() public {
        assertTrue(circle.isActive(), "circle should start active");

        vm.prank(ADMIN);
        circle.deactivateCircle();

        assertFalse(circle.isActive(), "circle should be inactive");
    }

    function testReactivateCircle() public {
        vm.prank(ADMIN);
        circle.deactivateCircle();
        assertFalse(circle.isActive(), "circle should be inactive");

        vm.prank(ADMIN);
        circle.reactivateCircle();
        assertTrue(circle.isActive(), "circle should be active again");
    }

    function testDeactivateCircleRevertsIfAlreadyInactive() public {
        vm.prank(ADMIN);
        circle.deactivateCircle();

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Circle is already inactive"));
        circle.deactivateCircle();
    }

    function testReactivateCircleRevertsIfAlreadyActive() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Circle is already active"));
        circle.reactivateCircle();
    }

    function testDeactivateCircleRevertsForNonAdminNonCreator() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(MEMBER);
        vm.expectRevert(
            abi.encodeWithSelector(Error.ForbiddenError.selector, "Only creator or admin can perform this action")
        );
        circle.deactivateCircle();
    }

    function testAddMemberRevertsWhenCircleInactive() public {
        vm.prank(ADMIN);
        circle.deactivateCircle();

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.CircleInactiveError.selector, "Circle is inactive"));
        circle.addMember(MEMBER);
    }

    function testRemoveMemberRevertsWhenCircleInactive() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        circle.deactivateCircle();

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.CircleInactiveError.selector, "Circle is inactive"));
        circle.removeMember(MEMBER);
    }

    function testInviteMemberByCreator() public {
        vm.prank(ADMIN);
        circle.inviteMember(MEMBER, "Alice");

        vm.prank(ADMIN);
        Storage.Invitation[] memory invitations = circle.getPendingInvitations();
        assertEq(invitations.length, 1, "should have one pending invitation");
        assertEq(invitations[0].invitee, MEMBER, "invitee mismatch");
        assertEq(invitations[0].nickname, "Alice", "nickname mismatch");
        assertFalse(invitations[0].accepted, "should not be accepted");
        assertFalse(invitations[0].rejected, "should not be rejected");
    }

    function testInviteMemberRevertsForNonCreator() public {
        vm.prank(ADMIN);
        circle.addMember(MODERATOR);

        vm.prank(ADMIN);
        circle.assignRole(MODERATOR, Storage.Role.MODERATOR);

        vm.prank(MODERATOR);
        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Only creator can perform this action"));
        circle.inviteMember(MEMBER, "Bob");
    }

    function testInviteMemberRevertsForExistingMember() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Already a member"));
        circle.inviteMember(MEMBER, "Alice");
    }

    function testInviteMemberRevertsForZeroAddress() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.InvalidInputError.selector, "Invalid invitee address"));
        circle.inviteMember(address(0), "Nobody");
    }

    function testInviteMemberRevertsForDuplicateInvitation() public {
        vm.prank(ADMIN);
        circle.inviteMember(MEMBER, "Alice");

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Invitation already pending"));
        circle.inviteMember(MEMBER, "Alice Again");
    }

    function testAcceptInvitation() public {
        vm.prank(ADMIN);
        circle.inviteMember(MEMBER, "Alice");

        assertFalse(circle.isMember(MEMBER), "should not be member yet");

        vm.prank(MEMBER);
        circle.acceptInvitation();

        assertTrue(circle.isMember(MEMBER), "should be member now");

        vm.prank(ADMIN);
        Storage.Member[] memory members = circle.getMembers();
        assertEq(members.length, 2, "should have two members");
        assertEq(members[1].memberAddress, MEMBER, "member address mismatch");
        assertEq(members[1].nickname, "Alice", "nickname should be preserved");
    }

    function testAcceptInvitationRevertsIfNoInvitation() public {
        vm.prank(MEMBER);
        vm.expectRevert(abi.encodeWithSelector(Error.NotFoundError.selector, "No invitation found"));
        circle.acceptInvitation();
    }

    function testAcceptInvitationRevertsIfAlreadyAccepted() public {
        vm.prank(ADMIN);
        circle.inviteMember(MEMBER, "Alice");

        vm.prank(MEMBER);
        circle.acceptInvitation();

        vm.prank(MEMBER);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Invitation already accepted"));
        circle.acceptInvitation();
    }

    function testRejectInvitation() public {
        vm.prank(ADMIN);
        circle.inviteMember(MEMBER, "Alice");

        vm.prank(MEMBER);
        circle.rejectInvitation();

        assertFalse(circle.isMember(MEMBER), "should not be member");

        vm.prank(ADMIN);
        Storage.Invitation[] memory invitations = circle.getPendingInvitations();
        assertEq(invitations.length, 0, "should have no pending invitations");
    }

    function testRejectInvitationRevertsIfAlreadyRejected() public {
        vm.prank(ADMIN);
        circle.inviteMember(MEMBER, "Alice");

        vm.prank(MEMBER);
        circle.rejectInvitation();

        vm.prank(MEMBER);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Invitation already rejected"));
        circle.rejectInvitation();
    }

    function testInviteMemberRevertsWhenCircleInactive() public {
        vm.prank(ADMIN);
        circle.deactivateCircle();

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.CircleInactiveError.selector, "Circle is inactive"));
        circle.inviteMember(MEMBER, "Alice");
    }

    function testAcceptInvitationRevertsWhenCircleInactive() public {
        vm.prank(ADMIN);
        circle.inviteMember(MEMBER, "Alice");

        vm.prank(ADMIN);
        circle.deactivateCircle();

        vm.prank(MEMBER);
        vm.expectRevert(abi.encodeWithSelector(Error.CircleInactiveError.selector, "Circle is inactive"));
        circle.acceptInvitation();
    }

    function testAddExpenseByMember() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        address[] memory participants = new address[](2);
        participants[0] = ADMIN;
        participants[1] = MEMBER;

        vm.prank(ADMIN);
        circle.addExpense("Groceries", 150, participants);

        vm.prank(ADMIN);
        Storage.Expense[] memory expenses = circle.getExpenses();
        assertEq(expenses.length, 1, "should have one expense");
        assertEq(expenses[0].description, "Groceries", "description mismatch");
        assertEq(expenses[0].amount, 150, "amount mismatch");
        assertEq(expenses[0].payer, ADMIN, "payer mismatch");
        assertEq(expenses[0].participants.length, 2, "participants count mismatch");
        assertEq(expenses[0].splitAmount, 75, "split amount should be 75");
        assertEq(expenses[0].remainder, 0, "remainder should be 0");
    }

    function testAddExpenseWithRemainder() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        circle.addMember(MODERATOR);

        address[] memory participants = new address[](3);
        participants[0] = ADMIN;
        participants[1] = MEMBER;
        participants[2] = MODERATOR;

        vm.prank(ADMIN);
        circle.addExpense("Dinner", 100, participants);

        vm.prank(ADMIN);
        Storage.Expense[] memory expenses = circle.getExpenses();
        assertEq(expenses[0].splitAmount, 33, "split amount should be 33");
        assertEq(expenses[0].remainder, 1, "remainder should be 1");
    }

    function testAddExpenseUpdatesBalances() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        address[] memory participants = new address[](2);
        participants[0] = ADMIN;
        participants[1] = MEMBER;

        vm.prank(ADMIN);
        circle.addExpense("Groceries", 100, participants);

        vm.prank(ADMIN);
        int256 adminBalance = circle.getBalance(ADMIN);
        assertEq(adminBalance, 50, "admin balance should be +50");

        vm.prank(ADMIN);
        int256 memberBalance = circle.getBalance(MEMBER);
        assertEq(memberBalance, -50, "member balance should be -50");
    }

    function testAddExpenseWithRemainderBalances() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        circle.addMember(MODERATOR);

        address[] memory participants = new address[](3);
        participants[0] = ADMIN;
        participants[1] = MEMBER;
        participants[2] = MODERATOR;

        vm.prank(MEMBER);
        circle.addExpense("Dinner", 100, participants);

        vm.prank(ADMIN);
        int256 adminBalance = circle.getBalance(ADMIN);
        assertEq(adminBalance, -34, "admin balance should be -34");

        vm.prank(MEMBER);
        int256 memberBalance = circle.getBalance(MEMBER);
        assertEq(memberBalance, 67, "member balance should be +67");

        vm.prank(MODERATOR);
        int256 moderatorBalance = circle.getBalance(MODERATOR);
        assertEq(moderatorBalance, -33, "moderator balance should be -33");
    }

    function testAddExpenseRevertsForNonMember() public {
        vm.prank(STRANGER);
        address[] memory participants = new address[](1);
        participants[0] = ADMIN;

        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Unauthorized access"));
        circle.addExpense("Groceries", 100, participants);
    }

    function testAddExpenseRevertsForEmptyDescription() public {
        address[] memory participants = new address[](1);
        participants[0] = ADMIN;

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.InvalidInputError.selector, "Description cannot be empty"));
        circle.addExpense("", 100, participants);
    }

    function testAddExpenseRevertsForLongDescription() public {
        address[] memory participants = new address[](1);
        participants[0] = ADMIN;

        string memory longDesc = new string(201);
        bytes memory longDescBytes = bytes(longDesc);
        for (uint256 i = 0; i < 201; i++) {
            longDescBytes[i] = "a";
        }

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.InvalidInputError.selector, "Description too long"));
        circle.addExpense(string(longDescBytes), 100, participants);
    }

    function testAddExpenseRevertsForZeroAmount() public {
        address[] memory participants = new address[](1);
        participants[0] = ADMIN;

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.InvalidInputError.selector, "Amount must be greater than zero"));
        circle.addExpense("Groceries", 0, participants);
    }

    function testAddExpenseRevertsForNoParticipants() public {
        address[] memory participants = new address[](0);

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.InvalidInputError.selector, "Must have at least one participant"));
        circle.addExpense("Groceries", 100, participants);
    }

    function testAddExpenseRevertsForNonMemberParticipant() public {
        address[] memory participants = new address[](1);
        participants[0] = STRANGER;

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.NotFoundError.selector, "Participant is not a member"));
        circle.addExpense("Groceries", 100, participants);
    }

    function testAddExpenseRevertsForDuplicateParticipants() public {
        address[] memory participants = new address[](2);
        participants[0] = ADMIN;
        participants[1] = ADMIN;

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Duplicate participants"));
        circle.addExpense("Groceries", 100, participants);
    }

    function testGetExpenseById() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        address[] memory participants = new address[](2);
        participants[0] = ADMIN;
        participants[1] = MEMBER;

        vm.prank(ADMIN);
        circle.addExpense("Groceries", 150, participants);

        vm.prank(ADMIN);
        Storage.Expense memory expense = circle.getExpense(1);
        assertEq(expense.id, 1, "expense id should be 1");
        assertEq(expense.description, "Groceries", "description mismatch");
    }

    function testGetExpenseByIdRevertsForInvalidId() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.NotFoundError.selector, "Expense not found"));
        circle.getExpense(999);
    }

    function testAddExpenseRevertsWhenCircleInactive() public {
        vm.prank(ADMIN);
        circle.deactivateCircle();

        address[] memory participants = new address[](1);
        participants[0] = ADMIN;

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.CircleInactiveError.selector, "Circle is inactive"));
        circle.addExpense("Groceries", 100, participants);
    }

    function testMultipleExpensesIncrementIds() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        address[] memory participants = new address[](2);
        participants[0] = ADMIN;
        participants[1] = MEMBER;

        vm.prank(ADMIN);
        circle.addExpense("Expense 1", 100, participants);

        vm.prank(MEMBER);
        circle.addExpense("Expense 2", 200, participants);

        vm.prank(ADMIN);
        Storage.Expense[] memory expenses = circle.getExpenses();
        assertEq(expenses.length, 2, "should have two expenses");
        assertEq(expenses[0].id, 1, "first expense id should be 1");
        assertEq(expenses[1].id, 2, "second expense id should be 2");
    }

    function testAddMemberRevertsWhenMaxMembersReached() public {
        for (uint160 i = 1; i < 50; i++) {
            vm.prank(ADMIN);
            circle.addMember(address(i));
        }

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Maximum members reached"));
        circle.addMember(address(100));
    }

    function testInviteMemberRevertsWhenMaxMembersReached() public {
        for (uint160 i = 1; i < 50; i++) {
            vm.prank(ADMIN);
            circle.addMember(address(i));
        }

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.ConflictError.selector, "Maximum members reached"));
        circle.inviteMember(address(100), "Too Many");
    }
}

contract CircleUpdateExpenseDescriptionTest is Test {
    Circle private circle;

    address private constant ADMIN = address(0xA11CE);
    address private constant MEMBER = address(0xB0B);
    address private constant STRANGER = address(0xDEAD);

    function setUp() public {
        vm.prank(ADMIN);
        circle = new Circle(ADMIN, "Builders", "Circle for builders");
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        address[] memory participants = new address[](2);
        participants[0] = ADMIN;
        participants[1] = MEMBER;
        vm.prank(ADMIN);
        circle.addExpense("Supplies", 100, participants); // expenseId = 1
    }

    function testUpdateExpenseDescriptionByPayer() public {
        vm.prank(ADMIN);
        circle.updateExpenseDescription(1, "Garden Tools");

        vm.prank(ADMIN);
        Storage.Expense memory e = circle.getExpense(1);
        assertEq(e.description, "Garden Tools", "description should update");
    }

    function testUpdateExpenseDescriptionRevertsForNonPayer() public {
        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(Error.ForbiddenError.selector, "Unauthorized access"));
        circle.updateExpenseDescription(1, "Garden Tools");
    }

    function testUpdateExpenseDescriptionRevertsForEmpty() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.InvalidInputError.selector, "Description cannot be empty"));
        circle.updateExpenseDescription(1, "");
    }

    function testUpdateExpenseDescriptionRevertsForTooLong() public {
        string memory longDesc = new string(201);
        bytes memory longDescBytes = bytes(longDesc);
        for (uint256 i = 0; i < 201; i++) {
            longDescBytes[i] = "a";
        }

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.InvalidInputError.selector, "Description too long"));
        circle.updateExpenseDescription(1, string(longDescBytes));
    }

    function testUpdateExpenseDescriptionRevertsWhenCircleInactive() public {
        vm.prank(ADMIN);
        circle.deactivateCircle();

        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Error.CircleInactiveError.selector, "Circle is inactive"));
        circle.updateExpenseDescription(1, "Garden Tools");
    }
}
