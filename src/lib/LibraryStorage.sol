// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Storage {
    struct Circle {
        address circleAddress;
        Member[] members;
        string name;
        string description;
    }

    struct Member {
        address memberAddress;
        Role role;
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
