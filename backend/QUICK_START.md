# 🚀 autoUSD Backend Quick Start

## Current Status
✅ **Backend server is running on port 3002!**

The server is up but needs Circle API credentials to function fully.

## Next Steps to Complete Setup

### 1. Get Your Circle Sandbox Credentials

1. Go to [console.circle.com](https://console.circle.com)
2. Sign in or create account
3. Make sure you're in **Sandbox** mode (top-right toggle)
4. Get these 4 items:

#### API Key
- Navigate to **Developers** → **API Keys**
- Create new API key
- Copy the full key (starts with `TEST_API_KEY:`)

#### Entity Secret
- Navigate to **Wallets** → **Developer Controlled**
- Click **Entity Configuration**
- Generate entity secret
- Copy the secret (64 character hex string)

#### Wallet Set ID
- Navigate to **Wallets** → **Wallet Sets**
- Create new wallet set for "autoUSD Users"
- Copy the UUID

#### Paymaster API Key (Optional)
- Navigate to **Gas Station** → **Paymaster**
- Create policy for Base Sepolia
- Copy the API key

### 2. Update Your .env File

Edit `/Users/peachy/Desktop/cursor/autoUSD/backend/.env`:

```env
# Replace these placeholder values with your actual Circle credentials:
CIRCLE_API_KEY=TEST_API_KEY:your_actual_key:your_actual_secret
CIRCLE_ENTITY_SECRET=your_64_char_entity_secret_here
CIRCLE_WALLET_SET_ID=your-uuid-here
CIRCLE_PAYMASTER_API_KEY=TEST_API_KEY:your_paymaster_key:secret
```

### 3. Restart the Server

The server will auto-restart when you save the .env file (nodemon is watching).

### 4. Verify Configuration

```bash
# Check if Circle is configured
curl http://localhost:3002/health
```

Should show: `"circle":"configured"` instead of `"circle":"not configured"`

### 5. Test Wallet Creation

```bash
# Create a test wallet
curl -X POST http://localhost:3002/api/circle/wallets/create \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "userId": "test-user-123"
  }'
```

## Available API Endpoints

- `GET  /health` - Health check
- `POST /api/circle/wallets/create` - Create wallet for user
- `GET  /api/circle/wallets/balance?email=user@example.com` - Check balance
- `POST /api/circle/wallets/deposit` - Execute gasless deposit
- `GET  /api/circle/wallets/transactions?email=user@example.com` - Transaction history
- `GET  /api/circle/wallets/stats?email=user@example.com` - User statistics

## Testing the Full Flow

Once you have Circle credentials:

1. **Create Wallet**:
```bash
curl -X POST http://localhost:3002/api/circle/wallets/create \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "userId": "user-123"}'
```

2. **Check Balance**:
```bash
curl http://localhost:3002/api/circle/wallets/balance?email=user@example.com
```

3. **Deposit (after deploying Mother Vault)**:
```bash
curl -X POST http://localhost:3002/api/circle/wallets/deposit \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "amount": "10000000"}'
```

## Troubleshooting

### "Circle configuration not properly set"
- Ensure all 4 Circle environment variables are in .env
- Check that API keys start with `TEST_API_KEY:` for sandbox

### "Failed to create wallet"
- Verify entity secret is correct (64 hex characters)
- Check wallet set ID is valid UUID format
- Ensure you're using sandbox environment in Circle console

### Port Already in Use
- Change PORT in .env to another port (e.g., 3003)
- Or kill the process: `lsof -i :3002` then `kill <PID>`

## What's Working Now

✅ Backend server running  
✅ All endpoints configured  
✅ In-memory database ready  
✅ Security middleware active  
✅ Rate limiting enabled  
⏳ Waiting for Circle credentials  

## Support

- Backend server logs: Check terminal where `npm run dev` is running
- Circle docs: https://developers.circle.com/w3s/docs
- API testing: Use Postman or curl commands above