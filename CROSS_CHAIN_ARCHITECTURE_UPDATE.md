# Cross-Chain Architecture Update

## Important Clarification: Two Different Katanas

### 1. Katana DEX (Original)
- **Platform**: Ronin Chain
- **Type**: DEX/AMM Protocol  
- **Chain ID**: 2020 (mainnet) / 2021 (Saigon testnet)
- **Bridge**: Ronin Bridge (not CCTP compatible)

### 2. Katana Network (New - 2024)
- **Platform**: Polygon CDK Chain
- **Type**: DeFi-focused L2 connected to AggLayer
- **Launch**: May 2024 (private mainnet)
- **Bridge**: AggLayer VaultBridge
- **TVL**: $240M+ in pre-deposits

## Revised Architecture Options

### Option A: Target Katana Network (AggLayer)
**Flow**: Base → Polygon (CCTP) → Katana Network (AggLayer)

```
Base Sepolia          Polygon Amoy         Katana Network
    │                      │                     │
MotherVault ──CCTP──→ Bridge Vault ──AggLayer──→ KatanaChildVault
    │                      │                     │
   USDC                   USDC                  USDC
```

**Pros:**
- CCTP supports Polygon directly
- AggLayer provides native token transfers
- Deep liquidity from VaultBridge
- Modern infrastructure (2024)

**Cons:**
- Two-hop complexity
- Gas costs on two chains
- AggLayer still evolving

### Option B: Direct to Polygon Only (Simplified)
**Flow**: Base → Polygon (CCTP)

```
Base Sepolia          Polygon Amoy
    │                      │
MotherVault ──CCTP──→ PolygonChildVault
    │                      │
   USDC                   USDC
```

**Pros:**
- Simple one-hop architecture
- CCTP native support
- Proven infrastructure
- Lower gas costs

**Cons:**
- No Katana exposure
- Less innovative

### Option C: Hybrid Approach (Recommended)
**Phase 1**: Base → Polygon (POC validation)
**Phase 2**: Add Katana Network via AggLayer (post-POC)

## Implementation Strategy

### Phase 3A: Polygon Integration (Immediate)
1. Deploy PolygonChildVault on Polygon Amoy testnet
2. Configure CCTP between Base Sepolia and Polygon Amoy
3. Test cross-chain USDC transfers
4. Validate yield generation on Polygon DeFi

### Phase 3B: Katana Network Integration (Future)
1. Research AggLayer integration requirements
2. Deploy bridge contract on Polygon
3. Connect to Katana Network via VaultBridge
4. Route yields back through two-hop path

## Technical Requirements

### CCTP Configuration (Base ↔ Polygon)
```solidity
// Domain IDs
uint32 constant BASE_SEPOLIA_DOMAIN = 6;
uint32 constant POLYGON_AMOY_DOMAIN = 7; // Verify actual ID

// Polygon Amoy Addresses
address constant POLYGON_USDC = 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582;
address constant POLYGON_TOKEN_MESSENGER = 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5;
address constant POLYGON_MESSAGE_TRANSMITTER = 0x26413e8157CD32011E726065a5462e97dD4d03D9;
```

### Hyperlane Configuration
```solidity
// Polygon Amoy Hyperlane
address constant POLYGON_MAILBOX = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766;
address constant POLYGON_IGP = 0x6cA0B6D22da47f091B7613223cD4BB03a2d77918;
```

## Decision Matrix

| Criteria | Option A (Two-Hop) | Option B (Polygon Only) | Option C (Hybrid) |
|----------|-------------------|------------------------|-------------------|
| Complexity | High | Low | Medium |
| Time to Market | 3-4 weeks | 1-2 weeks | 2 weeks + future |
| Innovation | High | Low | High |
| Gas Costs | High | Low | Low initially |
| Risk | High | Low | Low |
| Scalability | Excellent | Good | Excellent |

## Recommendation

**Go with Option C (Hybrid Approach)**

### Rationale:
1. **Faster POC**: Validate core cross-chain mechanics with Polygon first
2. **Future-Proof**: Architecture supports Katana Network addition
3. **Risk Management**: Prove concept before adding complexity
4. **Market Timing**: Launch POC while researching AggLayer

### Next Steps:
1. Update deployment scripts for Polygon Amoy
2. Create PolygonChildVault contract
3. Configure CCTP Base ↔ Polygon
4. Test end-to-end flows
5. Document AggLayer integration path

## Updated Timeline

### Week 1: Polygon Integration
- Deploy to Polygon Amoy testnet
- Configure CCTP bridging
- Test USDC transfers

### Week 2: Cross-Chain Testing  
- End-to-end deposit/withdrawal flows
- Rebalancing logic validation
- Performance benchmarking

### Post-POC: Katana Network
- Research AggLayer requirements
- Design two-hop architecture
- Implement VaultBridge integration

This approach maintains the Katana vision while pragmatically proving the concept with established infrastructure first.