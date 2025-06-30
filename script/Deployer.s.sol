//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
contract TokenAndPoolDeployer is Script {
    function run()
        public
        returns (RebaseToken rebaseToken, RebaseTokenPool pool)
    {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork
            .getNetworkDetails(block.chainid);
        vm.startBroadcast();
        rebaseToken = new RebaseToken();
        pool = new RebaseTokenPool(
            IERC20(address(rebaseToken)),
            new address[](0), // empty allowlist
            networkDetails.rmnProxyAddress,
            networkDetails.routerAddress
        );
        rebaseToken.grantMintAndBurnRole(address(pool));
        RegistryModuleOwnerCustom(
            networkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(rebaseToken));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(rebaseToken));
        //Link the tokens to the pool
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(
            address(rebaseToken),
            address(pool)
        );
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();

        vault = new Vault(IRebaseToken(rebaseToken));
        IRebaseToken(rebaseToken).grantMintAndBurnRole(address(vault));

        vm.stopBroadcast();
    }
}
