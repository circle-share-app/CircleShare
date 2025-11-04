// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {CircleFactory} from "../src/CircleFactory.sol";
import {Circle} from "../src/Circle.sol";
import {Storage} from "../src/lib/LibraryStorage.sol";
import {Error} from "../src/lib/Error.sol";

contract CircleFactoryTest is Test {
    CircleFactory private factory;

    address private constant ADMIN = address(0xA11CE);
    address private constant MEMBER = address(0xB0B);
    string private constant CIRCLE_NAME = "Builders";
    string private constant CIRCLE_DESCRIPTION = "Circle for builders";

    function setUp() public {
        factory = new CircleFactory();
    }

    function testCreateCircleRegistersCreatorAndPersistsMetadata() public {
        vm.prank(ADMIN);
        address circleAddress = factory.createCircle(
            CIRCLE_NAME,
            CIRCLE_DESCRIPTION
        );

        vm.prank(ADMIN);
        address resolved = factory.getCircleByName(CIRCLE_NAME);
        assertEq(resolved, circleAddress, "factory should resolve circle by name");

        vm.prank(ADMIN);
        address[] memory myCircles = factory.getMyCircles();
        assertEq(myCircles.length, 1, "creator should see one circle");
        assertEq(myCircles[0], circleAddress, "creator list should contain circle");

        vm.prank(ADMIN);
        Storage.Circle memory circleData = Circle(circleAddress).getCircle();
        assertEq(circleData.name, CIRCLE_NAME, "circle name mismatch");
        assertEq(
            circleData.description,
            CIRCLE_DESCRIPTION,
            "circle description mismatch"
        );
        assertEq(
            circleData.members.length,
            1,
            "creator should be the only member after deployment"
        );

        assertEq(factory.circleCount(), 1, "factory should track circle count");
    }

    function testNonMembersCannotViewCircleDetails() public {
        vm.prank(ADMIN);
        address circleAddress = factory.createCircle(
            CIRCLE_NAME,
            CIRCLE_DESCRIPTION
        );

        vm.startPrank(MEMBER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
        factory.getCircleByName(CIRCLE_NAME);

        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
        Circle(circleAddress).getCircle();
        vm.stopPrank();

        vm.prank(MEMBER);
        address[] memory myCircles = factory.getMyCircles();
        assertEq(myCircles.length, 0, "non-member should not see any circles");
    }

    function testFactoryReflectsMembershipChanges() public {
        vm.prank(ADMIN);
        address circleAddress = factory.createCircle(
            CIRCLE_NAME,
            CIRCLE_DESCRIPTION
        );

        vm.prank(ADMIN);
        Circle(circleAddress).addMember(MEMBER);

        vm.prank(MEMBER);
        address[] memory myCircles = factory.getMyCircles();
        assertEq(myCircles.length, 1, "member should see joined circle");
        assertEq(myCircles[0], circleAddress, "member list should contain circle");

        vm.prank(MEMBER);
        Storage.Circle memory circleData = Circle(circleAddress).getCircle();
        assertEq(circleData.members.length, 2, "circle should list two members");

        vm.startPrank(ADMIN);
        Circle(circleAddress).removeMember(MEMBER);
        vm.stopPrank();

        vm.prank(MEMBER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Error.ForbiddenError.selector,
                "Unauthorized access"
            )
        );
        Circle(circleAddress).getCircle();

        vm.prank(MEMBER);
        address[] memory cleared = factory.getMyCircles();
        assertEq(cleared.length, 0, "removed member should no longer see circle");
    }
}
