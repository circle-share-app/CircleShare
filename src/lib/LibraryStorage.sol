// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Storage {
    struct Circle {
        address circleAddress;
        Member[] members;
        string name;
        string description;
        bool active;
        address creator;
    }

    struct Member {
        address memberAddress;
        Role role;
        string nickname;
    }

    struct Expense {
        uint256 id;
        string description;
        uint256 amount;
        address payer;
        address[] participants;
        uint256 timestamp;
        uint256 splitAmount;
        uint256 remainder;
        bool settled;
    }

    struct Invitation {
        address inviter;
        address invitee;
        string nickname;
        uint256 timestamp;
        bool accepted;
        bool rejected;
    }

    enum Role {
        USER,
        MEMBER,
        ADMIN,
        MODERATOR
    }

    enum Permission {
        REMOVE_USER,
        ADD_USER
    }
}
