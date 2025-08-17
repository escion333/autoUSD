# Base Sepolia Deployment Guide

## Phase 2: Base Sepolia Testnet Integration

This document outlines the deployment of autoUSD Mother Vault to Base Sepolia testnet with $100 deposit cap.

## Prerequisites

### 1. Environment Setup
```bash
# Copy testnet configuration
cp .env.base.sepolia .env

# Add your deployer private key to .env
PRIVATE_KEY=your_private_key_here

# Add Basescan API key for contract verification
BASESCAN_API_KEY=your_basescan_api_key_here
```

### 2. Base Sepolia Infrastructure

**Verified Contract Addresses:**
- USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- CCTP TokenMessenger: `0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5`
- CCTP MessageTransmitter: `0x7865fAfC2db2093669d92c0F33AeEF291086BEFD`
- Hyperlane Mailbox: `0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766`
- Interchain Gas Paymaster: `0x931ca6CE4d0c93F3625c317C5A6a9618e2b0E8a3`

**Domain IDs:**
- Base Sepolia: `6`
- Katana Testnet: `30` (placeholder - verify actual)

## Deployment Process

### 1. Deploy Mother Vault
```bash
forge script script_temp/deploy/DeployBaseSepolia.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

### 2. Expected Contracts
- **MotherVault**: ERC-4626 vault with $100 cap
- **CCTPBridge**: Cross-chain USDC bridging
- **CrossChainMessenger**: Hyperlane messaging
- **Rebalancer**: Yield optimization logic
- **YieldDistributor**: Fee collection (0.5% management)
- **HealthMonitor**: System monitoring

### 3. Protocol Configuration
- Deposit Cap: $100 USDC (100e6)
- Management Fee: 0.5% (50 bps)
- Rebalance Threshold: 5% (500 bps)
- Rebalance Cooldown: 1 hour

## Testing Checklist

### ✅ Deployment Verification
- [ ] All contracts deployed successfully
- [ ] Contract verification on Basescan
- [ ] Deployment data saved to `deployments/base_sepolia.env`
- [ ] Mother Vault accepts deposits up to $100 cap
- [ ] CCTP bridge configured for Katana domain

### 🔄 Circle Wallet Integration
- [ ] Circle Developer Controlled Wallets SDK connected
- [ ] Test wallet creation and management
- [ ] Gasless transaction testing
- [ ] USDC approval and deposit flows
- [ ] Real-time balance updates

### 💰 Test USDC Acquisition
- [ ] Obtain Base Sepolia test USDC from Circle faucet
- [ ] Test small deposits ($1-10)
- [ ] Verify share minting calculations
- [ ] Test withdrawal functionality

### 🌉 Cross-Chain Preparation
- [ ] Hyperlane messaging configuration
- [ ] Domain mappings verified
- [ ] Ready for Katana testnet deployment

## Circle Wallet Testing

### Setup Circle Developer Controlled Wallets
1. **API Configuration**
   ```typescript
   // Use sandbox environment for testnet
   const circle = new W3SSdk({
     apiKey: process.env.CIRCLE_API_KEY,
     entitySecret: process.env.CIRCLE_ENTITY_SECRET,
     environment: 'sandbox'
   });
   ```

2. **Wallet Creation**
   ```typescript
   // Create user wallet for Base Sepolia
   const wallet = await circle.createWallet({
     blockchains: ['BASE-SEPOLIA'],
     count: 1,
     walletSetId: process.env.CIRCLE_WALLET_SET_ID
   });
   ```

3. **Gasless Transactions**
   ```typescript
   // Configure paymaster for Base Sepolia
   const paymaster = {
     url: "https://api.circle.com/v1/w3s/paymaster",
     policyId: process.env.CIRCLE_PAYMASTER_POLICY_ID
   };
   ```

### Test Scenarios

#### Basic Functionality
1. **Wallet Creation**: Create new user wallet
2. **Balance Check**: Read USDC balance
3. **Deposit Flow**: Approve USDC → Deposit to vault → Receive shares
4. **Withdrawal Flow**: Burn shares → Receive USDC

#### Advanced Testing
1. **Gasless Deposits**: User pays no gas fees
2. **Real-time Updates**: UI reflects balance changes
3. **Error Handling**: Network failures, insufficient funds
4. **Cap Enforcement**: Reject deposits exceeding $100

## Next Steps

### Immediate (Phase 2)
1. Complete Base Sepolia deployment
2. Test Circle wallet integration
3. Obtain and test with Base Sepolia USDC
4. Validate all user flows

### Following (Phase 3)
1. Deploy KatanaChildVault on Katana testnet
2. Configure real CCTP between Base and Katana
3. Test end-to-end cross-chain operations
4. Validate rebalancing logic

## Troubleshooting

### Common Issues
1. **Compilation Timeout**: Use `--via-ir=false` for faster builds
2. **Address Checksum**: Ensure proper address formatting
3. **Gas Estimation**: Use higher gas limits for complex deployments
4. **CCTP Verification**: Check domain IDs match actual networks

### Resources
- [Circle USDC Testnet Faucet](https://faucet.circle.com/)
- [Base Sepolia Explorer](https://sepolia.basescan.org/)
- [Hyperlane Documentation](https://docs.hyperlane.xyz/)
- [Circle Developer Controlled Wallets](https://developers.circle.com/developer-controlled-wallets)

## Success Criteria

**Phase 2 Complete When:**
- ✅ Mother Vault deployed and verified on Base Sepolia
- ✅ Circle wallets create and manage user accounts
- ✅ Gasless deposits work end-to-end
- ✅ Test USDC flows through the system
- ✅ All safety mechanisms (caps, fees) functional
- ✅ Ready for cross-chain integration (Phase 3)