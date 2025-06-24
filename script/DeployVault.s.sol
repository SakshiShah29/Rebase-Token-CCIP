//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";

contract DeployVault is Script {
    HelperConfig public helperConfig;

    function run() external returns (Vault, RebaseToken, HelperConfig) {
        helperConfig = new HelperConfig();
        (RebaseToken rebaseToken, uint256 deployerPrivateKey) = helperConfig
            .activeNetworkConfig();

        vm.startBroadcast(deployerPrivateKey);
        Vault vault = new Vault(IRebaseToken(address(rebaseToken)));
        // rebaseToken.transferOwnership(address(vault));
        vm.stopBroadcast();
        return (vault, rebaseToken, helperConfig);
    }
}
