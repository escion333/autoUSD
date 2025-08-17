#!/usr/bin/env node

/**
 * Check bridge transaction status via Polygon API
 * Following official AggLayer documentation
 */

const { checkTransactionStatus } = require('./utils_lxly_official');
const config = require('./config_lxly');

const execute = async () => {
  try {
    console.log('\n===== CHECKING BRIDGE TRANSACTION STATUS =====\n');
    
    // Get user address from config or command line
    const userAddress = process.argv[2] || config.user1.address;
    
    if (!userAddress) {
      console.error('❌ Error: User address is required');
      console.log('\nUsage: node check_status.js [userAddress]');
      process.exit(1);
    }
    
    console.log(`Checking transactions for: ${userAddress}`);
    console.log('Using testnet API endpoint');
    
    // Check transaction status
    const result = await checkTransactionStatus(userAddress, true);
    
    if (!result.transactions || result.transactions.length === 0) {
      console.log('\n📭 No bridge transactions found for this address');
      return;
    }
    
    console.log(`\n📊 Found ${result.transactions.length} transaction(s):\n`);
    
    // Display each transaction
    result.transactions.forEach((tx, index) => {
      console.log(`Transaction ${index + 1}:`);
      console.log('─'.repeat(50));
      console.log(`Status: ${tx.status}`);
      console.log(`Bridge TX: ${tx.transactionHash || tx.bridgeTransactionHash}`);
      console.log(`Amount: ${tx.amount ? (tx.amount / 1e6) + ' USDC' : 'N/A'}`);
      console.log(`Source Network: ${tx.sourceNetwork || tx.fromNetwork}`);
      console.log(`Destination Network: ${tx.destinationNetwork || tx.toNetwork}`);
      console.log(`Timestamp: ${tx.timestamp || 'N/A'}`);
      
      if (tx.depositCount !== undefined) {
        console.log(`Deposit Count: ${tx.depositCount}`);
      }
      
      // Status-specific messages
      switch (tx.status) {
        case 'BRIDGED':
          console.log('💡 Status: Transaction initiated, waiting for finalization');
          break;
        case 'READY_TO_CLAIM':
          console.log('✅ Status: Ready to claim! Run: node claim_asset.js ' + tx.transactionHash);
          break;
        case 'CLAIMED':
          console.log('✅ Status: Successfully claimed on destination');
          break;
        default:
          console.log(`ℹ️  Status: ${tx.status}`);
      }
      
      console.log('');
    });
    
    // Summary
    const readyToClaim = result.transactions.filter(tx => tx.status === 'READY_TO_CLAIM');
    if (readyToClaim.length > 0) {
      console.log('🎯 Action Required:');
      console.log(`You have ${readyToClaim.length} transaction(s) ready to claim!`);
      readyToClaim.forEach(tx => {
        console.log(`\nTo claim: node claim_asset.js ${tx.transactionHash || tx.bridgeTransactionHash}`);
      });
    }
    
  } catch (error) {
    console.error('\n❌ Error checking status:', error.message);
    
    if (error.message.includes('API')) {
      console.log('\n💡 Make sure you have set POLYGON_API_KEY in your .env file');
      console.log('Get your API key from: https://portal.polygon.technology/');
    }
    
    process.exit(1);
  }
};

// Show usage if --help
if (process.argv.includes('--help')) {
  console.log(`
Usage: node check_status.js [userAddress]

Arguments:
  userAddress - Address to check transactions for (optional, uses config if not provided)

Examples:
  node check_status.js
  node check_status.js 0x123...abc

Environment variables required:
  POLYGON_API_KEY - API key from Polygon portal
  USER_ADDRESS - Default address to check (if not provided as argument)

Transaction States:
  BRIDGED        - Transaction initiated on source chain
  READY_TO_CLAIM - Asset available on destination, awaiting claim
  CLAIMED        - Asset successfully claimed on destination

API Documentation:
  https://docs.polygon.technology/tools/bridge-api/
  `);
  process.exit(0);
}

// Execute the status check
execute()
  .then(() => {
    console.log('\n✨ Status check completed');
  })
  .catch(err => {
    console.error('Fatal error:', err);
  })
  .finally(() => {
    process.exit(0);
  });