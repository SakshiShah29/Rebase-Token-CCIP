// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        RebaseToken rebaseToken;
        uint256 deployerPrivateKey;
    }
    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            // Sepolia
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 31337) {
            // Anvil
            activeNetworkConfig = getOrCreateAnvilConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                rebaseToken: RebaseToken(address(0x00)),
                deployerPrivateKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.rebaseToken == RebaseToken(address(0))) {
            vm.startBroadcast(DEFAULT_ANVIL_KEY);
            RebaseToken rebaseToken = new RebaseToken();
            vm.stopBroadcast();
            activeNetworkConfig.rebaseToken = rebaseToken;
            activeNetworkConfig.deployerPrivateKey = DEFAULT_ANVIL_KEY;
        }
        return activeNetworkConfig;
    }
}
