#!/usr/bin/env node

/**
 * Test script for Fern webhook integration
 * 
 * Usage: npx tsx scripts/test-fern-webhook.ts [event-type]
 * 
 * Event types:
 * - customer.verified
 * - transaction.completed
 * - transaction.failed
 */

import { FernWebhookEvent, TransactionCompletedEvent } from '../src/lib/fern/types';

const WEBHOOK_URL = 'http://localhost:3000/api/fern/webhook';

async function sendWebhookEvent(event: FernWebhookEvent) {
  console.log('📤 Sending webhook event:', {
    eventId: event.eventId,
    eventType: event.eventType,
  });

  try {
    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-fern-signature': 'sha256=test-signature', // Mock signature for dev
      },
      body: JSON.stringify(event),
    });

    const result = await response.json();
    
    if (response.ok) {
      console.log('✅ Webhook processed successfully:', result);
    } else {
      console.error('❌ Webhook processing failed:', result);
    }
    
    return result;
  } catch (error) {
    console.error('❌ Failed to send webhook:', error);
    throw error;
  }
}

async function testCustomerVerified() {
  const event: FernWebhookEvent = {
    eventId: `evt_${Date.now()}_customer_verified`,
    eventType: 'customer.verified',
    timestamp: new Date().toISOString(),
    data: {
      customerId: 'cust_test_123',
      email: 'test@example.com',
      verificationLevel: 'full',
      limits: {
        daily: 5000,
        monthly: 50000,
      },
      verifiedAt: new Date().toISOString(),
    },
  };

  return sendWebhookEvent(event);
}

async function testTransactionCompleted(amount: number = 100) {
  const event: FernWebhookEvent = {
    eventId: `evt_${Date.now()}_transaction_completed`,
    eventType: 'transaction.completed',
    timestamp: new Date().toISOString(),
    data: {
      transactionId: `txn_test_${Date.now()}`,
      customerId: 'cust_test_123',
      amount: amount,
      currency: 'USDC',
      destinationAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7', // Test address
      transactionHash: `0x${Math.random().toString(16).substring(2, 66)}`,
      network: 'base',
      completedAt: new Date().toISOString(),
    } as TransactionCompletedEvent,
  };

  return sendWebhookEvent(event);
}

async function testTransactionFailed() {
  const event: FernWebhookEvent = {
    eventId: `evt_${Date.now()}_transaction_failed`,
    eventType: 'transaction.failed',
    timestamp: new Date().toISOString(),
    data: {
      transactionId: `txn_test_${Date.now()}`,
      customerId: 'cust_test_123',
      amount: 100,
      currency: 'USDC',
      reason: 'Insufficient funds in source account',
      failedAt: new Date().toISOString(),
    },
  };

  return sendWebhookEvent(event);
}

async function testAutoDepositFlow() {
  console.log('🧪 Testing complete auto-deposit flow...\n');
  
  // Step 1: Customer verification
  console.log('Step 1: Customer Verification');
  await testCustomerVerified();
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  // Step 2: Small successful transaction
  console.log('\nStep 2: Small Transaction ($25)');
  await testTransactionCompleted(25);
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  // Step 3: Medium transaction
  console.log('\nStep 3: Medium Transaction ($50)');
  await testTransactionCompleted(50);
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  // Step 4: Transaction that exceeds cap
  console.log('\nStep 4: Large Transaction ($30) - Should hit $100 cap');
  await testTransactionCompleted(30);
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  // Step 5: Failed transaction
  console.log('\nStep 5: Failed Transaction');
  await testTransactionFailed();
  
  console.log('\n✅ Auto-deposit flow test complete!');
}

async function checkWebhookStatus() {
  console.log('📊 Checking webhook status...\n');
  
  try {
    const response = await fetch('http://localhost:3000/api/fern/webhook-status');
    const status = await response.json();
    
    console.log('Webhook Status:', JSON.stringify(status, null, 2));
    
    if (status.retryQueue?.pending > 0) {
      console.log('\n🔄 Triggering retry for pending deposits...');
      
      const retryResponse = await fetch('http://localhost:3000/api/fern/webhook-status?action=retry-all', {
        method: 'POST',
      });
      
      const retryResult = await retryResponse.json();
      console.log('Retry Result:', retryResult);
    }
  } catch (error) {
    console.error('Failed to check webhook status:', error);
  }
}

// Main execution
async function main() {
  const eventType = process.argv[2] || 'flow';
  
  console.log(`🚀 Fern Webhook Test - Event Type: ${eventType}\n`);
  
  try {
    switch (eventType) {
      case 'customer.verified':
        await testCustomerVerified();
        break;
      
      case 'transaction.completed':
        const amount = process.argv[3] ? parseFloat(process.argv[3]) : 100;
        await testTransactionCompleted(amount);
        break;
      
      case 'transaction.failed':
        await testTransactionFailed();
        break;
      
      case 'flow':
        await testAutoDepositFlow();
        break;
      
      case 'status':
        await checkWebhookStatus();
        break;
      
      default:
        console.error('❌ Unknown event type:', eventType);
        console.log('\nAvailable event types:');
        console.log('  - customer.verified');
        console.log('  - transaction.completed [amount]');
        console.log('  - transaction.failed');
        console.log('  - flow (complete auto-deposit flow)');
        console.log('  - status (check webhook status)');
        process.exit(1);
    }
    
    console.log('\n✅ Test completed successfully!');
  } catch (error) {
    console.error('\n❌ Test failed:', error);
    process.exit(1);
  }
}

// Run the test
main().catch(console.error);