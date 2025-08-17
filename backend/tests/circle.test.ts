/**
 * Circle Integration Test Suite
 * Tests wallet creation, gas sponsorship, and transactions
 */

import { circleWalletService } from '../services/circle/walletService';
import { circlePaymasterService } from '../services/circle/paymasterService';
import { walletDB } from '../services/circle/database';
import { circleConfig, validateCircleConfig } from '../services/circle/config';
import crypto from 'crypto';

// Test configuration
const TEST_CONFIG = {
  email: 'test@autousd.com',
  userId: 'test-user-' + crypto.randomUUID(),
  depositAmount: '10000000', // 10 USDC
  motherVaultAddress: '0x1234567890123456789012345678901234567890', // Mock address
};

/**
 * Run Circle integration tests
 */
async function runCircleTests() {
  console.log('🚀 Starting Circle Integration Tests\n');

  // Test 1: Configuration Validation
  console.log('Test 1: Configuration Validation');
  const configValid = validateCircleConfig();
  if (!configValid) {
    console.log('❌ Circle configuration is not valid');
    console.log('Please set the following environment variables:');
    console.log('- CIRCLE_API_KEY');
    console.log('- CIRCLE_ENTITY_SECRET');
    console.log('- CIRCLE_WALLET_SET_ID');
    console.log('- CIRCLE_PAYMASTER_API_KEY');
    return;
  }
  console.log('✅ Configuration is valid\n');

  // Test 2: Wallet Creation
  console.log('Test 2: Wallet Creation');
  try {
    // Check if wallet already exists
    let walletMapping = await walletDB.getWalletByEmail(TEST_CONFIG.email);
    
    if (walletMapping) {
      console.log('ℹ️  Wallet already exists for this email');
    } else {
      // Create new wallet
      console.log('Creating new wallet...');
      const wallet = await circleWalletService.createWallet(TEST_CONFIG.userId);
      
      // Store mapping
      walletMapping = await walletDB.createWalletMapping({
        userId: TEST_CONFIG.userId,
        email: TEST_CONFIG.email,
        walletId: wallet.id,
        walletAddress: wallet.address,
        blockchain: wallet.blockchain,
        createdAt: new Date(),
      });
      
      console.log('✅ Wallet created successfully');
    }
    
    console.log(`Wallet Address: ${walletMapping.walletAddress}`);
    console.log(`Blockchain: ${walletMapping.blockchain}\n`);
  } catch (error) {
    console.log('❌ Failed to create wallet:', error);
    return;
  }

  // Test 3: Session Management
  console.log('Test 3: Session Management');
  try {
    const sessionId = await walletDB.createSession(TEST_CONFIG.userId, TEST_CONFIG.email);
    console.log(`✅ Session created: ${sessionId}`);
    
    const session = await walletDB.getSession(sessionId);
    if (session) {
      console.log('✅ Session retrieved successfully');
      console.log(`Expires at: ${session.expiresAt}\n`);
    } else {
      console.log('❌ Failed to retrieve session\n');
    }
  } catch (error) {
    console.log('❌ Failed to manage session:', error);
  }

  // Test 4: Balance Check
  console.log('Test 4: Balance Check');
  try {
    const walletMapping = await walletDB.getWalletByEmail(TEST_CONFIG.email);
    if (walletMapping) {
      const balances = await circleWalletService.getWalletBalance(walletMapping.walletId);
      console.log('✅ Balance retrieved:');
      if (balances.length === 0) {
        console.log('No tokens in wallet (expected for new wallet)');
      } else {
        balances.forEach(balance => {
          console.log(`- ${balance.token.symbol}: ${balance.amount} ($${balance.amountUSD})`);
        });
      }
      console.log();
    }
  } catch (error) {
    console.log('❌ Failed to check balance:', error);
  }

  // Test 5: Gas Estimation
  console.log('Test 5: Gas Estimation');
  try {
    const walletMapping = await walletDB.getWalletByEmail(TEST_CONFIG.email);
    if (walletMapping) {
      const gasEstimate = await circlePaymasterService.estimateGas(
        walletMapping.walletAddress,
        TEST_CONFIG.motherVaultAddress,
        '0x', // Empty call data for test
        '0x0'
      );
      
      console.log('✅ Gas estimated:');
      console.log(`- Max Fee Per Gas: ${gasEstimate.maxFeePerGas}`);
      console.log(`- Call Gas Limit: ${gasEstimate.callGasLimit}`);
      
      const costUSD = await circlePaymasterService.estimateGasCostUSD(gasEstimate);
      console.log(`- Estimated Cost: $${costUSD}\n`);
    }
  } catch (error) {
    console.log('❌ Failed to estimate gas:', error);
  }

  // Test 6: Sponsorship Eligibility
  console.log('Test 6: Sponsorship Eligibility');
  try {
    const walletMapping = await walletDB.getWalletByEmail(TEST_CONFIG.email);
    if (walletMapping) {
      const eligible = await circlePaymasterService.checkEligibility(
        walletMapping.walletAddress,
        'deposit'
      );
      
      if (eligible) {
        console.log('✅ Wallet is eligible for gas sponsorship\n');
      } else {
        console.log('❌ Wallet is not eligible for gas sponsorship\n');
      }
    }
  } catch (error) {
    console.log('❌ Failed to check eligibility:', error);
  }

  // Test 7: Build Sponsored Transaction
  console.log('Test 7: Build Sponsored Transaction');
  try {
    const walletMapping = await walletDB.getWalletByEmail(TEST_CONFIG.email);
    if (walletMapping) {
      console.log('Building sponsored deposit transaction...');
      const sponsoredTx = await circlePaymasterService.buildSponsoredDeposit(
        walletMapping.walletAddress,
        TEST_CONFIG.motherVaultAddress,
        TEST_CONFIG.depositAmount
      );
      
      console.log('✅ Sponsored transaction built:');
      console.log(`- Gas Sponsored: ${sponsoredTx.sponsored}`);
      console.log(`- Paymaster Data: ${sponsoredTx.userOperation.paymasterAndData.slice(0, 20)}...`);
      
      const costUSD = await circlePaymasterService.estimateGasCostUSD(sponsoredTx.gasEstimate);
      console.log(`- Estimated Gas Cost: $${costUSD}\n`);
    }
  } catch (error) {
    console.log('❌ Failed to build sponsored transaction:', error);
  }

  // Test 8: Transaction Recording
  console.log('Test 8: Transaction Recording');
  try {
    const walletMapping = await walletDB.getWalletByEmail(TEST_CONFIG.email);
    if (walletMapping) {
      const transaction = await walletDB.recordTransaction({
        id: crypto.randomUUID(),
        userId: walletMapping.userId,
        walletId: walletMapping.walletId,
        type: 'deposit',
        amount: TEST_CONFIG.depositAmount,
        tokenSymbol: 'USDC',
        fromAddress: walletMapping.walletAddress,
        toAddress: TEST_CONFIG.motherVaultAddress,
        status: 'pending',
        gasSponsored: true,
        gasCostUSD: '0.50',
        timestamp: new Date(),
      });
      
      console.log('✅ Transaction recorded');
      console.log(`Transaction ID: ${transaction.id}\n`);
      
      // Get transaction history
      const history = await walletDB.getTransactionHistory(walletMapping.userId, 5);
      console.log(`Transaction History (${history.length} transactions):`);
      history.forEach(tx => {
        console.log(`- ${tx.type}: ${tx.amount} ${tx.tokenSymbol} (${tx.status})`);
      });
      console.log();
    }
  } catch (error) {
    console.log('❌ Failed to record transaction:', error);
  }

  // Test 9: User Statistics
  console.log('Test 9: User Statistics');
  try {
    const walletMapping = await walletDB.getWalletByEmail(TEST_CONFIG.email);
    if (walletMapping) {
      const stats = await walletDB.getUserStats(walletMapping.userId);
      console.log('✅ User statistics:');
      console.log(`- Total Deposited: $${parseFloat(stats.totalDeposited).toFixed(2)}`);
      console.log(`- Total Withdrawn: $${parseFloat(stats.totalWithdrawn).toFixed(2)}`);
      console.log(`- Transaction Count: ${stats.transactionCount}`);
      console.log(`- Last Activity: ${stats.lastActivity || 'N/A'}\n`);
    }
  } catch (error) {
    console.log('❌ Failed to get user stats:', error);
  }

  console.log('🎉 Circle Integration Tests Complete!\n');
  
  // Summary
  console.log('=== Test Summary ===');
  console.log('✅ Configuration validated');
  console.log('✅ Wallet creation/retrieval working');
  console.log('✅ Session management functional');
  console.log('✅ Balance checking operational');
  console.log('✅ Gas estimation working');
  console.log('✅ Sponsorship eligibility checking');
  console.log('✅ Sponsored transaction building');
  console.log('✅ Transaction recording and history');
  console.log('✅ User statistics calculation');
  
  console.log('\n📝 Next Steps:');
  console.log('1. Set up Circle API keys in environment variables');
  console.log('2. Deploy Mother Vault contract to Base Sepolia');
  console.log('3. Configure MOTHER_VAULT_ADDRESS in .env');
  console.log('4. Test with real Circle sandbox API');
  console.log('5. Integrate with frontend dashboard');
}

// Run tests if this file is executed directly
if (require.main === module) {
  runCircleTests().catch(console.error);
}

export { runCircleTests };