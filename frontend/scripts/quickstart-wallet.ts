/**
 * Circle Developer Controlled Wallets - Quickstart Implementation
 * Based on: https://developers.circle.com/w3s/developer-controlled-create-your-first-wallet
 */

import { config } from 'dotenv';
import { initiateDeveloperControlledWalletsClient } from '@circle-fin/developer-controlled-wallets';

// Load environment variables
config({ path: '.env.local' });

async function main() {
  console.log('🔵 Circle Developer Controlled Wallets - Quickstart');
  console.log('==================================================\n');

  const apiKey = process.env.CIRCLE_API_KEY;
  const entitySecret = process.env.CIRCLE_ENTITY_SECRET;

  if (!apiKey || !entitySecret) {
    console.error('❌ Missing CIRCLE_API_KEY or CIRCLE_ENTITY_SECRET in .env.local');
    process.exit(1);
  }

  console.log('✅ Found API key and Entity Secret\n');

  try {
    // Step 1: Initialize the client
    console.log('1️⃣ Initializing Circle SDK client...');
    const client = initiateDeveloperControlledWalletsClient({
      apiKey,
      entitySecret,
    });
    console.log('✅ Client initialized\n');

    // Step 2: Create a Wallet Set
    console.log('2️⃣ Creating Wallet Set...');
    let walletSetId: string;
    
    try {
      // Try to create a new wallet set
      const walletSetResponse = await client.createWalletSet({
        name: `autoUSD-${Date.now()}`, // Unique name with timestamp
      });
      
      walletSetId = walletSetResponse.data?.walletSet?.id || '';
      console.log('✅ Wallet Set created:', walletSetId);
    } catch (error: any) {
      if (error.response?.status === 409) {
        console.log('⚠️  Wallet set might already exist, trying to list existing ones...');
        
        // List existing wallet sets
        const listResponse = await client.listWalletSets();
        if (listResponse.data?.walletSets && listResponse.data.walletSets.length > 0) {
          walletSetId = listResponse.data.walletSets[0].id;
          console.log('✅ Using existing Wallet Set:', walletSetId);
        } else {
          throw new Error('No wallet sets found and cannot create new one');
        }
      } else {
        throw error;
      }
    }
    
    console.log('');

    // Step 3: Create Wallets
    console.log('3️⃣ Creating Wallets...');
    const walletsResponse = await client.createWallets({
      walletSetId,
      accountType: 'SCA', // Smart Contract Account for gasless transactions
      blockchains: ['BASE-SEPOLIA'], // Base Sepolia testnet
      count: 1,
    });

    if (walletsResponse.data?.wallets && walletsResponse.data.wallets.length > 0) {
      const wallet = walletsResponse.data.wallets[0];
      console.log('✅ Wallet created successfully!');
      console.log('   Wallet ID:', wallet.id);
      console.log('   Address:', wallet.address);
      console.log('   Blockchain:', wallet.blockchain);
      console.log('   State:', wallet.state);
      console.log('   Create Date:', wallet.createDate);
      console.log('');
      
      // Step 4: Check wallet balance
      console.log('4️⃣ Checking wallet balance...');
      const balanceResponse = await client.getWalletTokenBalance({
        id: wallet.id,
      });
      
      console.log('✅ Balance retrieved:');
      if (balanceResponse.data?.tokenBalances && balanceResponse.data.tokenBalances.length > 0) {
        balanceResponse.data.tokenBalances.forEach((balance: any) => {
          console.log(`   ${balance.token.symbol}: ${balance.amount}`);
        });
      } else {
        console.log('   No token balances (wallet is empty)');
      }
      console.log('');
      
      console.log('🎉 Success! Your Developer Controlled Wallet is ready.');
      console.log('\n📋 Summary:');
      console.log('   - Wallet Set ID:', walletSetId);
      console.log('   - Wallet Address:', wallet.address);
      console.log('   - Network: Base Sepolia');
      console.log('   - Account Type: Smart Contract Account (gasless)');
      console.log('\n💡 Next Steps:');
      console.log('   1. Fund the wallet with testnet USDC');
      console.log('   2. Test transactions using the wallet');
      console.log('   3. Integrate with your application');
      
    } else {
      console.error('❌ Failed to create wallet - no wallet returned');
    }

  } catch (error: any) {
    console.error('\n❌ Error:', error.message);
    
    if (error.response?.data) {
      console.error('API Error Details:', JSON.stringify(error.response.data, null, 2));
    }
    
    if (error.response?.status === 400) {
      console.log('\n⚠️  Possible issues:');
      console.log('1. Entity Secret might not be registered');
      console.log('2. Invalid parameters in the request');
      console.log('3. Blockchain not supported');
      console.log('\nTry registering your Entity Secret at:');
      console.log('https://console.circle.com/wallets/dev/configurator');
    } else if (error.response?.status === 403) {
      console.log('\n⚠️  Permission denied. Check that your API key has:');
      console.log('- Developer Controlled Wallets permissions');
      console.log('- Correct environment (testnet vs mainnet)');
    }
    
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('Script failed:', error);
  process.exit(1);
});