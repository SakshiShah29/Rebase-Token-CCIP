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

import {RebaseToken} from "./RebaseToken.sol";
import {IRebaseToken} from "./Interfaces/IRebaseToken.sol";

/*
 *@title: Vault
 *@author: Sakshi Shah
 
 */
contract Vault {
    // Need to pass the token address of the rebase token to the vault constructor
    //create a deposit function that mints tokens to the user equal tot the amount of eth the user has sent
    //create the redeem function that burns the tokens and sends the user eth
    //create a way to send rewards to the vault

    // Errors
    error Vault__AmountShouldBeMoreThanZero(uint256 amount);
    error Vault__RedeemFailed(address user, uint256 amount);

    // State variables
    IRebaseToken private immutable i_rebaseToken;

    constructor(IRebaseToken rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    // Modifiers
    modifier amountMoreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert Vault__AmountShouldBeMoreThanZero(amount);
        }
        _;
    }

    receive() external payable {}

    /*
     *@notice: This function allows the user to deposit eth into the vault and mint rebase tokens.
     *@dev: The function mints rebase tokens to the user equal to the amount of eth sent.
     *@dev: The function emits a Deposit event with the user's address and the amount deposited.
     */
    function deposit() external payable amountMoreThanZero(msg.value) {
        //use the amount of the eth that the user has sent to mint the rebase token
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /*
     *@notice: This function allows the user to redeem their rebase tokens for eth.
     *@param amount: The amount of rebase tokens to be redeemed.
     *@dev: The function burns the rebase tokens from the user and sends them the equivalent amount of eth.
     */
    function redeem(uint256 amount) external amountMoreThanZero(amount) {
        //burn the rebase token from the user
        i_rebaseToken.burn(msg.sender, amount);
        (bool success, ) = payable(msg.sender).call{value: amount}(""); //send the user the amount of eth equal to the amount of rebase token burned
        if (!success) {
            revert Vault__RedeemFailed(msg.sender, amount);
        }
        emit Redeem(msg.sender, amount);
    }

    //Getter functions - View & Pure
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
