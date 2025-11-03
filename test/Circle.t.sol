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
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
        circle.getCircle();

        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
        circle.getMembers();

        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
        circle.getRole(ADMIN);

        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ConflictError.selector,
                "Invalid member address"
            )
        );
        circle.addMember(address(0));
    }

    function testAddMemberRejectsDuplicate() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ConflictError.selector,
                "Already a member"
            )
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.NotFoundError.selector,
                "Member not found"
            )
        );
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
        bool hasPerm = circle.hasPermission(
            MEMBER,
            Storage.Permission.ADD_USER
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ConflictError.selector,
                "Invalid role"
            )
        );
        circle.assignRole(MEMBER, Storage.Role.USER);
    }

    function testAssignRoleRequiresMembership() public {
        vm.prank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.NotFoundError.selector,
                "Member not found"
            )
        );
        circle.assignRole(MEMBER, Storage.Role.MODERATOR);
    }

    function testAssignRoleRestrictedToAdmin() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(MEMBER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.NotFoundError.selector,
                "Member not found"
            )
        );
        circle.revokeRole(MEMBER, Storage.Role.MODERATOR);
    }

    function testRevokeRoleRequiresExactMatch() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ConflictError.selector,
                "Role mismatch"
            )
        );
        circle.revokeRole(MEMBER, Storage.Role.MODERATOR);
    }

    function testAssignPermissionSetsFlag() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(ADMIN);
        circle.assignPermission(MEMBER, Storage.Permission.ADD_USER);

        vm.prank(ADMIN);
        bool hasPerm = circle.hasPermission(
            MEMBER,
            Storage.Permission.ADD_USER
        );
        assertTrue(hasPerm, "permission flag not set");
    }

    function testAssignPermissionRequiresMembership() public {
        vm.prank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.NotFoundError.selector,
                "Member not found"
            )
        );
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
        bool hasPerm = circle.hasPermission(
            MEMBER,
            Storage.Permission.ADD_USER
        );
        assertFalse(hasPerm, "permission flag not cleared");
    }

    function testAssignPermissionRestrictedToAdmin() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(MEMBER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
        circle.assignPermission(MEMBER, Storage.Permission.ADD_USER);
    }

    function testHasPermissionRestrictedToMembers() public {
        vm.prank(ADMIN);
        circle.addMember(MEMBER);

        vm.prank(STRANGER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
        circle.hasPermission(MEMBER, Storage.Permission.ADD_USER);
    }
}
