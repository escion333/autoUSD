# Webhook Flow Testing Guide

This guide covers how to test the Fern onramp webhook integration and auto-deposit functionality.

## Overview

The webhook flow handles the following events:
- `customer.created` - New customer registration
- `customer.verified` - KYC verification completed
- `customer.rejected` - KYC verification failed
- `transaction.pending` - USDC purchase initiated
- `transaction.processing` - USDC purchase in progress
- `transaction.completed` - USDC purchase completed (triggers auto-deposit)
- `transaction.failed` - USDC purchase failed

## Testing Methods

### 1. Automated Test Suite

Run the complete test suite:

```bash
cd frontend
node scripts/test-webhook-flow.js
```

Choose option 1 to run all tests automatically.

### 2. Interactive Testing

For manual testing of specific webhook events:

```bash
cd frontend
node scripts/test-webhook-flow.js
```

Choose option 2 for interactive mode, then enter event types to test.

### 3. API Testing

#### Test webhook endpoint directly:

```bash
curl -X POST http://localhost:3000/api/test-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "transaction.completed",
    "data": {
      "amount": 100,
      "destinationAddress": "0x742d35cc6644c0532925a3b8d0b74e7c297b0eae"
    }
  }'
```

#### Check health status:

```bash
curl http://localhost:3000/api/health
```

#### Test auto-deposit retry:

```bash
curl -X POST http://localhost:3000/api/fern/retry-auto-deposit \
  -H "Content-Type: application/json" \
  -d '{
    "fernTransactionId": "test_tx_123",
    "userEmail": "test@example.com"
  }'
```

#### Test wallet address mapping:

```bash
# Seed test wallet mappings
curl -X PUT http://localhost:3000/api/wallet/mapping

# Look up wallet by email
curl "http://localhost:3000/api/wallet/mapping?email=test@example.com"

# Look up wallet by address
curl "http://localhost:3000/api/wallet/mapping?address=0x742d35cc6644c0532925a3b8d0b74e7c297b0eae"

# Test balance lookup by address (the critical path)
curl -X POST http://localhost:3000/api/wallet/balance \
  -H "Content-Type: application/json" \
  -d '{
    "address": "0x742d35cc6644c0532925a3b8d0b74e7c297b0eae",
    "currency": "USDC"
  }'
```

## Key Test Scenarios

### 1. Successful Auto-Deposit Flow

Tests the complete flow from USDC purchase to vault deposit:

1. `transaction.completed` webhook received
2. **Wallet address to ID mapping lookup**
3. **Balance verification using Circle API**
4. User lookup by wallet address
5. Deposit cap validation
6. Vault deposit execution
7. Success notification

### 2. Failed Auto-Deposit with Retry

Tests error handling and retry mechanisms:

1. `transaction.completed` with simulated failure
2. Error classification (retryable vs non-retryable)
3. Failed deposit storage
4. Error notification with next steps
5. Manual retry attempt

### 3. Deposit Cap Enforcement

Tests the $100 beta deposit limit:

1. Large purchase amount (>$100)
2. Current position check
3. Deposit amount capping
4. Partial deposit execution

### 4. Wallet Address Mapping

Tests the critical address-to-ID mapping functionality:

```bash
cd frontend
node scripts/test-wallet-mapping.js
```

This tests:
1. Seeding test wallet mappings
2. Email to wallet lookup
3. Address to wallet lookup
4. Balance API with address input
5. Webhook auto-deposit using address mapping
6. Listing all stored mappings

The mapping system provides:
- **Bidirectional lookup**: email ↔ address ↔ wallet ID
- **Circle API integration**: Direct wallet queries
- **Caching**: In-memory cache with database fallback
- **Development support**: Test data seeding and debugging tools

## Environment Setup

### Required Environment Variables

```bash
# Webhook signature verification (development only)
FERN_WEBHOOK_SECRET=your_webhook_secret_here

# For production testing
CIRCLE_API_KEY=your_circle_api_key
CIRCLE_ENTITY_SECRET=your_entity_secret
```

### Development Mode Features

- Webhook signature verification is skipped
- Mock data is used for user lookups
- Simulated vault operations
- Auto-completion of test transactions

## Monitoring & Debugging

### Console Logs

The webhook handler provides detailed logging:

```
🔔 Received Fern webhook: { eventId, eventType, timestamp }
🚀 Triggering auto-deposit for: transactionId
⚠️ Skipping balance check - address to wallet ID mapping not implemented
✅ Auto-deposit completed successfully
```

### Error Classifications

Errors are automatically classified for better handling:

- `user_not_found` - Non-retryable, user account issue
- `deposit_cap_exceeded` - Non-retryable, beta limit reached
- `network_error` - Retryable, temporary network issue
- `contract_error` - Potentially retryable, blockchain issue
- `vault_paused` - Retryable, system maintenance

### Failed Deposit Tracking

Failed auto-deposits are stored with:
- Error type and classification
- Retry eligibility
- User notification status
- Timestamp and attempt count

## Production Considerations

### Database Integration

The following database schema is needed for production:

```sql
-- User wallet mappings table
CREATE TABLE user_wallets (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  wallet_id VARCHAR(255) NOT NULL,
  wallet_address VARCHAR(42) NOT NULL UNIQUE,
  blockchain VARCHAR(50) DEFAULT 'BASE-SEPOLIA',
  wallet_set_id VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Index for fast address lookups
CREATE INDEX idx_user_wallets_address ON user_wallets(wallet_address);
CREATE INDEX idx_user_wallets_email ON user_wallets(email);
```

Functions requiring database implementation:
- ✅ `getUserEmailFromWallet()` - **IMPLEMENTED** with Circle API + cache
- ✅ `findWalletByAddress()` - **IMPLEMENTED** with Circle API + cache
- ✅ `storeWalletMapping()` - **IMPLEMENTED** with in-memory cache (needs DB)
- `getUserVaultPosition()` - Current vault balance check
- `storeFailedAutoDeposit()` - Failed attempt storage
- `executeVaultDeposit()` - Smart contract interaction

### Security

- Webhook signature verification (already implemented)
- Rate limiting on retry endpoints
- Authentication for manual retry requests
- Audit logging for all deposit attempts

### Monitoring

- Webhook delivery success rates
- Auto-deposit success rates by error type
- Failed deposit accumulation
- User notification delivery status

## Troubleshooting

### Common Issues

1. **Webhook not receiving events**
   - Check FERN_WEBHOOK_SECRET environment variable
   - Verify webhook URL configuration in Fern dashboard
   - Check firewall/network connectivity

2. **Auto-deposit always failing**
   - Check wallet address to ID mapping implementation
   - Verify Circle API credentials
   - Check vault contract deployment and permissions

3. **Signature verification fails**
   - Ensure webhook secret matches Fern configuration
   - Check request body encoding (UTF-8)
   - Verify HMAC-SHA256 implementation

### Debug Mode

Set `NODE_ENV=development` to enable:
- Detailed error logging
- Mock implementations
- Signature verification bypass
- Extended timeout values

## Next Steps

1. Implement proper wallet address to ID mapping
2. Connect to production Circle API
3. Deploy smart contract integration
4. Set up monitoring and alerting
5. Add comprehensive error recovery