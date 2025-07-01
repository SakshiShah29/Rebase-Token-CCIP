#!/bin/bash

# Define constants 
AMOUNT=100000

DEFAULT_ZKSYNC_LOCAL_KEY="0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110"
DEFAULT_ZKSYNC_ADDRESS="0x36615Cf349d7F6344891B1e7CA7C72883F5dc049"

ARBITRUM_REGISTRY_MODULE_OWNER_CUSTOM="0xE625f0b8b0Ac86946035a7729Aba124c8A64cf69"
ARBITRUM_TOKEN_ADMIN_REGISTRY="0x8126bE56454B628a88C17849B9ED99dd5a11Bd2f"
ARBITRUM_ROUTER="0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165"
ARBITRUM_RNM_PROXY_ADDRESS="0x9527E2d01A3064ef6b50c1Da1C0cC523803BCFF2"
ARBITRUM_SEPOLIA_CHAIN_SELECTOR="3478487238524512106"
ARBITRUM_LINK_ADDRESS="0xb1D4538B4571d411F07960EF2838Ce337FE1E80E"

SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0x62e731218d0D47305aba2BE3751E7EE9E5520790"
SEPOLIA_TOKEN_ADMIN_REGISTRY="0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82"
SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_RNM_PROXY_ADDRESS="0xba3f6251de62dED61Ff98590cB2fDf6871FbB991"
SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"

# Compile and deploy the Rebase Token contract
source .env
forge build --via-ir
echo "Compiling and deploying the Rebase Token contract on Arbitrum sepolia..."
ARBITRUM_REBASE_TOKEN_ADDRESS=$(forge create src/RebaseToken.sol:RebaseToken --rpc-url ${ARBITRUM_RPC_URL} --account test-account --broadcast| awk '/Deployed to:/ {print $3}')
echo "Arbitrum rebase token address: $ARBITRUM_REBASE_TOKEN_ADDRESS"

# Compile and deploy the pool contract
echo "Compiling and deploying the pool contract on Arbitrum..."
ARBITRUM_POOL_ADDRESS=$(forge create src/RebaseTokenPool.sol:RebaseTokenPool --rpc-url ${ARBITRUM_RPC_URL} --account test-account --broadcast --constructor-args ${ARBITRUM_REBASE_TOKEN_ADDRESS} [] ${ARBITRUM_RNM_PROXY_ADDRESS} ${ARBITRUM_ROUTER} | awk '/Deployed to:/ {print $3}')
echo "Pool address: $ARBITRUM_POOL_ADDRESS"

# Set the permissions for the pool contract
echo "Setting the permissions for the pool contract on Arbitrum..."
cast send ${ARBITRUM_REBASE_TOKEN_ADDRESS} "grantMintAndBurnRole(address)" ${ARBITRUM_POOL_ADDRESS} --rpc-url ${ARBITRUM_RPC_URL} --account test-account
echo "Pool permissions set"

# Set the CCIP roles and permissions
echo "Setting the CCIP roles and permissions on Arbitrum..."
cast send ${ARBITRUM_REGISTRY_MODULE_OWNER_CUSTOM} "registerAdminViaOwner(address)" ${ARBITRUM_REBASE_TOKEN_ADDRESS} --rpc-url ${ARBITRUM_RPC_URL} --account test-account
cast send ${ARBITRUM_TOKEN_ADMIN_REGISTRY} "acceptAdminRole(address)" ${ARBITRUM_REBASE_TOKEN_ADDRESS} --rpc-url ${ARBITRUM_RPC_URL} --account test-account
cast send ${ARBITRUM_TOKEN_ADMIN_REGISTRY} "setPool(address,address)" ${ARBITRUM_REBASE_TOKEN_ADDRESS} ${ARBITRUM_POOL_ADDRESS} --rpc-url ${ARBITRUM_RPC_URL} --account test-account
echo "CCIP roles and permissions set"

# 2. On Sepolia!

echo "Running the script to deploy the contracts on Sepolia..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${SEPOLIA_RPC_URL} --account test-account --broadcast)
echo "Contracts deployed and permission set on Sepolia"

# Extract the addresses from the output
SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | head -1 | awk '{print $4}')
echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS"

# Deploy the vault 
echo "Deploying the vault on Sepolia..."
VAULT_ADDRESS=$(forge script ./script/Deployer.s.sol:VaultDeployer \
  --rpc-url ${SEPOLIA_RPC_URL} \
  --account test-account \
  --broadcast \
  --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} \
  | grep 'vault: contract Vault' | awk '{print $NF}')
echo "Vault address: $VAULT_ADDRESS"

# Configure the pool on Sepolia
echo "Configuring the pool on Sepolia..."
# uint64 remoteChainSelector,
#         address remotePoolAddress, /
#         address remoteTokenAddress, /
#         bool outboundRateLimiterIsEnabled, false 
#         uint128 outboundRateLimiterCapacity, 0
#         uint128 outboundRateLimiterRate, 0
#         bool inboundRateLimiterIsEnabled, false 
#         uint128 inboundRateLimiterCapacity, 0 
#         uint128 inboundRateLimiterRate 0 
forge script ./script/ConfigurePool.s.sol:ConfigurePool --rpc-url ${SEPOLIA_RPC_URL} --account test-account --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${SEPOLIA_POOL_ADDRESS} ${ARBITRUM_SEPOLIA_CHAIN_SELECTOR} ${ARBITRUM_POOL_ADDRESS} ${ARBITRUM_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0
echo "Ran ConfigurePoolScript with:"
echo "SEPOLIA_POOL_ADDRESS = ${SEPOLIA_POOL_ADDRESS}"
echo "ARBITRUM_SEPOLIA_CHAIN_SELECTOR = ${ARBITRUM_SEPOLIA_CHAIN_SELECTOR}"
echo "ARBITRUM_POOL_ADDRESS = ${ARBITRUM_POOL_ADDRESS}"
echo "ARBITRUM_REBASE_TOKEN_ADDRESS = ${ARBITRUM_REBASE_TOKEN_ADDRESS}"

# Deposit funds to the vault
echo "Depositing funds to the vault on Sepolia..."
cast send ${VAULT_ADDRESS} "deposit()" --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account test-account

# Wait a beat for some interest to accrue

# Configure the pool on Arbitrum
echo "Configuring the pool on Arbitrum..."
ENCODED_REMOTE_POOL=$(cast abi-encode "f(address)" ${SEPOLIA_POOL_ADDRESS})
ENCODED_REMOTE_TOKEN=$(cast abi-encode "f(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS})
cast send ${ARBITRUM_POOL_ADDRESS} \
  "applyChainUpdates((uint64,bool,bytes,bytes,(bool,uint128,uint128),(bool,uint128,uint128))[])" \
  "[(${SEPOLIA_CHAIN_SELECTOR}, true, ${ENCODED_REMOTE_POOL}, ${ENCODED_REMOTE_TOKEN}, (false,0,0), (false,0,0))]" \
  --rpc-url ${ARBITRUM_RPC_URL} --account test-account

# Bridge the funds using the script to Arbitrum 
echo "Bridging the funds using the script to Arbitrum..."
SEPOLIA_BALANCE_BEFORE=$(cast balance $(cast wallet address --account test-account) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"
forge script ./script/BridgeTokens.s.sol:BridgeTokens --rpc-url ${SEPOLIA_RPC_URL} --account test-account --broadcast --sig "run(address,uint64,address,uint256,address,address)" $(cast wallet address --account test-account) ${ARBITRUM_SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER}
echo "Funds bridged to Arbitrum"
SEPOLIA_BALANCE_AFTER=$(cast balance $(cast wallet address --account test-account) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER"

