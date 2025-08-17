# Deployment Sequence Guide

## Overview
autoUSD uses a two-hop architecture: **Base → Polygon → Katana**

## Step 1: Understand VaultBridge USDC Setup

### VBUSDC Architecture
VaultBridge USDC exists on the **origin chain**, not on Katana:
- **For Tatara testnet**: Origin is Sepolia (0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD)
- **For mainnet**: Origin is Ethereum (0x53E82ABbb12638F09d9e624578ccB666217a765e)

When VBUSDC is bridged to Tatara, it gets a different address on the destination chain.

## Step 2: Deploy KatanaChildVault on Tatara

### Tatara Testnet Details
- Chain ID: 129399
- RPC: https://rpc.tatara.katanarpc.com/
- Explorer: https://explorer.tatara.katana.network/

### Real Contract Addresses (from contracts.katana.tools)
- SushiSwap V3 Factory: `0x9B3336186a38E1b6c21955d112dbb0343Ee061eE`
- SushiSwap V3 Position Manager: `0x1400feFD6F9b897970f00Df6237Ff2B8b27Dc82C`
- VBUSDC Origin (Sepolia): `0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD`

```bash
# Deploy to Tatara testnet with real SushiSwap addresses
forge script script_temp/deploy/DeployKatanaTatara.s.sol \
  --rpc-url https://rpc.tatara.katanarpc.com/ \
  --broadcast
```

## Step 3: Deploy BridgeVault on Polygon Amoy

```bash
# Deploy to Polygon Amoy testnet
forge script script_temp/deploy/DeployPolygonAmoy.s.sol \
  --rpc-url https://rpc-amoy.polygon.technology \
  --broadcast
```

## Step 4: Deploy MotherVault on Base Sepolia

```bash
# Deploy to Base Sepolia
forge script script_temp/deploy/DeployBaseSepolia.s.sol \
  --rpc-url https://sepolia.base.org \
  --broadcast
```

## Step 5: Configure Cross-Chain Connections

### On Base Sepolia
1. Set Polygon BridgeVault as child vault
2. Configure CCTP domain mapping to Polygon

### On Polygon Amoy
1. Set Base MotherVault address
2. Set Katana ChildVault address
3. Configure AggLayer adapter

### On Katana Bokuto
1. Set Polygon BridgeVault as source
2. Configure yield strategies

## Local Testing Alternative

### Using Anvil Fork
```bash
# Fork Katana mainnet locally
anvil --fork-url https://rpc.katana.network/ \
      --fork-block-number 1000000 \
      --chain-id 747474 \
      --port 8545

# Deploy all contracts locally
forge script script_temp/deploy/DeployKatanaMocks.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast
```

## Architecture Summary

```
Base Sepolia (Mother Vault)
    ↓ CCTP (Domain 6→7)
Polygon Amoy (Bridge Vault)
    ↓ AggLayer/VaultBridge
Katana Tatara (Child Vault)
    ↓ SushiSwap V3
VBUSDC Liquidity Pools
```

## Key Addresses

### Base Sepolia
- USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- CCTP Token Messenger: `0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5`

### Polygon Amoy  
- USDC: `0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582`
- CCTP Token Messenger: `0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5`

### Katana Tatara
- VBUSDC Origin (Sepolia): `0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD`
- SushiSwap V3 Factory: `0x9B3336186a38E1b6c21955d112dbb0343Ee061eE`
- SushiSwap V3 Position Manager: `0x1400feFD6F9b897970f00Df6237Ff2B8b27Dc82C`

## Notes

1. **VBUSDC**: Katana uses VaultBridge Bridged USDC, not native USDC
2. **SushiSwap V3**: Capital-efficient AMM with concentrated liquidity (deployed on Tatara)
3. **VaultBridge**: VBUSDC bridging from origin chains (Sepolia for testnet)
4. **Testing**: Use Tatara testnet with real SushiSwap V3 contracts

## Mainnet Migration

When ready for mainnet:
1. Get actual SushiSwap V3 addresses on Katana mainnet
2. Get VBUSDC contract address
3. Update deployment scripts with mainnet addresses
4. Deploy to mainnet in same sequence