# Circle API Setup Guide

## Current Status ✅

### ✅ Completed:
1. **Entity Secret Generated**: `ff0c9a1386d75da8e9ec4d160d2a797760e77613b4a7e61da92a6674f8f533d7`
   - Successfully generated and saved to `.env.local`
   - Backup saved to `.entity-secret.backup`
   - Ready for registration with Circle API

2. **Code Implementation Complete**:
   - Developer Controlled Wallets service ready
   - Test scripts prepared
   - Authentication flow implemented

### ⏳ Pending - Requires Valid Circle API Key:

## Next Steps to Complete Setup

### Step 1: Get a Valid Circle API Key

The current API key in `.env.local` is a test/placeholder key (`TEST_API_KEY:...`) that doesn't work with Circle's API.

**To get a real API key:**

1. **Sign up for Circle Developer Account**:
   - Go to: https://console.circle.com/signup
   - Create an account if you don't have one
   - Complete verification process

2. **Access Developer Console**:
   - Log in to: https://console.circle.com
   - Navigate to "Developers" → "API Keys"

3. **Create a New API Key**:
   - Click "Create an API Key"
   - Name your key (e.g., "autoUSD Development")
   - Select Environment: **Testnet** (for development)
   - Select permissions:
     - ✅ **Developer Controlled Wallets** (required)
     - ✅ **Wallets** (required for wallet operations)
     - ✅ **Wallet Sets** (required for organization)
     - ✅ **Transactions** (required for transfers)
     - ✅ **Balances** (required for queries)
   - Click "Create API Key"
   - **IMPORTANT**: Copy the full API key immediately (shown only once!)
   - Format: `TEST_API_KEY:xxxxx:yyyyy` (testnet) or `LIVE_API_KEY:xxxxx:yyyyy` (mainnet)

4. **Update `.env.local`**:
   ```bash
   CIRCLE_API_KEY=YOUR_ACTUAL_API_KEY_HERE
   ```

### Step 2: Register Entity Secret

Once you have a valid API key, register the Entity Secret with Circle:

**Option A: Automated Registration (Recommended)**
```bash
npx tsx scripts/register-entity-secret.ts
```

**Option B: Manual Registration via Circle Console**
1. Go to: https://console.circle.com/wallets/dev/configurator
2. Enter the Entity Secret: `ff0c9a1386d75da8e9ec4d160d2a797760e77613b4a7e61da92a6674f8f533d7`
3. Click "Register"

**Note**: Registration is a one-time process. Once registered, the Entity Secret is permanently associated with your API key.

### Step 3: Verify Setup

Run the test script to verify everything works:

```bash
npx tsx scripts/test-circle-wallet.ts
```

Expected output:
```
✅ Client initialized successfully
✅ Wallet created successfully!
✅ Balance retrieved
🎉 All tests passed!
```

## Important Notes

### Security Considerations:
- **Entity Secret**: Keep it secure like a private key
- **API Key**: Never commit to version control
- **Recovery File**: Save the recovery file when registering Entity Secret

### Environment Variables Required:
```env
# Required - Get from Circle Console
CIRCLE_API_KEY=<your-actual-api-key>

# Already set - Generated Entity Secret
CIRCLE_ENTITY_SECRET=ff0c9a1386d75da8e9ec4d160d2a797760e77613b4a7e61da92a6674f8f533d7

# Optional - Circle App ID (for User Controlled Wallets, not needed for Developer Controlled)
NEXT_PUBLIC_CIRCLE_APP_ID=99afd48aa8b6b0d017afe6e33a670647

# USDC Token ID for Base Sepolia (already set if needed)
NEXT_PUBLIC_USDC_TOKEN_ID=<token-id-from-circle>
```

### Testing Checklist:
- [ ] Circle account created
- [ ] API key obtained from Circle Console
- [ ] API key updated in `.env.local`
- [ ] Entity Secret registered with Circle
- [ ] Test wallet created successfully
- [ ] Balance query working
- [ ] Transaction test completed

## Troubleshooting

### Common Issues:

1. **401 Unauthorized Error**:
   - Cause: Invalid or test API key
   - Solution: Get real API key from Circle Console

2. **Entity Secret Not Registered**:
   - Cause: Entity Secret not registered with Circle
   - Solution: Run registration script after getting valid API key

3. **Wallet Set Creation Fails**:
   - Cause: Permissions issue or duplicate name
   - Solution: Check API key permissions, use unique wallet set name

4. **Network Issues**:
   - Cause: Firewall or proxy blocking Circle API
   - Solution: Check network settings, use VPN if needed

## Support Resources

- Circle Documentation: https://developers.circle.com/w3s/docs
- API Reference: https://developers.circle.com/w3s/reference
- Support: https://developers.circle.com/support

## Ready to Deploy? 

Once all tests pass:
1. Frontend can create wallets for users via email
2. Gasless transactions are automatically enabled
3. Fern onramp can be integrated for fiat purchases
4. Smart contract integration can proceed

---

**Current Blocker**: Need valid Circle API key to proceed with wallet creation and testing.