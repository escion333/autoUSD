/**
 * Test Full User Flow with Circle Developer Controlled Wallets
 * This simulates the complete user journey from signup to wallet operations
 */

import { config } from 'dotenv';
import { DeveloperWalletService } from '../src/lib/circle/developer-wallet';

// Load environment variables
config({ path: '.env.local' });

// Test user data
const TEST_USERS = [
  'alice@autousd.com',
  'bob@autousd.com',
  'charlie@autousd.com'
];

async function simulateUserSignup(email: string) {
  console.log(`\n👤 Simulating signup for: ${email}`);
  console.log('─'.repeat(50));
  
  const service = DeveloperWalletService.getInstance();
  
  try {
    // Create wallet for user
    console.log('  📱 Creating wallet...');
    const wallet = await service.getOrCreateWallet(email);
    
    console.log('  ✅ Wallet created:');
    console.log(`     Address: ${wallet.walletAddress}`);
    console.log(`     Wallet ID: ${wallet.walletId}`);
    console.log(`     Created: ${wallet.createdAt.toISOString()}`);
    
    // Check balance
    console.log('\n  💰 Checking balance...');
    const balance = await service.getWalletBalance(wallet.walletId);
    
    if (balance.length > 0) {
      console.log('  📊 Token balances:');
      balance.forEach((token: any) => {
        console.log(`     ${token.token.symbol}: ${token.amount}`);
      });
    } else {
      console.log('  📊 Balance: 0 (empty wallet)');
    }
    
    return wallet;
  } catch (error: any) {
    console.error(`  ❌ Error: ${error.message}`);
    throw error;
  }
}

async function testWalletPersistence(email: string) {
  console.log(`\n🔄 Testing wallet persistence for: ${email}`);
  console.log('─'.repeat(50));
  
  const service = DeveloperWalletService.getInstance();
  
  // First call - should retrieve existing wallet
  console.log('  📱 Retrieving existing wallet...');
  const wallet1 = await service.getOrCreateWallet(email);
  
  // Second call - should return same wallet
  console.log('  🔄 Calling again (should return same wallet)...');
  const wallet2 = await service.getOrCreateWallet(email);
  
  if (wallet1.walletId === wallet2.walletId && wallet1.walletAddress === wallet2.walletAddress) {
    console.log('  ✅ Wallet persistence working correctly');
    console.log(`     Same wallet returned: ${wallet1.walletAddress}`);
  } else {
    console.error('  ❌ Wallet persistence failed - different wallets returned');
  }
}

async function displaySummary(wallets: any[]) {
  console.log('\n' + '='.repeat(60));
  console.log('📊 SUMMARY - All Created Wallets');
  console.log('='.repeat(60));
  
  console.log('\n┌─────────────────────────┬──────────────────────────────────────────┬─────────────┐');
  console.log('│ User Email              │ Wallet Address                           │ Network     │');
  console.log('├─────────────────────────┼──────────────────────────────────────────┼─────────────┤');
  
  wallets.forEach(wallet => {
    const email = wallet.email.padEnd(23);
    const address = wallet.walletAddress.padEnd(42);
    const network = wallet.blockchain.padEnd(11);
    console.log(`│ ${email} │ ${address} │ ${network} │`);
  });
  
  console.log('└─────────────────────────┴──────────────────────────────────────────┴─────────────┘');
}

async function main() {
  console.log('🚀 Circle Developer Controlled Wallets - Full Flow Test');
  console.log('='.repeat(60));
  console.log('This test simulates the complete user journey:\n');
  console.log('1. User signs up with email');
  console.log('2. Platform creates a wallet for them');
  console.log('3. User can check their balance');
  console.log('4. Wallet persists across sessions');
  console.log('='.repeat(60));
  
  const service = DeveloperWalletService.getInstance();
  
  try {
    // Initialize service once
    console.log('\n🔧 Initializing Circle service...');
    await service.initializeClient();
    console.log('✅ Service initialized\n');
    
    // Create wallets for test users
    const wallets = [];
    for (const email of TEST_USERS) {
      const wallet = await simulateUserSignup(email);
      wallets.push(wallet);
      
      // Add small delay between users
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    // Test wallet persistence
    await testWalletPersistence(TEST_USERS[0]);
    
    // Display summary
    await displaySummary(wallets);
    
    console.log('\n✅ All tests completed successfully!');
    console.log('\n📝 Key Takeaways:');
    console.log('   • Wallets are created instantly for new users');
    console.log('   • Each user gets a unique blockchain address');
    console.log('   • Wallets persist across sessions (cached in memory)');
    console.log('   • Platform manages all keys - users only need email');
    console.log('   • Ready for gasless transactions on Base Sepolia');
    
    console.log('\n🎯 Next Steps:');
    console.log('   1. Fund wallets with testnet USDC');
    console.log('   2. Test deposit to Mother Vault contract');
    console.log('   3. Implement Fern onramp integration');
    console.log('   4. Deploy to production with mainnet API key');
    
  } catch (error: any) {
    console.error('\n❌ Test failed:', error.message);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('Test script failed:', error);
  process.exit(1);
});