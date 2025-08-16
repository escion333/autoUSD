# Circle Developer Controlled Wallets Setup Guide

## Overview

autoUSD uses **Circle Developer Controlled Wallets** to provide a seamless user experience:
- ✅ No seed phrases or private keys for users
- ✅ Custodial wallets managed by the platform
- ✅ Gasless transactions
- ✅ Multi-chain support
- ✅ Enterprise-grade security

## Architecture Comparison

### User Controlled Wallets (Not Used)
- Users manage their own keys
- Complex onboarding with PIN/security questions
- Users pay gas fees
- More suitable for DeFi power users

### Developer Controlled Wallets (Our Choice) ✅
- Platform manages wallets on behalf of users
- Simple email-only onboarding
- Platform can sponsor gas fees
- Perfect for abstracting blockchain complexity
- Ideal for yield aggregation platforms

## Setup Instructions

### Step 1: Get Your Circle API Key

1. Go to [Circle Console](https://console.circle.com)
2. Create a new project
3. Navigate to "API Keys"
4. Create a new API key with these permissions:
   - Developer Controlled Wallets: Read & Write
   - Smart Contract Platform: Read (optional)

### Step 2: Generate Entity Secret

The Entity Secret is a 32-byte private key that secures your wallets.

Run the setup script:
```bash
npx tsx scripts/setup-circle.ts
```

Choose option 3 (Generate and Register) and follow the prompts.

**⚠️ IMPORTANT:** 
- Save your Entity Secret securely (like a private key)
- Save the recovery file that gets generated
- Never share or commit these to version control

### Step 3: Update Environment Variables

Add to your `.env.local`:
```env
# Your API key from Circle Console
CIRCLE_API_KEY=your_api_key_here

# Entity Secret from setup script
CIRCLE_ENTITY_SECRET=your_entity_secret_here

# Optional: USDC token ID for Base Sepolia
NEXT_PUBLIC_USDC_TOKEN_ID=your_usdc_token_id
```

### Step 4: Test the Integration

1. Start the development server:
```bash
npm run dev
```

2. Go to http://localhost:3000
3. Click "Connect Wallet"
4. Enter your email
5. A wallet will be automatically created

## How It Works

### 1. User Authentication
```typescript
// User enters email
const user = await authService.login(email);
// Wallet is automatically created/retrieved
```

### 2. Wallet Creation
```typescript
// Backend creates a custodial wallet
const wallet = await walletService.getOrCreateWallet(email);
// Returns wallet address for the user
```

### 3. Deposits (Coming Soon)
```typescript
// User deposits via Fern onramp
// Funds go directly to their Circle wallet
// Platform manages the deposit to Mother Vault
```

### 4. Withdrawals (Coming Soon)
```typescript
// Platform withdraws from Mother Vault
// Sends funds to user's external address
// All handled by Circle infrastructure
```

## API Endpoints

### `/api/wallet/create`
Creates or retrieves a wallet for a user email.

**Request:**
```json
{
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "wallet": {
    "address": "0x...",
    "walletId": "...",
    "blockchain": "BASE-SEPOLIA"
  }
}
```

### `/api/wallet/balance`
Gets wallet balance.

**Request:**
```
GET /api/wallet/balance?walletId=xxx
```

**Response:**
```json
{
  "success": true,
  "balances": [
    {
      "token": "USDC",
      "amount": "100.00",
      "decimals": 6
    }
  ]
}
```

## Security Best Practices

1. **Entity Secret Management**
   - Store in secure key management system
   - Use environment variables
   - Rotate periodically
   - Keep recovery file safe

2. **API Key Security**
   - Never expose in client-side code
   - Use server-side routes only
   - Implement rate limiting
   - Monitor usage

3. **Wallet Management**
   - Map wallets to user accounts securely
   - Implement proper access controls
   - Audit all transactions
   - Regular backups

## Troubleshooting

### "Invalid credentials" Error
- Check API key format
- Ensure Entity Secret is registered
- Verify API permissions

### "Wallet creation failed"
- Check wallet set exists
- Verify blockchain configuration
- Check Circle service status

### "Entity Secret not found"
- Run setup script to generate
- Add to `.env.local`
- Restart server

## Production Considerations

1. **Database Integration**
   - Store wallet mappings in database
   - Cache wallet information
   - Track transaction history

2. **Error Handling**
   - Implement retry logic
   - Graceful fallbacks
   - User-friendly error messages

3. **Monitoring**
   - Track wallet creation
   - Monitor transaction success rates
   - Alert on failures

4. **Compliance**
   - KYC/AML integration
   - Transaction monitoring
   - Regulatory reporting

## Next Steps

1. ✅ Complete Circle setup
2. ⏳ Integrate Fern onramp
3. ⏳ Connect to Mother Vault contract
4. ⏳ Implement deposit/withdraw flows
5. ⏳ Add transaction history
6. ⏳ Production deployment

## Support

- [Circle Documentation](https://developers.circle.com/w3s/docs)
- [Developer Controlled Wallets Guide](https://developers.circle.com/w3s/developer-controlled-create-your-first-wallet)
- [Circle Support](https://developers.circle.com/support)