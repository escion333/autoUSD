#!/usr/bin/env node

const { ethers } = require('ethers');
const { getLxLyClient } = require('./utils_lxly');
const config = require('./config');

/**
 * Claim bridged assets on destination network
 * Based on AggLayer documentation: https://docs.agglayer.dev/agglayer/get-started/bridge-assets/
 */
async function claimAssets() {
  try {
    console.log('\n===== CLAIMING BRIDGED ASSETS =====\n');
    
    // Parse command line arguments
    const args = process.argv.slice(2);
    const bridgeTxHash = args[0];
    const sourceNetwork = args[1] || 'polygonAmoy';
    const destNetwork = args[2] || 'katanaTatara';
    
    if (!bridgeTxHash) {
      console.error('❌ Error: Bridge transaction hash is required');
      console.log('Usage: node claimAssets.js <bridgeTxHash> [sourceNetwork] [destNetwork]');
      process.exit(1);
    }
    
    if (!config.user.privateKey) {
      throw new Error('PRIVATE_KEY not set in environment');
    }
    
    console.log(`Bridge TX Hash: ${bridgeTxHash}`);
    console.log(`Source Network: ${sourceNetwork}`);
    console.log(`Destination Network: ${destNetwork}`);
    
    // Get network configurations
    const sourceNetworkConfig = config[sourceNetwork];
    const destNetworkConfig = config[destNetwork];
    
    if (!sourceNetworkConfig || !destNetworkConfig) {
      throw new Error('Invalid network names provided');
    }
    
    // Initialize bridge client for destination network
    const bridgeClient = await getLxLyClient(destNetwork, sourceNetwork);
    
    // First, check the transaction status
    console.log('\n📊 Checking bridge transaction status...');
    const status = await bridgeClient.checkStatus(bridgeTxHash);
    
    console.log(`Current status: ${status.status}`);
    
    if (status.status === 'CLAIMED') {
      console.log('✅ Assets already claimed!');
      return;
    } else if (status.status !== 'READY_TO_CLAIM') {
      console.log(`⏳ Transaction not ready to claim yet. Status: ${status.status}`);
      console.log('Please wait for the bridge to complete (usually 10-20 minutes)');
      return;
    }
    
    // Get deposit details from the transaction
    console.log('\n🔍 Fetching deposit details...');
    const depositDetails = status.details;
    const depositCount = depositDetails.depositCount || depositDetails.index;
    
    if (!depositCount && depositCount !== 0) {
      throw new Error('Could not determine deposit count from transaction');
    }
    
    console.log(`Deposit count: ${depositCount}`);
    
    // Get merkle proof for claiming
    console.log('\n📝 Getting merkle proof...');
    const proofData = await bridgeClient.getMerkleProof(
      sourceNetworkConfig.networkId,
      depositCount
    );
    
    if (!proofData) {
      throw new Error('Failed to get merkle proof');
    }
    
    console.log('Merkle proof obtained successfully');
    
    // Prepare claim parameters
    const claimParams = {
      smtProof: proofData.proof,
      index: proofData.index || depositCount,
      mainnetExitRoot: proofData.mainnetExitRoot,
      rollupExitRoot: proofData.rollupExitRoot,
      originNetwork: sourceNetworkConfig.networkId,
      originTokenAddress: config.tokens.usdcPolygon,
      destinationNetwork: destNetworkConfig.networkId,
      destinationAddress: await bridgeClient.signer.getAddress(),
      amount: depositDetails.amount,
      metadata: depositDetails.metadata || '0x'
    };
    
    console.log('\n💸 Claiming assets...');
    console.log(`Amount to claim: ${ethers.formatUnits(claimParams.amount, 6)} USDC`);
    console.log(`Destination address: ${claimParams.destinationAddress}`);
    
    // Execute claim
    const claimResult = await bridgeClient.claimAsset(claimParams);
    
    if (claimResult.success) {
      console.log('\n✅ Claim transaction submitted successfully!');
      console.log('Transaction details:', claimResult.data);
      
      // In production, we would wait for the transaction to be mined
      console.log('\n⏳ Waiting for transaction confirmation...');
      console.log('Check your wallet for the received USDC');
      
      // If this was bridged to BridgeVault, it should forward to Katana
      if (config.contracts.bridgeVault && destNetwork === 'katanaTatara') {
        console.log('\n📦 BridgeVault will forward funds to Katana Child Vault');
        console.log(`Child Vault: ${config.contracts.katanaChildVault}`);
      }
    } else {
      console.error('❌ Claim failed:', claimResult.message);
    }
    
  } catch (error) {
    console.error('\n❌ Error claiming assets:', error.message);
    process.exit(1);
  }
}

// Show usage if --help
if (process.argv.includes('--help')) {
  console.log(`
Usage: node claimAssets.js <bridgeTxHash> [sourceNetwork] [destNetwork]

Arguments:
  bridgeTxHash    - Transaction hash from the bridge operation (required)
  sourceNetwork   - Source network name (default: polygonAmoy)
  destNetwork     - Destination network name (default: katanaTatara)

Examples:
  node claimAssets.js 0x123...abc
  node claimAssets.js 0x123...abc polygonAmoy katanaTatara
  node claimAssets.js 0x123...abc katanaTatara polygonAmoy

Environment variables required:
  PRIVATE_KEY - Private key of the claimer
  POLYGON_AMOY_RPC_URL - Polygon Amoy RPC endpoint
  KATANA_TATARA_RPC_URL - Katana Tatara RPC endpoint

Note: Claims must be made on the destination network. The script will
automatically connect to the correct network based on parameters.
  `);
  process.exit(0);
}

// Run the claim function
claimAssets().catch(console.error);