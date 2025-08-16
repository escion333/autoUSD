# Fern Integration Plan for autoUSD

## Overview
Fern provides a seamless fiat-to-crypto onramp API that will enable autoUSD users to purchase USDC directly with fiat currency and automatically deposit it into the Mother Vault.

## Fern API Core Concepts

### 1. Authentication
- **API Key-based**: Bearer token in Authorization header
- **Environment-specific keys**: Sandbox, Pre-production, Production
- **Secure key management**: Keys provided by Fern team after commercial agreement

### 2. Core API Flow
The Fern integration follows this sequence:
1. **Customer Creation** → 2. **KYC Verification** → 3. **Payment Account Setup** → 4. **Quote Generation** → 5. **Transaction Execution** → 6. **Webhook Notifications**

### 3. Key Components

#### Customers API
- **POST /customers**: Create customer with email
- **GET /customers/{customerId}**: Check verification status
- **PATCH /customers/{customerId}**: Update KYC data
- **Response includes**: customerId, customerStatus, kycLink

#### Quotes API
- Generate exchange rates and fees
- Quote must be created before transaction
- Becomes invalid after transaction creation
- Shows all fees upfront (0.5% Fern fee + gas/wire fees)

#### Transactions API
- Requires valid quote ID
- Confirms quote details
- Provides fund transfer instructions
- Triggers automatic USDC conversion

#### Webhooks
- Real-time transaction status updates
- Customer verification events
- Support for retries and verification
- Critical for auto-deposit flow

## Integration Requirements for autoUSD

### Phase 1: Basic Setup
1. **Environment Configuration**
   ```env
   FERN_API_KEY=your_api_key_here
   FERN_API_URL=https://api.fernhq.com
   FERN_WEBHOOK_SECRET=your_webhook_secret
   ```

2. **API Service Layer** (`/frontend/src/lib/fern/api.ts`)
   ```typescript
   class FernAPIService {
     // Customer management
     async createCustomer(email: string)
     async getCustomerStatus(customerId: string)
     
     // Quote generation
     async createQuote(params: QuoteParams)
     
     // Transaction execution
     async createTransaction(quoteId: string)
     async getTransactionStatus(transactionId: string)
   }
   ```

### Phase 2: Customer Onboarding Flow
1. **Customer Creation**
   - Use Circle wallet email for Fern customer
   - Store customerId with user profile
   - Generate KYC link for verification

2. **KYC Management**
   - Redirect to branded KYC form
   - Track verification status
   - Handle approved/rejected states
   - Store KYC tier for limits

### Phase 3: Purchase Flow Implementation
1. **Quote Generation**
   ```typescript
   interface QuoteParams {
     fromCurrency: 'USD' | 'EUR' | 'GBP';
     toCurrency: 'USDC';
     amount: number;
     network: 'BASE' | 'BASE-SEPOLIA';
     destinationAddress: string; // Circle wallet address
   }
   ```

2. **Transaction Execution**
   - Display quote with fees
   - Confirm with user
   - Execute transaction
   - Show payment instructions

3. **Payment Instructions UI**
   - Bank wire details
   - ACH information
   - Reference number
   - Expected timeline

### Phase 4: Webhook Integration
1. **Webhook Endpoint** (`/frontend/src/app/api/fern/webhook/route.ts`)
   ```typescript
   async function handleWebhook(event: FernWebhookEvent) {
     switch(event.type) {
       case 'customer.verified':
         // Update user KYC status
         break;
       case 'transaction.completed':
         // Trigger auto-deposit to Mother Vault
         break;
       case 'transaction.failed':
         // Handle failure, notify user
         break;
     }
   }
   ```

2. **Webhook Events to Handle**
   - `customer.created`
   - `customer.verified`
   - `customer.rejected`
   - `transaction.pending`
   - `transaction.completed`
   - `transaction.failed`

### Phase 5: Auto-Deposit Flow
1. **USDC Detection**
   ```typescript
   async function handleTransactionComplete(event: TransactionCompleteEvent) {
     // 1. Verify USDC received in Circle wallet
     const balance = await checkWalletBalance(event.destinationAddress);
     
     // 2. Check deposit limits ($100 cap)
     const depositAmount = Math.min(event.amount, 100);
     
     // 3. Auto-deposit to Mother Vault
     await depositToMotherVault(depositAmount);
     
     // 4. Notify user of successful deposit
     await notifyUser(event.customerId, depositAmount);
   }
   ```

2. **Error Handling**
   - Insufficient balance after fees
   - Deposit cap exceeded
   - Network issues
   - Contract interaction failures

## UI Components Update

### 1. Enhanced OnrampModal
```typescript
interface OnrampModalProps {
  onComplete: (transactionId: string) => void;
  maxAmount?: number; // $100 deposit cap
  userEmail: string;
  walletAddress: string;
}

// Features:
// - Amount input with fee calculator
// - Currency selector (USD, EUR, GBP)
// - KYC status indicator
// - Quote display with breakdown
// - Payment instructions
// - Transaction tracking
```

### 2. KYC Status Component
```typescript
interface KYCStatusProps {
  customerId: string;
  onVerified: () => void;
}

// Shows:
// - Verification status (pending/approved/rejected)
// - Link to complete KYC
// - Tier limits
// - Time to verify estimate
```

### 3. Transaction Tracker
```typescript
interface TransactionTrackerProps {
  transactionId: string;
  onComplete: () => void;
}

// Displays:
// - Current status
// - Expected timeline
// - Payment instructions
// - Auto-deposit progress
```

## Testing Strategy

### 1. Sandbox Testing
- Create test customers with various KYC states
- Generate test quotes with different amounts
- Simulate successful/failed transactions
- Test webhook delivery and retry logic

### 2. Integration Tests
```typescript
describe('Fern Integration', () => {
  test('Complete purchase flow', async () => {
    // 1. Create customer
    // 2. Complete KYC
    // 3. Generate quote
    // 4. Execute transaction
    // 5. Handle webhook
    // 6. Verify auto-deposit
  });
  
  test('Handle deposit limit', async () => {
    // Test $100 cap enforcement
  });
  
  test('Webhook verification', async () => {
    // Test signature verification
  });
});
```

### 3. Error Scenarios
- KYC rejection
- Transaction failure
- Network issues
- Webhook delivery failure
- Auto-deposit failure

## Security Considerations

1. **API Key Management**
   - Store in environment variables
   - Never expose in client code
   - Rotate regularly

2. **Webhook Verification**
   - Verify signatures on all webhooks
   - Validate payload structure
   - Check for replay attacks

3. **Rate Limiting**
   - Implement request throttling
   - Handle 429 responses gracefully
   - Queue operations when needed

4. **Data Privacy**
   - Minimal KYC data storage
   - Encrypt sensitive information
   - Comply with data regulations

## Implementation Timeline

### Week 1: Foundation
- [ ] Set up Fern API service layer
- [ ] Create webhook endpoints
- [ ] Update environment configuration
- [ ] Basic API integration tests

### Week 2: Customer & KYC
- [ ] Implement customer creation
- [ ] Build KYC status tracking
- [ ] Create KYC UI components
- [ ] Test verification flow

### Week 3: Purchase Flow
- [ ] Quote generation UI
- [ ] Transaction execution
- [ ] Payment instructions display
- [ ] Transaction tracking

### Week 4: Auto-Deposit
- [ ] Webhook handler implementation
- [ ] Auto-deposit logic
- [ ] Error handling
- [ ] End-to-end testing

## Success Metrics

1. **Conversion Rate**: % of users completing purchases
2. **KYC Approval Rate**: % passing verification
3. **Auto-Deposit Success**: % of purchases auto-deposited
4. **Time to Deposit**: Average time from payment to vault
5. **Error Rate**: % of failed transactions

## Next Steps

1. **Immediate Actions**
   - Request API keys from Fern team
   - Set up sandbox environment
   - Create initial API service layer

2. **Development Priorities**
   - Customer creation and KYC flow
   - Basic quote and transaction UI
   - Webhook endpoint setup
   - Auto-deposit logic

3. **Testing Requirements**
   - Full sandbox testing
   - Security audit of webhook handling
   - Load testing for high volume
   - User acceptance testing

## Notes

- Fern charges 0.5% fee on all transactions
- Additional gas and wire/ACH fees apply
- KYC is required for all customers
- Quotes expire after transaction creation
- Webhooks are critical for auto-deposit flow
- Support for 15+ fiat currencies
- Global coverage with licensed providers