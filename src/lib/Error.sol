// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Error {
    error NotFoundError(string message);
    error UnauthorizedError(string message);
    error ForbiddenError(string message);
    error ConflictError(string message);
    error InvalidInputError(string message);
    error CircleInactiveError(string message);
}
