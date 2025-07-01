# Cross-Chain Rebase Token Protocol

## Introduction

This project implements a **cross-chain rebase token protocol** that allows users to deposit ETH into a vault and receive rebase tokens whose balances increase linearly over time, representing accrued interest. The protocol is designed to incentivize early adopters by allowing the global interest rate to only decrease over time. The system supports cross-chain bridging of rebase tokens, preserving user-specific interest rates across chains.

## Features

- **Vault Deposits:** Users deposit ETH and receive rebase tokens at a 1:1 ratio.
- **Rebase Token:** Token balances increase linearly over time, reflecting accrued interest.
- **User-Specific Interest Rates:** Each user's interest rate is set at deposit time and remains fixed for that user.
- **Decreasing Global Interest Rate:** The protocol owner can only decrease the global interest rate, never increase it.
- **Cross-Chain Bridging:** Users can bridge their rebase tokens between supported chains, preserving their accrued interest and user-specific interest rate.
- **Permissioned Mint/Burn:** Only authorized contracts (vault, pool) can mint or burn tokens.

## Architecture

![image](https://github.com/user-attachments/assets/74af9322-84e2-42a1-86ec-11bff2d7f0b6)

- **Vault:** Handles ETH deposits and redemptions, mints/burns rebase tokens.
- **RebaseToken:** ERC20 token with dynamic, linearly increasing balances and user-specific interest rates.
- **RebaseTokenPool:** Handles cross-chain bridging logic, interacts with CCIP.

## Contracts

- `Vault.sol`: Accepts ETH deposits, mints rebase tokens, and allows redemption.
- `RebaseToken.sol`: ERC20 token with dynamic balance logic and interest accrual.
- `RebaseTokenPool.sol`: Bridges tokens cross-chain, preserving user interest rates.
- `IRebaseToken.sol`: Interface for the rebase token.

## How It Works

1. **Deposit:**
   - User deposits ETH into the `Vault`.
   - Vault mints rebase tokens to the user at the current global interest rate.
   - User's interest rate is fixed at deposit time.
2. **Interest Accrual:**
   - User's token balance increases linearly over time, based on their fixed interest rate.
   - The protocol owner can only decrease the global interest rate for new deposits.
3. **Redemption:**
   - User redeems rebase tokens for ETH from the vault.
   - Vault burns the user's tokens and sends the corresponding ETH.
4. **Transfer:**
   - When tokens are transferred, the recipient inherits the sender's interest rate if their balance was zero.
5. **Cross-Chain Bridging:**
   - Users can bridge tokens to another chain using the `RebaseTokenPool` and CCIP.
   - User's interest rate and balance are preserved on the destination chain.

## Getting Started

### Prerequisites
- [Foundry](https://book.getfoundry.sh/) (for Solidity development and testing)
- Node.js (for Chainlink CCIP local simulator, if needed)

### Install Dependencies
Clone the repo and install dependencies:
```sh
git clone <repo-url>
cd ccip-rebase-token
# Install any required submodules or dependencies as needed
```

## Deployment

### 1. Deploy Token and Pool
Use the provided script to deploy the `RebaseToken` and `RebaseTokenPool`:
```sh
forge script script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>
```

### 2. Deploy Vault
```sh
forge script script/Deployer.s.sol:VaultDeployer --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY> --constructor-args <REBASE_TOKEN_ADDRESS>
```

### 3. Configure Pool for Cross-Chain
```sh
forge script script/ConfigurePool.s.sol --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY> --constructor-args <SOURCE_POOL> <DEST_CHAIN_SELECTOR> <DEST_POOL> <REMOTE_TOKEN> <RATE_LIMITER_CONFIGS...>
```

## Bridging Tokens
To bridge tokens between chains:
```sh
forge script script/BridgeTokens.s.sol --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY> --constructor-args <RECEIVER> <DEST_CHAIN_SELECTOR> <TOKEN_ADDRESS> <AMOUNT> <LINK_TOKEN_ADDRESS> <ROUTER_ADDRESS>
```

## Testing

Run the test suite with Foundry:
```sh
forge test
```

- `test/RebaseTokenTest.t.sol`: Unit tests for deposit, interest accrual, redemption, transfer, and permissioning.
- `test/CrossChain.t.sol`: Integration tests for cross-chain bridging and pool configuration.

## Example

- **Deposit ETH:**
  - User calls `Vault.deposit{value: amount}()`
  - Receives rebase tokens at the current interest rate.
- **Redeem:**
  - User calls `Vault.redeem(amount)`
  - Receives ETH back, tokens are burned.
- **Bridge:**
  - Use the bridge script to move tokens to another chain, preserving accrued interest.

## License

MIT
