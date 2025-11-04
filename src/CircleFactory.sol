// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Circle} from "./Circle.sol";
import {ICircle} from "./interface/ICircle.sol";
import {Error} from "./lib/Error.sol";

contract CircleFactory {
    using Error for *;

    event CircleCreated(address indexed circleAddress, string name, string description, address indexed admin);

    address[] private _circles;
    mapping(string => address) private _circleByName;
    mapping(bytes32 => bool) private _nameExists;

    function createCircle(string memory name, string memory description) public returns (address circleAddress) {
        bytes32 hash = keccak256(abi.encodePacked(name));
        if (_nameExists[hash]) revert Error.ConflictError("Name already exists");

        Circle newCircle = new Circle(msg.sender, name, description);

        circleAddress = address(newCircle);
        _circles.push(circleAddress);
        _circleByName[name] = circleAddress;
        _nameExists[hash] = true;

        emit CircleCreated(circleAddress, name, description, msg.sender);
    }

    function getMyCircles() external view returns (address[] memory) {
        uint256 count;
        uint256 circlesLength = _circles.length;
        for (uint256 i; i < circlesLength; i++) {
            if (ICircle(_circles[i]).isMember(msg.sender)) {
                count++;
            }
        }

        address[] memory memberCircles = new address[](count);
        uint256 index;
        for (uint256 i; i < circlesLength; i++) {
            address circleAddress = _circles[i];
            if (ICircle(circleAddress).isMember(msg.sender)) {
                memberCircles[index] = circleAddress;
                index++;
            }
        }

        return memberCircles;
    }

    function getMyActiveCircles() external view returns (address[] memory) {
        uint256 count;
        uint256 circlesLength = _circles.length;
        for (uint256 i; i < circlesLength; i++) {
            ICircle circle = ICircle(_circles[i]);
            if (circle.isMember(msg.sender) && circle.isActive()) {
                count++;
            }
        }

        address[] memory activeCircles = new address[](count);
        uint256 index;
        for (uint256 i; i < circlesLength; i++) {
            address circleAddress = _circles[i];
            ICircle circle = ICircle(circleAddress);
            if (circle.isMember(msg.sender) && circle.isActive()) {
                activeCircles[index] = circleAddress;
                index++;
            }
        }

        return activeCircles;
    }

    function getAllActiveCircles() external view returns (address[] memory) {
        uint256 count;
        uint256 circlesLength = _circles.length;
        for (uint256 i; i < circlesLength; i++) {
            if (ICircle(_circles[i]).isActive()) {
                count++;
            }
        }

        address[] memory activeCircles = new address[](count);
        uint256 index;
        for (uint256 i; i < circlesLength; i++) {
            address circleAddress = _circles[i];
            if (ICircle(circleAddress).isActive()) {
                activeCircles[index] = circleAddress;
                index++;
            }
        }

        return activeCircles;
    }

    function getCircleByName(string memory name) external view returns (address) {
        address circleAddress = _circleByName[name];
        if (circleAddress == address(0)) revert Error.NotFoundError("Circle not found");
        if (!ICircle(circleAddress).isMember(msg.sender)) {
            revert Error.ForbiddenError("Unauthorized access");
        }
        return circleAddress;
    }

    function circleCount() external view returns (uint256) {
        return _circles.length;
    }
}
