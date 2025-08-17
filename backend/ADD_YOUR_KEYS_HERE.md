# ⚠️ Action Required: Add Your Circle API Keys

The backend server is running but needs your Circle API keys to function.

## Quick Fix:

Edit the file: `/Users/peachy/Desktop/cursor/autoUSD/backend/.env`

Replace these placeholder values with your actual Circle credentials:

```env
# REPLACE THESE PLACEHOLDERS:
CIRCLE_API_KEY=TEST_API_KEY:placeholder:placeholder
CIRCLE_ENTITY_SECRET=placeholder_entity_secret
CIRCLE_WALLET_SET_ID=00000000-0000-0000-0000-000000000000
CIRCLE_PAYMASTER_API_KEY=TEST_API_KEY:placeholder:placeholder

# WITH YOUR ACTUAL VALUES FROM console.circle.com:
CIRCLE_API_KEY=TEST_API_KEY:your_actual_key:your_actual_secret
CIRCLE_ENTITY_SECRET=your_64_character_hex_string
CIRCLE_WALLET_SET_ID=your-uuid-xxxx-xxxx-xxxx-xxxxxxxxxxxx
CIRCLE_PAYMASTER_API_KEY=TEST_API_KEY:your_paymaster_key:secret
```

## Where to Find These in Circle Console:

1. **API Key**: Developers → API Keys → Copy full key
2. **Entity Secret**: Wallets → Developer Controlled → Entity Configuration
3. **Wallet Set ID**: Wallets → Wallet Sets → Copy UUID
4. **Paymaster Key**: Gas Station → Paymaster → Copy API key

## After Adding Keys:

The server will automatically restart (nodemon is watching).

Then test with:
```bash
curl http://localhost:3002/health
```

Should show `"circle":"configured"` instead of `"circle":"not configured"`