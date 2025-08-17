# Testnet Deployment Guide

## Overview

This guide covers deploying autoUSD to testnets using a two-hop architecture:
- **Base Sepolia** → **Polygon Amoy** → **Katana Tatara**

## Prerequisites

1. **Funded Wallets**:
   - Base Sepolia: ETH for gas
   - Polygon Amoy: MATIC for gas  
   - Katana Tatara: 0.010037 ETH (already funded)

2. **Test USDC**:
   - Get from Circle faucet: https://faucet.circle.com/
   - Select Base Sepolia network
   - Request 10 USDC minimum

## Deployment Sequence

### Step 1: Deploy to Base Sepolia

```bash
# Load environment
source .env.base.sepolia

# Deploy contracts
forge script script_temp/base/DeployBaseSepolia.s.sol \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --slow \
    -vvv

# Save deployed addresses to .env.base.sepolia
```

### Step 2: Deploy to Polygon Amoy

```bash
# Load environment with Mother Vault address
source .env.polygon.amoy
export MOTHER_VAULT_BASE=<address_from_step_1>

# Deploy BridgeVault
forge script script_temp/polygon/DeployPolygonAmoy.s.sol \
    --rpc-url $POLYGON_AMOY_RPC_URL \
    --broadcast \
    --slow \
    -vvv

# Save deployed addresses
```

### Step 3: Deploy to Katana Tatara

```bash
# Load environment with Bridge Vault address
source .env.katana.tatara
export BRIDGE_VAULT_POLYGON=<address_from_step_2>

# Deploy KatanaChildVault
forge script script_temp/katana/DeployKatanaTatara.s.sol \
    --rpc-url $KATANA_TATARA_RPC_URL \
    --broadcast \
    --slow \
    -vvv

# Save deployed addresses
```

## Post-Deployment Configuration

### 1. Connect Cross-Chain Components

On Base Sepolia:
- Add Polygon domain to CrossChainMessenger
- Configure child vault addresses

On Polygon Amoy:
- Set Katana child vault address in BridgeVault
- Configure AggLayer adapter (manual)

On Katana Tatara:
- Update mother vault reference
- Verify SushiSwap pool configuration

### 2. Test Cross-Chain Flow

```bash
# Test deposit flow
cast send $MOTHER_VAULT_BASE "deposit(uint256)" 10000000 \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Monitor bridge status
cast call $BRIDGE_VAULT_POLYGON "getStats()" \
    --rpc-url $POLYGON_AMOY_RPC_URL

# Check child vault balance  
cast call $KATANA_CHILD_VAULT "totalAssets()" \
    --rpc-url $KATANA_TATARA_RPC_URL
```

## Contract Addresses

### Base Sepolia Infrastructure
- USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- CCTP Token Messenger: `0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5`
- CCTP Message Transmitter: `0x7865fAfC2db2093669d92c0F33AeEF291086BEFD`
- Hyperlane Mailbox: `0x6966b0E55883d49BFB24539356a2f8A673E02039`
- Hyperlane IGP: `0x0dD20e410bdB95404f71c5a4e7Fa67B892A5f949`

### Polygon Amoy Infrastructure
- USDC: `0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582`
- CCTP Token Messenger: `0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5`
- CCTP Message Transmitter: `0x7865fAfC2db2093669d92c0F33AeEF291086BEFD`

### Katana Tatara Infrastructure
- SushiSwap V3 Factory: `0x9B3336186a38E1b6c21955d112dbb0343Ee061eE`
- Position Manager: `0x1400feFD6F9b897970f00Df6237Ff2B8b27Dc82C`
- Swap Router: `0x0e4e59f8492cb88033bA5083199eDB37d5039305`
- VBUSDC: `0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD`
- USDT: `0xA617Ec5cBC004A6a8b8ECd965B1ef848350e7e73`

## Troubleshooting

### Compilation Issues
If you encounter "Stack too deep" errors:
```bash
# Use the default profile with via-ir enabled
forge build
```

### Gas Estimation
- Base Sepolia: ~0.01 ETH for deployment
- Polygon Amoy: ~0.1 MATIC for deployment
- Katana Tatara: ~0.005 ETH for deployment

### Faucets
- Base Sepolia ETH: https://www.alchemy.com/faucets/base-sepolia
- Polygon Amoy MATIC: https://faucet.polygon.technology/
- Circle USDC: https://faucet.circle.com/

## Security Notes

1. **Never commit private keys** - Use environment variables
2. **Test with small amounts** - Start with $1-10 USDC
3. **Verify addresses** - Double-check all contract addresses
4. **Monitor bridges** - Watch for stuck transactions

## Next Steps

After successful deployment:
1. Update frontend with testnet addresses
2. Test Circle wallet integration
3. Validate cross-chain rebalancing
4. Run integration tests