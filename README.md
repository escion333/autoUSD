# autoUSD

Cross-chain USDC yield optimizer enabling automated yield farming across Layer 2 networks.

## Overview

autoUSD is a decentralized protocol that optimizes USDC yields across multiple Layer 2 networks through automated rebalancing. Users deposit USDC once and the protocol automatically distributes funds to maximize returns across supported chains.

### Key Features

- **Single Deposit Interface**: Deposit USDC on Base L2 through an ERC-4626 compliant vault
- **Multi-Chain Yield Generation**: Automated distribution across Base, Katana, and Zircuit
- **Dynamic Rebalancing**: APY-driven rebalancing when yield differentials exceed thresholds
- **Cross-Chain Infrastructure**: Leverages Circle CCTP and Hyperlane for secure bridging
- **Gasless Transactions**: Circle Paymaster integration for sponsored transactions
- **Emergency Controls**: System-wide pause functionality for risk management

## Architecture

The protocol consists of:
- **Mother Vault**: Main vault on Base L2 handling deposits/withdrawals
- **Child Vaults**: Yield-generating vaults deployed on each target L2
- **Rebalancing Engine**: Automated system optimizing yields across chains
- **Cross-chain Messaging**: Hyperlane V3 for coordination between vaults

## Development Setup

### Prerequisites

- Node.js >= 18.0.0
- Foundry toolkit
- pnpm package manager

### Installation

```bash
# Install dependencies
pnpm install

# Build contracts
forge build

# Run tests
forge test
```

### Environment Variables

Create a `.env` file with:

```
BASE_RPC_URL=
BASE_SEPOLIA_RPC_URL=
KATANA_RPC_URL=
ZIRCUIT_RPC_URL=
BASESCAN_API_KEY=
PRIVATE_KEY=
```

## Testing

```bash
# Run all tests
pnpm test

# Run unit tests
pnpm test:unit

# Run integration tests
pnpm test:integration

# Run fork tests
pnpm test:fork

# Generate coverage report
pnpm coverage
```

## Deployment

Deployment scripts are located in the `scripts/` directory. 

```bash
# Deploy to testnet
pnpm deploy:testnet

# Deploy to mainnet
pnpm deploy:mainnet
```

## Security

This protocol handles user funds and implements cross-chain operations. Security considerations:

- All contracts are upgradeable with time-locked admin functions
- Emergency pause functionality across all chains
- Comprehensive test coverage including fuzz tests
- Formal verification of critical functions
- Regular security audits

## License

MIT