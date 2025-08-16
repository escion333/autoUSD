/**
 * Test script for Circle Developer Controlled Wallets
 * This tests wallet creation with the current configuration
 */

import { config } from 'dotenv';
import { DeveloperWalletService } from '../src/lib/circle/developer-wallet';

// Load environment variables
config({ path: '.env.local' });

async function main() {
  console.log('🔵 Testing Circle Developer Controlled Wallets');
  console.log('==============================================\n');

  const service = DeveloperWalletService.getInstance();
  
  try {
    // Step 1: Initialize the client
    console.log('1️⃣ Initializing Circle client...');
    await service.initializeClient();
    console.log('✅ Client initialized successfully\n');

    // Step 2: Create a test wallet
    const testEmail = 'test@autousd.com';
    console.log(`2️⃣ Creating wallet for: ${testEmail}...`);
    
    const wallet = await service.getOrCreateWallet(testEmail);
    console.log('✅ Wallet created successfully!');
    console.log('   Wallet ID:', wallet.walletId);
    console.log('   Address:', wallet.walletAddress);
    console.log('   Blockchain:', wallet.blockchain);
    console.log('   Wallet Set ID:', wallet.walletSetId);
    console.log('\n');

    // Step 3: Check wallet balance
    console.log('3️⃣ Checking wallet balance...');
    const balance = await service.getWalletBalance(wallet.walletId);
    console.log('✅ Balance retrieved:');
    console.log('   Token balances:', JSON.stringify(balance, null, 2));
    console.log('\n');

    console.log('🎉 All tests passed! Circle Developer Controlled Wallets are working.');
    console.log('\n📋 Summary:');
    console.log('   - Successfully initialized client with Entity Secret');
    console.log('   - Created a wallet for user email');
    console.log('   - Retrieved wallet balance');
    console.log('   - Ready for production use!');
    
  } catch (error: any) {
    console.error('\n❌ Test failed:', error.message);
    
    if (error.message.includes('401') || error.message.includes('Unauthorized')) {
      console.log('\n⚠️  The API key appears to be invalid or unauthorized.');
      console.log('   Please check:');
      console.log('   1. Your Circle API key in .env.local');
      console.log('   2. That the Entity Secret is registered');
      console.log('   3. That your Circle account has Developer Controlled Wallets enabled');
    } else if (error.message.includes('Entity Secret')) {
      console.log('\n⚠️  Entity Secret issue detected.');
      console.log('   The Entity Secret may not be registered with Circle.');
      console.log('   Try running: npx tsx scripts/setup-circle.ts');
    } else {
      console.log('\n⚠️  Unexpected error. Full details:');
      console.log(error);
    }
    
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('Test script failed:', error);
  process.exit(1);
});