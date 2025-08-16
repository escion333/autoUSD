#!/usr/bin/env node

/**
 * Webhook Flow Test Script
 * 
 * This script tests the end-to-end webhook flow by simulating Fern webhook events
 * and verifying the auto-deposit functionality.
 */

const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const BASE_URL = process.env.NEXTAUTH_URL || 'http://localhost:3000';

async function runTest(testName, eventType, customData = null) {
  console.log(`\n🧪 Running test: ${testName}`);
  console.log(`📡 Event type: ${eventType}`);
  
  try {
    const response = await fetch(`${BASE_URL}/api/test-webhook`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        eventType,
        data: customData,
      }),
    });
    
    const result = await response.json();
    
    if (result.success) {
      console.log('✅ Test completed successfully');
      console.log('📦 Test event:', result.testEvent.eventId);
      console.log('📥 Webhook response status:', result.webhookResponse.status);
      
      if (result.webhookResponse.body.handlerResult) {
        console.log('🔄 Handler result:', result.webhookResponse.body.handlerResult);
      }
      
      return result;
    } else {
      console.log('❌ Test failed:', result.error);
      return null;
    }
  } catch (error) {
    console.log('💥 Test error:', error.message);
    return null;
  }
}

async function runAllTests() {
  console.log('🚀 Starting webhook flow tests...\n');
  
  const tests = [
    {
      name: 'Customer Creation',
      eventType: 'customer.created',
    },
    {
      name: 'Customer Verification',
      eventType: 'customer.verified',
    },
    {
      name: 'Transaction Pending',
      eventType: 'transaction.pending',
    },
    {
      name: 'Transaction Processing',
      eventType: 'transaction.processing',
    },
    {
      name: 'Transaction Completed (Auto-deposit)',
      eventType: 'transaction.completed',
      data: {
        transactionId: 'test_auto_deposit_tx',
        amount: 50,
        currency: 'USD',
        destinationAddress: '0x742d35cc6644c0532925a3b8d0b74e7c297b0eae',
        transactionHash: '0x' + Math.random().toString(16).substring(2, 66),
      },
    },
    {
      name: 'Transaction Failed',
      eventType: 'transaction.failed',
      data: {
        transactionId: 'test_failed_tx',
        amount: 25,
        reason: 'Network timeout during processing',
      },
    },
    {
      name: 'Customer Rejection',
      eventType: 'customer.rejected',
      data: {
        customerId: 'test_customer_rejected',
        reason: 'Unable to verify identity documents',
      },
    },
  ];
  
  let passed = 0;
  let failed = 0;
  
  for (const test of tests) {
    const result = await runTest(test.name, test.eventType, test.data);
    
    if (result) {
      passed++;
    } else {
      failed++;
    }
    
    // Small delay between tests
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  console.log('\n📊 Test Results:');
  console.log(`✅ Passed: ${passed}`);
  console.log(`❌ Failed: ${failed}`);
  console.log(`📈 Success Rate: ${Math.round((passed / (passed + failed)) * 100)}%`);
  
  if (failed === 0) {
    console.log('\n🎉 All tests passed! Webhook flow is working correctly.');
  } else {
    console.log('\n⚠️  Some tests failed. Check the logs above for details.');
  }
}

async function runInteractiveTest() {
  console.log('\n🎯 Interactive webhook test mode');
  console.log('Available event types:');
  console.log('  - customer.created');
  console.log('  - customer.verified');
  console.log('  - customer.rejected');
  console.log('  - transaction.pending');
  console.log('  - transaction.processing'); 
  console.log('  - transaction.completed');
  console.log('  - transaction.failed');
  
  return new Promise((resolve) => {
    rl.question('\nEnter event type to test (or "quit" to exit): ', async (eventType) => {
      if (eventType.toLowerCase() === 'quit') {
        rl.close();
        resolve();
        return;
      }
      
      const result = await runTest(`Interactive: ${eventType}`, eventType);
      console.log('\nTest completed. Check the logs above for details.\n');
      
      // Continue interactive mode
      await runInteractiveTest();
      resolve();
    });
  });
}

async function seedTestData() {
  console.log('\n🌱 Seeding test wallet mappings...');
  
  try {
    const response = await fetch(`${BASE_URL}/api/wallet/mapping`, {
      method: 'PUT',
    });
    
    const result = await response.json();
    
    if (result.success) {
      console.log('✅ Test data seeded successfully');
      console.log('📋 Seeded mappings:', result.seededMappings.length);
    } else {
      console.log('⚠️ Failed to seed test data:', result.error);
    }
  } catch (error) {
    console.log('⚠️ Could not seed test data:', error.message);
  }
}

async function main() {
  console.log('🧪 Webhook Flow Test Suite');
  console.log('==========================');
  console.log(`🌐 Base URL: ${BASE_URL}`);
  
  // Check if server is running
  try {
    const healthCheck = await fetch(`${BASE_URL}/api/health`);
    if (!healthCheck.ok) {
      throw new Error('Server not responding properly');
    }
  } catch (error) {
    console.log('❌ Server health check failed:', error.message);
    console.log('💡 Make sure your Next.js server is running on', BASE_URL);
    process.exit(1);
  }
  
  // Seed test data in development
  if (process.env.NODE_ENV !== 'production') {
    await seedTestData();
  }
  
  return new Promise((resolve) => {
    rl.question('\nChoose test mode:\n1. Run all tests\n2. Interactive mode\n3. Single test (transaction.completed)\n\nEnter choice (1-3): ', async (choice) => {
      switch (choice) {
        case '1':
          await runAllTests();
          break;
        case '2':
          await runInteractiveTest();
          break;
        case '3':
          await runTest(
            'Quick Test: Transaction Completed', 
            'transaction.completed',
            {
              amount: 75,
              destinationAddress: '0x742d35cc6644c0532925a3b8d0b74e7c297b0eae',
            }
          );
          break;
        default:
          console.log('Invalid choice. Exiting.');
      }
      
      rl.close();
      resolve();
    });
  });
}

// Handle script execution
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { runTest, runAllTests };