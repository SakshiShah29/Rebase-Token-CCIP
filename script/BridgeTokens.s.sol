//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract BridgeTokens is Script {
    function run(
        address recieverAddress,
        uint64 destinationChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address routerAddressOnSource
    ) external {
        vm.startBroadcast();
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(tokenToSendAddress),
            amount: amountToSend
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(recieverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: ""
        });

        uint256 fee = IRouterClient(routerAddressOnSource).getFee(
            destinationChainSelector,
            message
        );
        IERC20(linkTokenAddress).approve(routerAddressOnSource, fee);

        IERC20(address(tokenToSendAddress)).approve(
            routerAddressOnSource,
            amountToSend
        );

        IRouterClient(routerAddressOnSource).ccipSend(
            destinationChainSelector,
            message
        );
        vm.stopBroadcast();
    }
}
