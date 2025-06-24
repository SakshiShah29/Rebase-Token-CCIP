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
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/*
 *@title: Rebase Token
 *@author:Sakshi Shah
 *@notice: This is a cross chain rebase token that incentivises the user to deposit into a vault and gain interest in rewards.
 *@notice:The intesrest rate in the contract can only decrease.
 *@notice: Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    // Errors
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 currentInterestRate,
        uint256 newInterestRate
    );

    // State variables
    uint256 private constant PRECISION_FACTOR = 1e18; // 18 decimal places
    bytes32 private constant MINT_AND_BURN_ROLE =
        keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10; // 0.0000000005% per sec
    mapping(address userAddress => uint256 newInterestRateForUser)
        private s_userInterestRate; // User specific interest rate
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    // Events
    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, account);
    }

    /*
     *@notice: This function is used to set the interest rate for the rebase token.
     *@param _newInterestRate: The new interest rate to be set.
     *@dev: The interest rate can only decrease, if the new interest rate is greater than the current interest rate, it will revert.
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(s_interestRate);
    }

    /*
     *@notice: This function mints new tokens to the specified address.
     *@param to: The address to which the new tokens will be minted.
     *@param amount: The amount of tokens to be minted.
     *@dev: This function first mints the accrued interest for the user, then sets the user's interest rate to the current interest rate, and finally mints the specified amount of tokens.
     *@dev: The user's interest rate is updated to the current interest rate at the time of minting.
     */
    function mint(
        address to,
        uint256 amount,
        uint256 userInterestRate
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        mintAccuredInterest(to);
        s_userInterestRate[to] = userInterestRate;
        _mint(to, amount);
    }

    /*
     *@notice: This function burns tokens from the specified address.
     *@param from: The address from which the tokens will be burned.
     *@param amount: The amount of tokens to be burned.
     *@dev: This function first mints the accrued interest for the user, then burns the specified amount of tokens from the user's balance.
     */
    function burn(
        address from,
        uint256 amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        mintAccuredInterest(from);
        _burn(from, amount);
    }

    /*
     *@notice: This function transfers tokens from the caller's address to the specified recipient address.
     *@param recipient: The address to which the tokens will be transferred.
     *@param amount: The amount of tokens to be transferred.
     *@dev: This function first mints the accrued interest for both the sender and the recipient, then checks if the recipient's balance is zero and if so, inherits the sender's interest rate.
     *@dev: If the amount is set to the maximum uint256 value, it transfers the entire balance of the sender.
     *@return bool: Returns true if the transfer is successful.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }
        mintAccuredInterest(msg.sender);
        mintAccuredInterest(recipient);
        if (balanceOf(recipient) == 0 && amount > 0) {
            s_userInterestRate[recipient] = s_userInterestRate[msg.sender]; //inherit interest rate
        }

        return super.transfer(recipient, amount);
    }

    /*
     *@notice: This function transfers tokens from one address to another.
     *@param sender: The address from which the tokens will be transferred.
     *@param recipient: The address to which the tokens will be transferred.
     *@param amount: The amount of tokens to be transferred.
     *@dev: This function first mints the accrued interest for both the sender and the recipient, then checks if the recipient's balance is zero and if so, inherits the sender's interest rate.
     *@dev: If the amount is set to the maximum uint256 value, it transfers the entire balance of the sender.
     *@return bool: Returns true if the transfer is successful.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        mintAccuredInterest(sender);
        mintAccuredInterest(recipient);
        if (amount == type(uint256).max) {
            amount = balanceOf(sender);
        }
        if (balanceOf(recipient) == 0 && amount > 0) {
            s_userInterestRate[recipient] = s_userInterestRate[sender]; //inherit interest rate
        }

        return super.transferFrom(sender, recipient, amount);
    }

    /*
     *@notice:This function returns the balance of the user including the accrued interest.
     *@param user: The address of the user whose balance is to be returned.
     *@dev: The balance is calculated by adding the principle balance and the accrued interest since the last update.
     *@return uint256: The total balance of the user including the accrued interest.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        //current principal balance of the user
        uint256 currentPrincipalBalance = super.balanceOf(_user);
        if (currentPrincipalBalance == 0) {
            return 0;
        }
        // shares * current accumulated interest for that user since their interest was last minted to them.
        return
            (currentPrincipalBalance *
                _calculateUserAccumulatedInterestSinceLastUpdate(_user)) /
            PRECISION_FACTOR;
    }

    /*
     *@notice: This function calculates the accumulated interest for a user since their last update.
     *@param user: The address of the user whose accumulated interest is to be calculated.
     *@dev: The interest is calculated by multiplying the user's balance with the interest rate and the time elapsed since the last update.
     *@return uint256: The accumulated interest for the user.
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address user
    ) internal view returns (uint256 linearInterest) {
        uint256 timeDifference = block.timestamp -
            s_userLastUpdatedTimestamp[user];
        // represents the linear growth over time = 1 + (interest rate * time)
        linearInterest =
            (s_userInterestRate[user] * timeDifference) +
            PRECISION_FACTOR;
    }

    /*
     * @notice: This function mints the accrued interest for a user since their last update.
     *@param user: The address of the user whose accrued interest is to be minted.
     */
    function mintAccuredInterest(address user) internal {
        // Current balance of the user for rebase token that they have minted-> principle balance
        //calculate the current balance including any interest-> balanceOf
        //calculate teh number of tokes that need to be minted 2-1
        //call mint to mint the tokens
        uint256 previousPrincipleBalance = super.balanceOf(user);
        uint256 currentBalance = balanceOf(user);
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        s_userLastUpdatedTimestamp[user] = block.timestamp;
        if (balanceIncrease > 0) {
            _mint(user, balanceIncrease);
        }
    }

    /*
     * @notice: This function returns the principle balance of a user. This is the number of tokens that the user has minted without any accrued interest since the last time the user has interacted with the protocol.
     *@param user: The address of the user whose principle balance is to be returned.
     */
    function principleBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getUserInterestRate(
        address userAddress
    ) external view returns (uint256) {
        return s_userInterestRate[userAddress];
    }

    function getPrecisionFactor() external pure returns (uint256) {
        return PRECISION_FACTOR;
    }

    function getUserLastUpdatedTimestamp(
        address userAddress
    ) external view returns (uint256) {
        return s_userLastUpdatedTimestamp[userAddress];
    }
    function getMintAndBurnRole() external pure returns (bytes32) {
        return MINT_AND_BURN_ROLE;
    }
}
