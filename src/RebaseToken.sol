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

/*
 *@title: Rebase Token
 *@author:Sakshi Shah
 *@notice: This is a cross chain rebase token that incentivises the user to deposit into a vault and gain interest in rewards.
 *@notice:The intesrest rate in the contract can only decrease.
 *@notice: Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */
contract RebaseToken is ERC20 {
    // Errors
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 currentInterestRate,
        uint256 newInterestRate
    );

    // State variables
    uint256 private s_interestRate = 5e10; // 0.0000000005% per sec
    mapping(address userAddress => uint256 newInterestRateForUser)
        private s_userInterestRate; // User specific interest rate
        mapping(address=>uint256) private s_userLastUpdatedTimestamp;

    uint256 private constant PRECISION_FACTOR = 1e18; // 18 decimal places

    // Events
    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") {}

    /*
     *@notice: This function is used to set the interest rate for the rebase token.
     *@param _newInterestRate: The new interest rate to be set.
     *@dev: The interest rate can only decrease, if the new interest rate is greater than the current interest rate, it will revert.
     */
    function setUnterestRate(uint256 _newInterestRate) external {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(s_interestRate);
    }

    function mint(address to, uint256 amount) external {
        mintAccount(to);
        s_userInterestRate[to] = s_interestRate;
        _mint(to, amount);
    }

    function balanceOf(address user) public view override returns (uint256) {
   //get the principle balance first
   
    }
    function mintAccount(address user) internal {
        // Current balance of the user for rebase token that they have minted-> principle balance
        //calculate the current balance including any interest-> balanceOf
        //calculate teh number of tokes that need to be minted 2-1 
        //call mint to mint the tokens
        s_userLastUpdatedTimestamp[user] = block.timestamp;

    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
        // Optionally, you can reset the user's interest rate to 0 or keep it unchanged
        // s_userInterestRate[from] = 0; // Uncomment if you want to reset
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
    function getUserInterestRate(address userAddress)
        external
        view
        returns (uint256)
    {
        return s_userInterestRate[userAddress];
    }
    function getPrecisionFactor() external pure returns (uint256) {
        return PRECISION_FACTOR;
    }
}
