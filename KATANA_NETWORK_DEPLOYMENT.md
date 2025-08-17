# Katana Network Deployment Strategy

## Target: Katana Network (Polygon CDK Chain)

### Architecture Overview
```
Base Sepolia ──CCTP──→ Polygon Amoy ──AggLayer──→ Katana Tatara
     │                      │                          │
MotherVault           BridgeVault              KatanaChildVault
     │                      │                          │
   USDC                   USDC                    Yield Strategies
```

## Network Configurations

### Base Sepolia (Source)
- **Chain ID**: 84532
- **RPC**: https://sepolia.base.org
- **USDC**: 0x036CbD53842c5426634e7929541eC2318f3dCF7e
- **CCTP Domain**: 6

### Polygon Amoy Testnet (Bridge)
- **Chain ID**: 80002
- **RPC**: https://rpc-amoy.polygon.technology
- **USDC**: 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582
- **CCTP Domain**: 7
- **CCTP TokenMessenger**: 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5
- **CCTP MessageTransmitter**: 0x26413e8157CD32011E726065a5462e97dD4d03D9

### Katana Tatara Testnet (Destination)
- **Chain ID**: 129399
- **RPC**: https://rpc.tatara.katanarpc.com
- **Native Token**: ETH
- **Explorer**: https://explorer.tatara.katana.network/
- **Bridge**: AggLayer VaultBridge

### Katana Mainnet (Future)
- **Chain ID**: 747474
- **Status**: Private mainnet (May 2024)
- **TVL**: $240M+ in pre-deposits

## Implementation Phases

### Phase 3A: Polygon Bridge Setup
1. **Deploy BridgeVault on Polygon Amoy**
   - Acts as intermediate holding vault
   - Manages CCTP from Base
   - Prepares funds for AggLayer transfer

2. **Configure CCTP (Base → Polygon)**
   - Set domain mappings
   - Configure message handlers
   - Test USDC bridging

### Phase 3B: AggLayer Integration
1. **Research AggLayer Requirements**
   - VaultBridge integration docs
   - Native token transfer mechanics
   - Cross-chain message format

2. **Deploy Bridge Contracts**
   - AggLayer adapter on Polygon
   - Message relay system
   - Asset tracking

### Phase 3C: Katana Network Deployment
1. **Deploy KatanaChildVault on Tatara**
   - Yield strategy implementation
   - LP position management
   - APY calculation

2. **Connect via AggLayer**
   - Configure VaultBridge
   - Set up cross-chain messaging
   - Test fund flows

## Smart Contract Architecture

### BridgeVault (Polygon Amoy)
```solidity
contract BridgeVault {
    // Receives USDC from Base via CCTP
    function receiveCCTP(uint256 amount, bytes32 sourceAddress) external;
    
    // Bridges to Katana via AggLayer
    function bridgeToKatana(uint256 amount) external;
    
    // Handles returns from Katana
    function receiveFromKatana(uint256 amount) external;
    
    // Routes back to Base
    function returnToBase(uint256 amount, address recipient) external;
}
```

### KatanaChildVault (Katana Network)
```solidity
contract KatanaChildVault is IChildVault {
    // Receives USDC via AggLayer
    function receiveFromPolygon(uint256 amount) external;
    
    // Deploys into Katana yield strategies
    function deployCapital(uint256 amount) external;
    
    // Calculates current APY
    function getAPY() external view returns (uint256);
    
    // Withdraws and bridges back
    function withdrawToPolygon(uint256 amount) external;
}
```

## Two-Hop Message Flow

### Deposit Flow
1. User deposits USDC to MotherVault (Base)
2. MotherVault burns USDC via CCTP
3. BridgeVault mints USDC on Polygon
4. BridgeVault bridges to Katana via AggLayer
5. KatanaChildVault deploys into yield strategies

### Withdrawal Flow
1. User requests withdrawal from MotherVault
2. KatanaChildVault withdraws from strategies
3. Funds bridge to Polygon via AggLayer
4. BridgeVault burns USDC via CCTP
5. MotherVault mints USDC to user (Base)

## Gas Optimization

### Batching Strategy
- Aggregate multiple deposits before bridging
- Set minimum bridge amounts ($100+)
- Daily rebalancing windows

### Cost Analysis
```
Base → Polygon (CCTP): ~$2-3
Polygon → Katana (AggLayer): ~$1-2
Total per hop: ~$3-5
Round trip: ~$6-10
```

## Testing Plan

### Stage 1: CCTP Testing (Week 1)
- [ ] Deploy BridgeVault on Polygon Amoy
- [ ] Test Base → Polygon USDC transfers
- [ ] Verify CCTP message handling
- [ ] Measure gas costs and timing

### Stage 2: Mock AggLayer (Week 1-2)
- [ ] Create AggLayer mock contracts
- [ ] Simulate Polygon → Katana bridging
- [ ] Test two-hop message flow
- [ ] Validate error handling

### Stage 3: Tatara Deployment (Week 2)
- [ ] Deploy KatanaChildVault on Tatara
- [ ] Research actual AggLayer integration
- [ ] Connect all three networks
- [ ] End-to-end testing

## Risk Mitigation

### Bridge Risks
- **CCTP Failure**: Implement retry mechanism
- **AggLayer Delay**: Buffer management on Polygon
- **Gas Spikes**: Dynamic fee adjustment

### Liquidity Management
- Keep 10% buffer on each chain
- Emergency withdrawal paths
- Cross-chain reconciliation

## Success Metrics

### Technical
- Two-hop latency < 10 minutes
- Gas costs < $10 per cycle
- 99.9% bridge success rate

### Business
- Yield from Katana strategies > gas costs
- Smooth user experience despite complexity
- Scalable to $1M+ TVL

## Next Steps

### Immediate (This Week)
1. Create Polygon Amoy deployment script
2. Deploy BridgeVault contract
3. Test CCTP Base → Polygon
4. Research AggLayer documentation

### Following (Next Week)
1. Deploy to Katana Tatara testnet
2. Implement AggLayer bridge
3. Test complete two-hop flow
4. Optimize gas and batching

## Resources

### Documentation
- [Polygon CDK Docs](https://docs.polygon.technology/cdk/)
- [AggLayer Overview](https://polygon.technology/agglayer)
- [CCTP Integration](https://developers.circle.com/cctp)
- [Katana Network](https://katana.network)

### Testnets
- [Polygon Amoy Faucet](https://faucet.polygon.technology/)
- [Tatara Explorer](https://explorer.tatara.katana.network/)
- [Circle USDC Faucet](https://faucet.circle.com/)

This two-hop architecture enables access to Katana Network's deep liquidity and yield strategies while leveraging established CCTP infrastructure for secure cross-chain USDC transfers.