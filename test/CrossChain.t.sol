// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
contract CrossChain is Test {
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    uint256 SEND_VALUE = 1e5;
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;
    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;
    Vault vault;
    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;
    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia-eth");
        arbSepoliaFork = vm.createSelectFork("arb-sepolia");
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork)); //making it persistant accross the network

        //1. Deploy and configure on sepolia
        vm.selectFork(sepoliaFork);
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.startPrank(owner); // Assuming the owner is the deployer and owner of the sepoliaToken
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        sepoliaToken.grantMintAndBurnRole(address(vault));
        RegistryModuleOwnerCustom(
            sepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(sepoliaToken)); //Accepting the admin role for the token in the TokenAdminRegistry
        //Linking tokens to the pool
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(sepoliaToken), address(sepoliaPool));
        address expectedPoolInSource = TokenAdminRegistry(
            sepoliaNetworkDetails.tokenAdminRegistryAddress
        ).getPool(address(sepoliaToken));
        assertEq(
            expectedPoolInSource,
            address(sepoliaPool),
            "TokenAdminRegistry mapping failed"
        );
        vm.stopPrank();

        // 2. Deploy and configure on arb-sepolia
        vm.selectFork(arbSepoliaFork);
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.startPrank(owner); // Assuming the owner is the deployer  and owner of the arbSepoliaToken
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(
            arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(arbSepoliaToken)); // nominating owner as the pending admin of the token
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(arbSepoliaToken)); //Accepting the admin role for the token in the TokenAdminRegistry
        //Linking tokens to the pool
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaToken), address(arbSepoliaPool));
        address expectedPoolInDestination = TokenAdminRegistry(
            arbSepoliaNetworkDetails.tokenAdminRegistryAddress
        ).getPool(address(arbSepoliaToken));
        assertEq(
            expectedPoolInDestination,
            address(arbSepoliaPool),
            "TokenAdminRegistry mapping failed"
        );
        vm.stopPrank();
        // Configure Sepolia Pool to interact with the Arbitrum Sepolia Pool
        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaPool),
            address(arbSepoliaToken)
        );
        // Configure Arbitrum Sepolia Pool to interact with the Sepolia Pool
        configureTokenPool(
            arbSepoliaFork,
            address(arbSepoliaPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaPool),
            address(sepoliaToken)
        );
    }

    function configureTokenPool(
        uint256 fork,
        address sourcePoolAddress,
        uint64 remoteChainSelector,
        address remotePoolAddress,
        address remoteTokenAddress
    ) public {
        vm.selectFork(fork);
        vm.startPrank(owner);
        TokenPool.ChainUpdate[]
            memory chainUpdates = new TokenPool.ChainUpdate[](1);

        // The remote pool address needs to be Abi encoded as bytes
        // CCIP expects an array of remote pool addresses even if there is just one primary address
        bytes[] memory remotePoolAddressesBytesArray = new bytes[](1);
        remotePoolAddressesBytesArray[0] = abi.encode(remotePoolAddress);
        //   struct ChainUpdate {
        //     uint64 remoteChainSelector; // ──╮ Remote chain selector
        //     bool allowed; // ────────────────╯ Whether the chain should be enabled
        //     bytes remotePoolAddress; //        Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //     bytes remoteTokenAddress; //       Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
        //     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
        //   }
        console.log("Configuring pool on fork", fork);
        console.log("Remote token address:", remoteTokenAddress);
        console.logBytes(abi.encodePacked(remoteTokenAddress));
        chainUpdates[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: remotePoolAddressesBytesArray[0],
            remoteTokenAddress: abi.encode(address(remoteTokenAddress)),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });

        TokenPool(sourcePoolAddress).applyChainUpdates(chainUpdates);
        vm.stopPrank();
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 sourceFork,
        uint256 destinationFork,
        Register.NetworkDetails memory sourceNetworkDetails,
        Register.NetworkDetails memory destinationNetworkDetails,
        RebaseToken sourceToken,
        RebaseToken destinationToken
    ) public {
        vm.selectFork(sourceFork);
        vm.startPrank(user);
        //     struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains
        //     bytes data; // Data payload
        //     EVMTokenAmount[] tokenAmounts; // Token transfers
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
        //   }
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(sourceToken),
            amount: amountToBridge
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: sourceNetworkDetails.linkAddress,
            extraArgs: ""
        });

        uint256 fee = IRouterClient(sourceNetworkDetails.routerAddress).getFee(
            destinationNetworkDetails.chainSelector,
            message
        );
        //fund link tokens to the user first
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user);
        IERC20(sourceNetworkDetails.linkAddress).approve(
            sourceNetworkDetails.routerAddress,
            fee
        );

        uint256 sourceTokenBalanceBefore = sourceToken.balanceOf(user);
        vm.prank(user);
        IERC20(address(sourceToken)).approve(
            sourceNetworkDetails.routerAddress,
            amountToBridge
        );
        vm.prank(user);
        IRouterClient(sourceNetworkDetails.routerAddress).ccipSend(
            destinationNetworkDetails.chainSelector,
            message
        );
        uint256 sourceTokenBalanceAfter = sourceToken.balanceOf(user);
        assertEq(
            sourceTokenBalanceAfter,
            sourceTokenBalanceBefore - amountToBridge,
            "Source token balance should decrease by the bridged amount"
        );
        uint256 sourceUserInterestRate = IRebaseToken(address(sourceToken))
            .getUserInterestRate(user);

        //propogate mssg cross chain
        vm.selectFork(destinationFork);
        vm.warp(block.timestamp + 900); // Ensure the block timestamp is updated to allow processing of the message
        uint destinationBalancBefore = destinationToken.balanceOf(user);
        vm.selectFork(sourceFork); // in the latest version of chainlink-local, it assumes you are currently on the local fork before calling switchChainAndRouteMessage
        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);
        uint destinationBalanceAfter = destinationToken.balanceOf(user);
        assertEq(
            destinationBalanceAfter,
            destinationBalancBefore + amountToBridge,
            "Destination token balance should increase by the bridged amount"
        );
        uint256 destinationUserInterestRate = IRebaseToken(
            address(destinationToken)
        ).getUserInterestRate(user);
        assertEq(
            destinationUserInterestRate,
            sourceUserInterestRate,
            "User interest rate should be the same on both chains"
        );
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        //To send ETH(msg.value) with a contract call
        //Cast contract instance to address, then payable,then back to contract type
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(
            sepoliaToken.balanceOf(user),
            SEND_VALUE,
            "User should have minted rebase tokens equal to the deposited ETH"
        );
        // Bridge tokens from Sepolia to Arbitrum Sepolia
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaToken,
            arbSepoliaToken
        );
    }
}
