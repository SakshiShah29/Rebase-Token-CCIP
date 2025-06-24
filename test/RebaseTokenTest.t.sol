// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vault} from "../src/Vault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DeployVault} from "../script/DeployVault.s.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    IRebaseToken public i_rebaseToken;
    HelperConfig public helperConfig;
    Vault public vault;
    DeployVault public deployer;
    address public deployerAddress;

    address public user = makeAddr("user");
    address public owner = makeAddr("owner");
    function setUp() public {
        deployer = new DeployVault();
        (vault, rebaseToken, helperConfig) = deployer.run();
        i_rebaseToken = IRebaseToken(address(rebaseToken));
        (, uint256 deployerPrivateKey) = helperConfig.activeNetworkConfig();
        deployerAddress = vm.addr(deployerPrivateKey);
        vm.startPrank(deployerAddress);
        vm.deal(deployerAddress, 1e18);
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 amount) public {
        (bool success, ) = payable(vault).call{value: amount}("");
        require(success, "Vault funding failed");
    }

    // RebaseToken Tests
    //Deposit

    function testInterestIsLinearOnDeposit(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        //deposit
        //check rebase token balance
        //warp time and check balance again
        //  warp the time again by same amount and check balance again
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        console.log("Initial Balance: %s", initialBalance);
        assertEq(initialBalance, amount);
        vm.warp(block.timestamp + 1 hours);
        uint256 balanceAfterOneHour = rebaseToken.balanceOf(user);
        assertGt(
            balanceAfterOneHour,
            initialBalance,
            "Balance should increase after one hour"
        );
        uint256 balanceDifference = balanceAfterOneHour - initialBalance;
        vm.warp(block.timestamp + 1 hours);
        uint256 balanceAfterTwoHours = rebaseToken.balanceOf(user);
        assertGt(
            balanceAfterTwoHours,
            balanceAfterOneHour,
            "Balance should increase after two hours"
        );
        uint256 secondBalanceDifference = balanceAfterTwoHours -
            balanceAfterOneHour;
        assertApproxEqAbs(balanceDifference, secondBalanceDifference, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        console.log("Initial Balance: %s", initialBalance);
        assertEq(initialBalance, amount);

        // Redeem immediately
        vault.redeem(type(uint256).max);
        uint256 finalBalance = rebaseToken.balanceOf(user);
        console.log("Final Balance after redeem: %s", finalBalance);
        assertEq(
            finalBalance,
            0,
            "Final balance should be zero after redeeming all tokens"
        );
        assertEq(
            address(user).balance,
            amount,
            "User should receive the exact amount of ETH they deposited"
        );
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e5, type(uint96).max);
        time = bound(time, 1 hours, type(uint96).max);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        // Warp time
        vm.warp(block.timestamp + time);
        uint256 balance = rebaseToken.balanceOf(user);
        //add rewards to vault
        vm.deal(deployerAddress, balance - amount);

        // Add rewards to vault
        vm.prank(deployerAddress);
        addRewardsToVault(balance - amount);
        vm.prank(user);
        vault.redeem(type(uint256).max); // Redeem all tokens

        uint256 finalBalance = rebaseToken.balanceOf(user);
        console.log("Final Balance after redeem: %s", finalBalance);
        assertEq(
            finalBalance,
            0,
            "Final balance should be zero after redeeming all tokens"
        );
        assertEq(
            address(user).balance,
            balance,
            "User should receive the exact amount of ETH they deposited plus interest"
        );
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 2e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address recipient = makeAddr("recipient");
        uint256 initialBalanceUser = rebaseToken.balanceOf(user);
        uint256 initialBalanceRecipient = rebaseToken.balanceOf(recipient);
        assertEq(
            initialBalanceUser,
            amount,
            "Initial balance of user should match deposited amount"
        );
        assertEq(
            initialBalanceRecipient,
            0,
            "Initial balance of recipient should be zero"
        );

        //owner reduces interest rate
        vm.prank(deployerAddress);
        rebaseToken.setInterestRate(4e10);
        assertEq(
            rebaseToken.getInterestRate(),
            4e10,
            "Interest rate should be set to 4e10"
        );

        vm.prank(user);
        rebaseToken.transfer(recipient, amountToSend); // Transfer tokens to recipient
        console.log("BAlance of user", rebaseToken.balanceOf(user));

        uint256 finalBalanceUser = rebaseToken.balanceOf(user);
        uint256 finalBalanceRecipient = rebaseToken.balanceOf(recipient);

        assertEq(
            finalBalanceUser,
            initialBalanceUser - amountToSend,
            "Final balance of user should be reduced by the transferred amount"
        );
        assertEq(
            finalBalanceRecipient,
            initialBalanceRecipient + amountToSend,
            "Final balance of recipient should be increased by the transferred amount"
        );

        //check if the user interest rate has been interited by the recipient
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        uint256 recipientInterestRate = rebaseToken.getUserInterestRate(
            recipient
        );
        assertEq(
            recipientInterestRate,
            userInterestRate,
            "Recipient should inherit the user's interest rate"
        );
    }

    function testCannotSetInterestRateIfNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        rebaseToken.setInterestRate(4e10);
        vm.stopPrank();
    }

    function testCannotMintAndBurnIfNotMintAndBurnRole(uint256 amount) public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                rebaseToken.getMintAndBurnRole()
            )
        );
        uint256 interestRate = rebaseToken.getInterestRate();
        rebaseToken.mint(user, amount, interestRate);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                rebaseToken.getMintAndBurnRole()
            )
        );
        rebaseToken.burn(user, amount);
        vm.stopPrank();
    }
    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 principleAmount = rebaseToken.principleBalanceOf(user);
        assertEq(
            principleAmount,
            amount,
            "Principle amount should match the deposited amount"
        );

        // Warp time to accrue interest
        vm.warp(block.timestamp + 1 hours);
        uint256 newPrincipleAmount = rebaseToken.principleBalanceOf(user);
        assertEq(
            newPrincipleAmount,
            amount,
            "Principle amount should remain the same after interest accrual"
        );
    }

    function testGetRebaseTokenAddress() public {
        address rebaseTokenAddress = vault.getRebaseTokenAddress();
        assertEq(
            rebaseTokenAddress,
            address(rebaseToken),
            "Rebase token address should match the deployed contract address"
        );
    }

    function testGetInterestRate() public {
        uint256 interestRate = rebaseToken.getInterestRate();
        assertEq(interestRate, 5e10, "Initial interest rate should be 5e10");
    }

    function testGetUserInterestRate() public {
        vm.startPrank(user);
        vm.deal(user, 1e18);
        vault.deposit{value: 1e18}();
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        assertEq(
            userInterestRate,
            5e10,
            "User interest rate should match the initial interest rate"
        );
        vm.stopPrank();
    }

    function testGetPrecisionFactor() public {
        uint256 precisionFactor = rebaseToken.getPrecisionFactor();
        assertEq(precisionFactor, 1e18, "Precision factor should be 1e18");
    }
    function testGetUserLastUpdatedTimestamp() public {
        vm.startPrank(user);
        vm.deal(user, 1e18);
        vault.deposit{value: 1e18}();
        uint256 lastUpdatedTimestamp = rebaseToken.getUserLastUpdatedTimestamp(
            user
        );
        assertEq(
            lastUpdatedTimestamp,
            block.timestamp,
            "User's last updated timestamp should match the current block timestamp"
        );
        vm.stopPrank();
    }

    function testRevertsIfInterestRateSetHigherByTheOwner(
        uint256 newInterestRate
    ) public {
        newInterestRate = bound(newInterestRate, 6e10, type(uint256).max);
        vm.startPrank(deployerAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector,
                5e10,
                newInterestRate
            )
        );
        rebaseToken.setInterestRate(newInterestRate);
        vm.stopPrank();
    }
}
