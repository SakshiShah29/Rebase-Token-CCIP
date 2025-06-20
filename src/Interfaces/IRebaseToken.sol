//SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

interface IRebaseToken {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;

    function setInterestRate(uint256 newInterestRate) external;

    function getInterestRate() external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}
