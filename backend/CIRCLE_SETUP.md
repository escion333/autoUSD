# Circle Developer Controlled Wallets Setup Guide

## Overview
This guide will help you set up Circle Developer Controlled Wallets for the autoUSD protocol, enabling gasless transactions and email-based wallet management.

## Prerequisites
- Node.js 18+ installed
- Circle Developer Account (sandbox)
- Base Sepolia testnet access

## Step 1: Create Circle Developer Account

1. Go to [Circle Console](https://console.circle.com)
2. Sign up for a developer account
3. Select "Sandbox" environment for testing

## Step 2: Generate API Keys

1. Navigate to **Developers** → **API Keys**
2. Click **Create API Key**
3. Name it "autoUSD Backend"
4. Copy the API key (format: `TEST_API_KEY:xxxxx:yyyyy`)
5. Store securely - you won't be able to see it again!

## Step 3: Create Entity Secret

1. Navigate to **Wallets** → **Developer Controlled**
2. Click **Entity Configuration**
3. Generate a new Entity Secret
4. Download and store the recovery file securely
5. Copy the entity secret for .env configuration

## Step 4: Create Wallet Set

1. Navigate to **Wallets** → **Wallet Sets**
2. Click **Create Wallet Set**
3. Configuration:
   - Name: "autoUSD Users"
   - Type: "End User Wallets"
   - Blockchain: "Base Sepolia"
4. Copy the Wallet Set ID (UUID format)

## Step 5: Configure Paymaster

1. Navigate to **Gas Station** → **Paymaster**
2. Click **Create Policy**
3. Configuration:
   - Name: "autoUSD Gas Sponsorship"
   - Network: "Base Sepolia"
   - Entry Point: `0x0000000071727De22E5E9d8BAf0edAc6f37da032`
   - Daily Limit: 100 USDC equivalent
   - Per-Transaction Limit: 10 USDC equivalent
4. Copy the Paymaster API Key

## Step 6: Configure Environment Variables

Create `.env` file in the backend directory:

```bash
# Circle Developer Controlled Wallets
CIRCLE_API_KEY=TEST_API_KEY:your_actual_api_key_here
CIRCLE_PAYMASTER_API_KEY=TEST_API_KEY:your_paymaster_key_here
CIRCLE_ENTITY_SECRET=your_entity_secret_here
CIRCLE_WALLET_SET_ID=your_wallet_set_id_here

# Network Configuration
NEXT_PUBLIC_CHAIN_ID=84532
NEXT_PUBLIC_BASE_RPC_URL=https://sepolia.base.org
NEXT_PUBLIC_PAYMASTER_URL=https://api.circle.com/v1/w3s/paymaster
NEXT_PUBLIC_ENTRY_POINT_ADDRESS=0x0000000071727De22E5E9d8BAf0edAc6f37da032

# Mother Vault Address (after deployment)
MOTHER_VAULT_ADDRESS=0x... # Add after deploying contracts
```

## Step 7: Install Dependencies

```bash
cd backend
npm install
```

## Step 8: Test Circle Integration

```bash
# Run the test suite
npm run test:circle
```

Expected output:
- ✅ Configuration validated
- ✅ Wallet creation successful
- ✅ Session management working
- ✅ Gas estimation functional
- ✅ Sponsorship eligibility confirmed

## Step 9: Start Backend Server

```bash
# Development mode
npm run dev

# Production build
npm run build
npm start
```

Server will start on `http://localhost:3001`

## Step 10: Test API Endpoints

### Create Wallet
```bash
curl -X POST http://localhost:3001/api/circle/wallets/create \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "userId": "user-123"
  }'
```

### Check Balance
```bash
curl http://localhost:3001/api/circle/wallets/balance?email=user@example.com
```

### Execute Gasless Deposit
```bash
curl -X POST http://localhost:3001/api/circle/wallets/deposit \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "amount": "10000000"
  }'
```

## Troubleshooting

### "Configuration not valid" error
- Ensure all 4 Circle environment variables are set
- Check API key format (should start with TEST_API_KEY in sandbox)

### "Failed to create wallet" error
- Verify entity secret is correct
- Check wallet set ID is valid UUID
- Ensure you're using sandbox environment

### "Not eligible for gas sponsorship" error
- Check daily transaction limits
- Verify Paymaster policy is active
- Ensure wallet has not exceeded limits

## Security Best Practices

1. **Never commit .env files** to version control
2. **Use environment-specific keys** (sandbox vs production)
3. **Implement rate limiting** on API endpoints
4. **Store entity secret securely** (use KMS in production)
5. **Monitor gas usage** to prevent abuse
6. **Implement user authentication** before wallet creation

## Next Steps

1. **Deploy Mother Vault** to Base Sepolia
2. **Update MOTHER_VAULT_ADDRESS** in .env
3. **Integrate with frontend** dashboard
4. **Set up Fern** for fiat on-ramp
5. **Configure Hyperlane** for cross-chain messaging

## Support

- [Circle Documentation](https://developers.circle.com/w3s/docs)
- [Circle API Reference](https://developers.circle.com/w3s/reference)
- [Circle Discord](https://discord.gg/circle)
- [autoUSD Documentation](../docs/)