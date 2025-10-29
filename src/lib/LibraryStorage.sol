// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Storage {
    struct Group {
        address groupAddress;
        Member[] members;
        string name;
        string description;
    }

    struct Member {
        address memberAdress;
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
