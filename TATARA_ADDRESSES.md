# Katana Tatara Testnet - Real Contract Addresses

## Network Information
- **Chain ID**: 129399 (0x1f977)
- **RPC URL**: https://rpc.tatara.katanarpc.com/
- **Explorer**: https://explorer.tatara.katana.network/

## SushiSwap V3 Contracts on Tatara

### Core Contracts
```solidity
// SushiSwap V3 Factory
address constant SUSHI_V3_FACTORY = 0x9B3336186a38E1b6c21955d112dbb0343Ee061eE;

// SushiSwap V3 Position Manager (NFT positions)
address constant SUSHI_V3_POSITION_MANAGER = 0x1400feFD6F9b897970f00Df6237Ff2B8b27Dc82C;

// SushiSwap V3 Router - TODO: Need to obtain or may use Position Manager
address constant SUSHI_V3_ROUTER = address(0); // Not provided yet
```

## VaultBridge USDC (VBUSDC)

### Important: VBUSDC Origin Addresses
VBUSDC exists on the **origin chain**, not directly on Katana:

```solidity
// For Tatara testnet: Origin is Sepolia
address constant VBUSDC_ORIGIN_SEPOLIA = 0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD;

// For Bokuto testnet: Origin is also Sepolia (different address)
address constant VBUSDC_ORIGIN_BOKUTO = 0xb62Ba071952770130939a175d0e3CBF1770dd38;

// For Mainnet: Origin is Ethereum
address constant VBUSDC_ORIGIN_ETHEREUM = 0x53E82ABbb12638F09d9e624578ccB666217a765e;
```

### Key Functions in VBUSDC
- `depositAndBridge()` - Deposit USDC and bridge to Katana
- `depositGasTokenAndBridge()` - Bridge with gas token
- `yieldVaultMaximumSlippagePercentage()` - Slippage settings
- `backingDifference()` - Yield tracking

## Architecture Notes

### VaultBridge Flow
1. **Origin Chain (Sepolia)**: User deposits USDC to VBUSDC contract
2. **Bridge Operation**: VBUSDC bridges funds to Katana via VaultBridge
3. **Katana Tatara**: Bridged VBUSDC appears with a different address
4. **SushiSwap V3**: Deploy bridged VBUSDC into liquidity pools

### SushiSwap V3 Integration
- Uses **Position Manager** for creating/managing liquidity positions
- Factory creates new pools for token pairs
- Concentrated liquidity with custom price ranges
- NFT positions for tracking LP ownership

## Deployment Considerations

### What We Have
✅ SushiSwap V3 Factory address
✅ SushiSwap V3 Position Manager address
✅ VBUSDC origin contract addresses
✅ Network RPC and explorer

### What We Need
⚠️ VBUSDC address on Tatara after bridging
⚠️ SushiSwap V3 Router address (or confirm Position Manager usage)
⚠️ AggLayer/VaultBridge integration details
⚠️ Gas token requirements for Tatara

## Testing Strategy

### Option 1: Bridge Test USDC
1. Get test USDC on Sepolia
2. Deposit to VBUSDC origin contract (0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD)
3. Bridge to Tatara
4. Note the bridged VBUSDC address on Tatara
5. Use in our KatanaChildVault

### Option 2: Deploy Mock VBUSDC
1. Deploy a mock ERC20 as VBUSDC on Tatara
2. Use for testing SushiSwap V3 integration
3. Replace with real bridged address later

## Updated Deployment Script Usage

```bash
# Deploy to Tatara with real addresses
forge script script_temp/deploy/DeployKatanaTatara.s.sol \
  --rpc-url https://rpc.tatara.katanarpc.com/ \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

# The script uses:
# - Real SushiSwap V3 Factory: 0x9B3336186a38E1b6c21955d112dbb0343Ee061eE
# - Real Position Manager: 0x1400feFD6F9b897970f00Df6237Ff2B8b27Dc82C
# - VBUSDC origin for reference (actual bridged address TBD)
```

## Resources
- Contract Directory: https://contracts.katana.tools/
- Katana Docs: https://superdocs.katana.tools/
- Explorer: https://explorer.tatara.katana.network/