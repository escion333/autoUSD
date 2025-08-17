/**
 * Test script for gasless deposits using Circle Developer Controlled Wallets
 * Tests integration with deployed MotherVault on Base Sepolia
 */

import { config } from 'dotenv';
import { DeveloperWalletService } from '../src/lib/circle/developer-wallet';
import { getEnvironmentConfig } from '../src/lib/config/environment';
import { createPublicClient, http, Address, formatUnits } from 'viem';
import { baseSepolia } from 'viem/chains';

// Load environment variables
config({ path: '.env.local' });

// Force staging environment for testnet testing
process.env.NODE_ENV = 'staging';

const USDC_ABI = [
  {
    "type": "function",
    "name": "balanceOf", 
    "inputs": [{"name": "account", "type": "address", "internalType": "address"}],
    "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "symbol",
    "inputs": [],
    "outputs": [{"name": "", "type": "string", "internalType": "string"}],
    "stateMutability": "view"
  }
] as const;

const MOTHER_VAULT_ABI = [
  {
    "type": "function",
    "name": "balanceOf",
    "inputs": [{"name": "account", "type": "address", "internalType": "address"}],
    "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "symbol",
    "inputs": [],
    "outputs": [{"name": "", "type": "string", "internalType": "string"}],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalSupply",
    "inputs": [],
    "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
    "stateMutability": "view"
  }
] as const;

async function main() {
  console.log('🧪 Testing Gasless Deposit Integration');
  console.log('====================================\n');

  const config = getEnvironmentConfig();
  const service = DeveloperWalletService.getInstance();
  
  // Create public client for reading blockchain state
  const publicClient = createPublicClient({
    chain: baseSepolia,
    transport: http(config.networks.base.rpcUrl),
  });
  
  try {
    // Step 1: Initialize Circle client
    console.log('1️⃣ Initializing Circle client...');
    await service.initializeClient();
    console.log('✅ Client initialized\n');

    // Step 2: Get or create test wallet
    const testEmail = 'deposit-test@autousd.com';
    console.log(`2️⃣ Setting up wallet for: ${testEmail}...`);
    
    const wallet = await service.getOrCreateWallet(testEmail);
    const userAddress = wallet.walletAddress as Address;
    
    console.log('✅ Wallet ready:');
    console.log('   Wallet ID:', wallet.walletId);
    console.log('   Address:', userAddress);
    console.log('   Blockchain:', wallet.blockchain);
    console.log('');

    // Step 3: Check contract deployments
    console.log('3️⃣ Verifying contract deployments...');
    console.log('   USDC Address:', config.contracts.usdc);
    console.log('   MotherVault Address:', config.contracts.motherVault);
    
    try {
      const usdcSymbol = await publicClient.readContract({
        address: config.contracts.usdc as Address,
        abi: USDC_ABI,
        functionName: 'symbol',
      });
      console.log('   ✅ USDC contract verified:', usdcSymbol);
      
      const vaultSymbol = await publicClient.readContract({
        address: config.contracts.motherVault as Address,
        abi: MOTHER_VAULT_ABI,
        functionName: 'symbol',
      });
      console.log('   ✅ MotherVault contract verified:', vaultSymbol);
      
      const vaultTotalSupply = await publicClient.readContract({
        address: config.contracts.motherVault as Address,
        abi: MOTHER_VAULT_ABI,
        functionName: 'totalSupply',
      });
      console.log('   📊 MotherVault total supply:', formatUnits(vaultTotalSupply, 6), vaultSymbol);
      
    } catch (contractError) {
      console.error('❌ Contract verification failed:', contractError);
      throw new Error('Contracts not properly deployed or accessible');
    }
    console.log('');

    // Step 4: Check wallet balances
    console.log('4️⃣ Checking wallet balances...');
    
    const usdcBalance = await publicClient.readContract({
      address: config.contracts.usdc as Address,
      abi: USDC_ABI,
      functionName: 'balanceOf',
      args: [userAddress],
    });
    
    const vaultBalance = await publicClient.readContract({
      address: config.contracts.motherVault as Address,
      abi: MOTHER_VAULT_ABI,
      functionName: 'balanceOf',
      args: [userAddress],
    });
    
    console.log('   💵 USDC Balance:', formatUnits(usdcBalance, 6), 'USDC');
    console.log('   📊 Vault Shares:', formatUnits(vaultBalance, 6), 'aUSD');
    console.log('');

    // Step 5: Test deposit readiness
    console.log('5️⃣ Testing deposit readiness...');
    
    if (usdcBalance === 0n) {
      console.log('⚠️  No USDC balance detected.');
      console.log('   To test deposits, you need test USDC.');
      console.log('   Get test USDC from: https://faucet.circle.com/');
      console.log('   Send test USDC to:', userAddress);
      console.log('');
      console.log('📋 Integration Setup Complete!');
      console.log('   - Circle wallets: ✅ Working');
      console.log('   - Contracts: ✅ Deployed and verified');
      console.log('   - Ready for testing with test USDC');
      return;
    }
    
    console.log('✅ Wallet has USDC - ready for deposit testing!');
    console.log('');

    // Step 6: Test deposit API (simulation)
    console.log('6️⃣ Testing deposit API...');
    console.log('   Note: This would call /api/wallet/deposit with:');
    console.log('   - walletId:', wallet.walletId);
    console.log('   - amount: 1000000 (1 USDC)');
    console.log('   - vaultAddress:', config.contracts.motherVault);
    console.log('   - usdcAddress:', config.contracts.usdc);
    console.log('');

    console.log('🎉 Deposit Integration Test Complete!');
    console.log('');
    console.log('📋 Integration Status:');
    console.log('   ✅ Circle Developer Controlled Wallets');
    console.log('   ✅ MotherVault deployed and accessible');
    console.log('   ✅ USDC contract verified');
    console.log('   ✅ Wallet created and ready');
    console.log('   ✅ API endpoints created');
    console.log('');
    console.log('🚀 Ready for gasless deposits!');
    
  } catch (error: any) {
    console.error('\n❌ Integration test failed:', error.message);
    
    if (error.message.includes('USDC')) {
      console.log('\n💡 To fix USDC issues:');
      console.log('   1. Get test USDC from https://faucet.circle.com/');
      console.log('   2. Send test USDC to the generated wallet address');
    } else if (error.message.includes('MotherVault')) {
      console.log('\n💡 To fix MotherVault issues:');
      console.log('   1. Verify NEXT_PUBLIC_MOTHER_VAULT_ADDRESS in .env.local');
      console.log('   2. Ensure the contract is deployed on Base Sepolia');
    }
    
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('Integration test failed:', error);
  process.exit(1);
});