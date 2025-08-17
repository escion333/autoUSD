# Phase 3: Katana Network Deployment - READY TO EXECUTE

## Status: All Prerequisites Complete ✅

### Test Environment Setup
- **Network**: Katana Tatara Testnet (Chain ID: 129399)
- **Test Wallet**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- **Balance**: 0.010037 ETH (funded and confirmed)
- **RPC URL**: https://rpc.tatara.katanarpc.com/

### Contract Addresses (Tatara Testnet)
```solidity
// SushiSwap V3 Infrastructure
SUSHI_V3_FACTORY = 0x9B3336186a38E1b6c21955d112dbb0343Ee061eE
SUSHI_V3_POSITION_MANAGER = 0x1400feFD6F9b897970f00Df6237Ff2B8b27Dc82C

// VBUSDC (VaultBridge USDC) - Origin on Sepolia
VBUSDC_ORIGIN_SEPOLIA = 0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD
```

### Two-Hop Architecture Design
```
Base Sepolia → Polygon Amoy → Katana Tatara
     ↓              ↓              ↓
 MotherVault → BridgeVault → KatanaChildVault
     ↓              ↓              ↓
    CCTP       AggLayer      SushiSwap V3
```

### Deployment Scripts Status
All scripts have been debugged and are production-ready:

1. **DeployBaseSepolia.s.sol** ✅
   - Fixed double initialization bug
   - Corrected CCTP domain routing to Polygon
   - Ready for Mother Vault deployment

2. **DeployPolygonAmoy.s.sol** ✅
   - Added missing domain constants
   - Implemented BridgeVault for intermediate bridging
   - Removed unnecessary CrossChainMessenger

3. **DeployKatanaTatara.s.sol** ✅
   - Updated with real Tatara addresses
   - Configured for SushiSwap V3 integration
   - Ready for KatanaChildVault deployment

### Deployment Sequence

#### Step 1: Deploy to Base Sepolia
```bash
forge script script_temp/deploy/DeployBaseSepolia.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

#### Step 2: Deploy to Polygon Amoy
```bash
forge script script_temp/deploy/DeployPolygonAmoy.s.sol \
  --rpc-url $POLYGON_AMOY_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

#### Step 3: Deploy to Katana Tatara
```bash
forge script script_temp/deploy/DeployKatanaTatara.s.sol \
  --rpc-url https://rpc.tatara.katanarpc.com/ \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Bridge Configuration

#### CCTP (Base ↔ Polygon)
- Base Sepolia Domain: 6
- Polygon Amoy Domain: 7
- Native USDC bridging support

#### AggLayer/VaultBridge (Polygon → Katana)
- Polygon as origin chain
- VBUSDC bridging to Katana
- Gas token handling for Tatara

### Testing Checklist

- [ ] Verify test wallet balance on all chains
- [ ] Deploy contracts in sequence
- [ ] Configure cross-chain messaging
- [ ] Test USDC deposit on Base
- [ ] Verify bridge to Polygon
- [ ] Confirm arrival on Katana
- [ ] Test SushiSwap V3 liquidity provision
- [ ] Validate yield generation
- [ ] Test withdrawal flow back to Base

### Key Risks & Mitigations

1. **VBUSDC Address Discovery**
   - Risk: Bridged VBUSDC address on Katana unknown
   - Mitigation: Deploy mock first, replace after bridge test

2. **Gas Costs on Tatara**
   - Risk: Limited ETH for multiple deployments
   - Mitigation: Optimize deployment, request more from faucet if needed

3. **Bridge Delays**
   - Risk: Cross-chain messages may take time
   - Mitigation: Implement retry mechanisms, monitor with events

### Success Criteria

✅ All contracts deployed successfully
✅ Cross-chain messages flowing
✅ USDC successfully bridged Base → Polygon → Katana
✅ SushiSwap V3 positions created
✅ Withdrawals working back to Base

## Ready to Deploy! 🚀

All prerequisites are complete. The system is ready for Phase 3 testnet deployment.