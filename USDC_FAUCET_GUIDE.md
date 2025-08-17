# Base Sepolia Test USDC Guide

## Obtaining Test USDC for autoUSD Testing

### Circle Testnet Faucet

**URL**: https://faucet.circle.com/

**Capabilities:**
- ✅ Base Sepolia supported
- ✅ 10 USDC per hour, per address
- ✅ Free testnet tokens

### Step-by-Step Process

#### 1. Access Circle Faucet
- Navigate to https://faucet.circle.com/
- Select "Base Sepolia" from network dropdown
- Ensure USDC is selected as currency

#### 2. Get Wallet Address
```typescript
// From Circle Developer Controlled Wallets
const wallets = await sdk.getWallets({
  blockchain: 'BASE-SEPOLIA'
});

const walletAddress = wallets.data.wallets[0].address;
console.log('Wallet Address:', walletAddress);
```

#### 3. Request Test USDC
- Paste wallet address into faucet
- Click "Request Tokens"
- Wait for confirmation (usually 1-2 minutes)

#### 4. Verify Receipt
```bash
# Check USDC balance on Base Sepolia
cast call 0x036CbD53842c5426634e7929541eC2318f3dCF7e \
  "balanceOf(address)(uint256)" \
  YOUR_WALLET_ADDRESS \
  --rpc-url https://sepolia.base.org

# Format result (divide by 1e6 for human-readable USDC amount)
```

### Testing Workflow

#### Phase 1: Basic Wallet Setup
```bash
# Run wallet creation test
cd frontend
npx tsx scripts/test-base-sepolia-gasless.ts
```

#### Phase 2: Fund Wallets
1. **Get Test USDC**: Use Circle faucet for each test wallet
2. **Get Test ETH**: Use Base Sepolia faucet for gas (if needed)
3. **Verify Balances**: Confirm both USDC and ETH received

#### Phase 3: Test Transactions
```typescript
// Test sequence after Mother Vault deployment
1. Gasless USDC approval to Mother Vault
2. Gasless deposit transaction ($10 test)
3. Verify share minting
4. Test withdrawal flow
5. Confirm balance updates
```

### Test Amounts Strategy

**Small Tests First:**
- Start with $1-5 USDC deposits
- Verify all mechanics work
- Scale up to $10-20 for larger tests
- Keep under $100 cap for individual testing

**Multiple Wallets:**
- Create 3-5 test wallets
- Fund each with 10 USDC from faucet
- Test different user scenarios
- Validate concurrent user behavior

### Troubleshooting

#### Common Issues

**1. Faucet Rate Limiting**
- Wait 1 hour between requests for same address
- Use multiple wallet addresses for more tokens
- Each address can get 10 USDC per hour

**2. Transaction Failures**
```typescript
// Check transaction status
const txStatus = await sdk.getTransaction({
  transactionId: 'your-tx-id'
});

console.log('Status:', txStatus.data.status);
console.log('Error:', txStatus.data.errorReason);
```

**3. Balance Updates**
- Allow 1-2 minutes for balance updates
- Check both on-chain and Circle wallet balance
- Verify block confirmations

#### Verification Commands

```bash
# Check Base Sepolia network status
curl https://sepolia.base.org \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Verify USDC contract
cast call 0x036CbD53842c5426634e7929541eC2318f3dCF7e \
  "name()(string)" \
  --rpc-url https://sepolia.base.org
# Should return: "USD Coin"

# Check Mother Vault deployment (after deployment)
cast call $MOTHER_VAULT_ADDRESS \
  "asset()(address)" \
  --rpc-url https://sepolia.base.org
# Should return: 0x036CbD53842c5426634e7929541eC2318f3dCF7e
```

### Success Criteria

**Phase 2 USDC Testing Complete When:**
- ✅ Multiple test wallets funded with USDC
- ✅ Gasless approval transactions working
- ✅ Gasless deposit transactions working  
- ✅ Balance updates reflected in real-time
- ✅ All user flows tested end-to-end
- ✅ Error handling validated

### Resources

- **Circle Faucet**: https://faucet.circle.com/
- **Base Sepolia Explorer**: https://sepolia.basescan.org/
- **Base Sepolia RPC**: https://sepolia.base.org
- **USDC Contract**: 0x036CbD53842c5426634e7929541eC2318f3dCF7e

### Next Steps After USDC Testing

1. **Complete Phase 2**: All Base Sepolia flows working
2. **Begin Phase 3**: Deploy to Katana testnet
3. **Cross-Chain Testing**: Real CCTP and Hyperlane messages
4. **End-to-End Validation**: Full autoUSD user journey