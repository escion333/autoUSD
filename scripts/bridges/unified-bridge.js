#!/usr/bin/env node

const { ethers } = require('ethers');
require('dotenv').config();

/**
 * Unified Bridge Integration for autoUSD
 * 
 * Provides modular functions for bridging USDC between Ethereum and Katana
 * using the Unified Bridge protocol (friend's script reference).
 * 
 * Based on working implementation with:
 * - Bridge address: 0x528e26b25a34a4A5d0dbDa1d57D318153d2ED582
 * - Katana network ID: 29
 * - ethers v6
 */

// Constants
const UNIFIED_BRIDGE_ADDRESS = '0x528e26b25a34a4A5d0dbDa1d57D318153d2ED582';
const KATANA_NETWORK_ID = 29;
const USDC_DECIMALS = 6;

// Minimal Unified Bridge ABI (functions we need)
const UNIFIED_BRIDGE_ABI = [
  // Bridge asset function (correct parameter order)
  'function bridgeAsset(uint32 destinationNetwork, address destinationAddress, uint256 amount, address token, bool forceUpdateGlobalExitRoot, bytes calldata permitData) external payable',
  
  // Claim asset function
  'function claimAsset(bytes32[] calldata smtProof, bytes32[] calldata smtRollupProof, uint256 globalIndex, bytes32 mainnetExitRoot, bytes32 rollupExitRoot, uint32 originNetwork, address originTokenAddress, uint32 destinationNetwork, address destinationAddress, uint256 amount, bytes calldata metadata) external',
  
  // Check if asset is claimed
  'function isClaimed(uint256 leafIndex, uint32 sourceBridgeNetwork) external view returns (bool)',
  
  // Get bridge events
  'event BridgeEvent(uint8 leafType, uint32 originNetwork, address originAddress, uint32 destinationNetwork, address destinationAddress, uint256 amount, bytes metadata, uint32 depositCount)',
  'event ClaimEvent(uint256 globalIndex, uint32 originNetwork, address originAddress, address destinationAddress, uint256 amount)'
];

// Standard ERC20 ABI for approvals
const ERC20_ABI = [
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function allowance(address owner, address spender) external view returns (uint256)',
  'function balanceOf(address account) external view returns (uint256)',
  'function decimals() external view returns (uint8)',
  'function symbol() external view returns (string)'
];

/**
 * Configuration object for networks and contracts
 */
const config = {
  ethereum: {
    rpcUrl: process.env.ETHEREUM_RPC_URL || process.env.ETH_RPC_URL,
    chainId: 11155111, // Ethereum Sepolia
    usdc: process.env.ETHEREUM_USDC_ADDRESS || '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238', // Ethereum Sepolia USDC
  },
  katana: {
    rpcUrl: process.env.KATANA_RPC_URL || 'https://rpc.tatara.katana.tools',
    chainId: 129399, // Katana Tatara chain ID
    networkId: KATANA_NETWORK_ID,
  },
  user: {
    privateKey: process.env.PRIVATE_KEY,
  }
};

/**
 * Logger utility for consistent output
 */
const logger = {
  info: (msg) => console.log(`ℹ️  ${msg}`),
  success: (msg) => console.log(`✅ ${msg}`),
  warning: (msg) => console.log(`⚠️  ${msg}`),
  error: (msg) => console.error(`❌ ${msg}`),
  step: (msg) => console.log(`\n🔄 ${msg}`),
};

/**
 * Get provider and wallet for a specific network
 * @param {string} network - 'ethereum' or 'katana'
 * @returns {Object} { provider, wallet, signer }
 */
function getNetworkConnection(network) {
  if (!config[network] || !config[network].rpcUrl) {
    throw new Error(`RPC URL not configured for ${network}`);
  }
  
  if (!config.user.privateKey) {
    throw new Error('PRIVATE_KEY not set in environment variables');
  }

  const provider = new ethers.JsonRpcProvider(config[network].rpcUrl);
  const wallet = new ethers.Wallet(config.user.privateKey, provider);
  
  return { provider, wallet, signer: wallet };
}

/**
 * Check USDC balance for an address
 * @param {string} network - 'ethereum' or 'katana'
 * @param {string} address - Address to check balance for
 * @returns {Promise<Object>} { balance, formatted }
 */
async function checkUSDCBalance(network, address) {
  try {
    const { provider } = getNetworkConnection(network);
    
    // Use the appropriate USDC contract address for the network
    const usdcAddress = network === 'ethereum' 
      ? config.ethereum.usdc 
      : config.katana.usdc || config.ethereum.usdc; // Fallback if Katana USDC not set
    
    const usdcContract = new ethers.Contract(usdcAddress, ERC20_ABI, provider);
    const balance = await usdcContract.balanceOf(address);
    const formatted = ethers.formatUnits(balance, USDC_DECIMALS);
    
    return { balance, formatted };
  } catch (error) {
    logger.error(`Failed to check USDC balance on ${network}: ${error.message}`);
    throw error;
  }
}

/**
 * Approve USDC spending for the bridge contract
 * @param {Object} signer - Ethers signer
 * @param {string} amount - Amount to approve (in wei)
 * @returns {Promise<Object>} Transaction receipt
 */
async function approveUSDC(signer, amount) {
  try {
    logger.step('Checking USDC allowance...');
    
    const usdcContract = new ethers.Contract(config.ethereum.usdc, ERC20_ABI, signer);
    const currentAllowance = await usdcContract.allowance(
      await signer.getAddress(),
      UNIFIED_BRIDGE_ADDRESS
    );
    
    if (currentAllowance >= amount) {
      logger.info(`Sufficient allowance already exists: ${ethers.formatUnits(currentAllowance, USDC_DECIMALS)} USDC`);
      return null;
    }
    
    logger.step('Approving USDC spend for bridge contract...');
    const approveTx = await usdcContract.approve(UNIFIED_BRIDGE_ADDRESS, amount);
    
    logger.info(`Approval transaction sent: ${approveTx.hash}`);
    logger.step('Waiting for approval confirmation...');
    
    const receipt = await approveTx.wait();
    logger.success(`USDC approval confirmed in block ${receipt.blockNumber}`);
    
    return receipt;
  } catch (error) {
    logger.error(`Failed to approve USDC: ${error.message}`);
    throw error;
  }
}

/**
 * Bridge USDC from Ethereum to Katana
 * @param {string} amount - Amount in USDC (e.g., "100.5")
 * @param {string} recipient - Recipient address on Katana
 * @param {Object} options - Additional options { forceUpdate, permitData }
 * @returns {Promise<Object>} Bridge transaction result
 */
async function bridgeToKatana(amount, recipient, options = {}) {
  try {
    logger.step(`Initiating bridge: ${amount} USDC from Ethereum to Katana`);
    
    // Validate inputs
    if (!amount || isNaN(parseFloat(amount))) {
      throw new Error('Invalid amount specified');
    }
    
    if (!ethers.isAddress(recipient)) {
      throw new Error('Invalid recipient address');
    }
    
    // Setup connection
    const { signer } = getNetworkConnection('ethereum');
    const userAddress = await signer.getAddress();
    
    // Convert amount to wei
    const amountWei = ethers.parseUnits(amount, USDC_DECIMALS);
    logger.info(`Bridging amount: ${amount} USDC (${amountWei.toString()} wei)`);
    logger.info(`From: ${userAddress}`);
    logger.info(`To: ${recipient} (Katana)`);
    
    // Check balance
    const { balance, formatted } = await checkUSDCBalance('ethereum', userAddress);
    logger.info(`Current USDC balance: ${formatted} USDC`);
    
    if (balance < amountWei) {
      throw new Error(`Insufficient USDC balance. Have: ${formatted}, Need: ${amount}`);
    }
    
    // Approve USDC spending
    await approveUSDC(signer, amountWei);
    
    // Setup bridge contract
    const bridgeContract = new ethers.Contract(UNIFIED_BRIDGE_ADDRESS, UNIFIED_BRIDGE_ABI, signer);
    
    // Prepare bridge parameters
    const {
      forceUpdateGlobalExitRoot = true,
      permitData = '0x'
    } = options;
    
    logger.step('Executing bridge transaction...');
    
    // Execute bridge transaction
    const bridgeTx = await bridgeContract.bridgeAsset(
      config.ethereum.usdc,
      amountWei,
      KATANA_NETWORK_ID,
      recipient,
      forceUpdateGlobalExitRoot,
      permitData,
      { value: 0 } // No ETH required for this bridge
    );
    
    logger.info(`Bridge transaction sent: ${bridgeTx.hash}`);
    logger.step('Waiting for confirmation...');
    
    const receipt = await bridgeTx.wait();
    logger.success(`Bridge transaction confirmed in block ${receipt.blockNumber}`);
    
    // Parse events to get bridge details
    const bridgeEvents = receipt.logs
      .map(log => {
        try {
          return bridgeContract.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .filter(event => event && event.name === 'BridgeEvent');
    
    const result = {
      success: true,
      txHash: receipt.transactionHash,
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed.toString(),
      amount: amount,
      recipient: recipient,
      bridgeEvents: bridgeEvents.map(event => ({
        originNetwork: event.args.originNetwork,
        destinationNetwork: event.args.destinationNetwork,
        depositCount: event.args.depositCount.toString(),
        amount: ethers.formatUnits(event.args.amount, USDC_DECIMALS)
      }))
    };
    
    logger.success('Bridge to Katana completed successfully!');
    logger.info('⏳ Assets will be available on Katana once the bridge processes the transaction');
    logger.info('💡 You can check the status and claim assets when ready');
    
    return result;
    
  } catch (error) {
    logger.error(`Bridge to Katana failed: ${error.message}`);
    throw error;
  }
}

/**
 * Handle claims from Katana back to Ethereum
 * This is a placeholder for the claim functionality which requires
 * merkle proofs from the bridge infrastructure
 * @param {Object} claimParams - Claim parameters from bridge service
 * @returns {Promise<Object>} Claim transaction result
 */
async function bridgeFromKatana(claimParams) {
  try {
    logger.step('Initiating claim from Katana to Ethereum');
    
    if (!claimParams) {
      throw new Error('Claim parameters are required. Get these from the bridge status API.');
    }
    
    // Validate required claim parameters
    const requiredFields = [
      'smtProof', 'smtRollupProof', 'globalIndex', 'mainnetExitRoot',
      'rollupExitRoot', 'originNetwork', 'originTokenAddress',
      'destinationNetwork', 'destinationAddress', 'amount', 'metadata'
    ];
    
    for (const field of requiredFields) {
      if (!(field in claimParams)) {
        throw new Error(`Missing required claim parameter: ${field}`);
      }
    }
    
    // Setup connection to Ethereum (where we claim)
    const { signer } = getNetworkConnection('ethereum');
    const bridgeContract = new ethers.Contract(UNIFIED_BRIDGE_ADDRESS, UNIFIED_BRIDGE_ABI, signer);
    
    // Check if already claimed
    const leafIndex = claimParams.globalIndex; // Adjust this based on actual structure
    const isClaimed = await bridgeContract.isClaimed(leafIndex, claimParams.originNetwork);
    
    if (isClaimed) {
      logger.warning('Assets have already been claimed');
      return { success: false, reason: 'Already claimed' };
    }
    
    logger.step('Executing claim transaction...');
    
    // Execute claim transaction
    const claimTx = await bridgeContract.claimAsset(
      claimParams.smtProof,
      claimParams.smtRollupProof,
      claimParams.globalIndex,
      claimParams.mainnetExitRoot,
      claimParams.rollupExitRoot,
      claimParams.originNetwork,
      claimParams.originTokenAddress,
      claimParams.destinationNetwork,
      claimParams.destinationAddress,
      claimParams.amount,
      claimParams.metadata
    );
    
    logger.info(`Claim transaction sent: ${claimTx.hash}`);
    logger.step('Waiting for confirmation...');
    
    const receipt = await claimTx.wait();
    logger.success(`Claim transaction confirmed in block ${receipt.blockNumber}`);
    
    const result = {
      success: true,
      txHash: receipt.transactionHash,
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed.toString(),
      amount: ethers.formatUnits(claimParams.amount, USDC_DECIMALS),
      recipient: claimParams.destinationAddress
    };
    
    logger.success('Claim from Katana completed successfully!');
    
    return result;
    
  } catch (error) {
    logger.error(`Claim from Katana failed: ${error.message}`);
    throw error;
  }
}

/**
 * Check bridge transaction status and get claim data
 * This would typically query the bridge API for merkle proofs
 * @param {string} txHash - Bridge transaction hash
 * @returns {Promise<Object>} Status and claim data
 */
async function getBridgeStatus(txHash) {
  try {
    logger.step(`Checking bridge status for transaction: ${txHash}`);
    
    // In a real implementation, this would call the bridge API
    // For now, return a placeholder response
    logger.warning('Bridge status checking requires integration with the bridge API');
    logger.info('💡 Implement bridge API integration to get merkle proofs for claiming');
    
    return {
      txHash,
      status: 'pending', // 'pending', 'ready', 'claimed'
      claimData: null, // Would contain merkle proofs when ready
      message: 'Bridge API integration required for status checking'
    };
    
  } catch (error) {
    logger.error(`Failed to check bridge status: ${error.message}`);
    throw error;
  }
}

/**
 * Utility function to estimate gas costs
 * @param {string} operation - 'bridge' or 'claim'
 * @param {string} amount - Amount for estimation
 * @returns {Promise<Object>} Gas estimates
 */
async function estimateGasCosts(operation, amount = '100') {
  try {
    const { signer } = getNetworkConnection('ethereum');
    const bridgeContract = new ethers.Contract(UNIFIED_BRIDGE_ADDRESS, UNIFIED_BRIDGE_ABI, signer);
    
    let gasEstimate;
    
    if (operation === 'bridge') {
      const amountWei = ethers.parseUnits(amount, USDC_DECIMALS);
      const recipient = await signer.getAddress(); // Use sender as recipient for estimation
      
      gasEstimate = await bridgeContract.bridgeAsset.estimateGas(
        config.ethereum.usdc,
        amountWei,
        KATANA_NETWORK_ID,
        recipient,
        true,
        '0x'
      );
    } else {
      logger.warning('Claim gas estimation requires actual claim parameters');
      return { gasEstimate: 'N/A', reason: 'Requires claim parameters' };
    }
    
    const gasPrice = await signer.provider.getFeeData();
    const estimatedCost = gasEstimate * gasPrice.gasPrice;
    
    return {
      gasEstimate: gasEstimate.toString(),
      gasPrice: gasPrice.gasPrice.toString(),
      estimatedCostETH: ethers.formatEther(estimatedCost),
      estimatedCostWei: estimatedCost.toString()
    };
    
  } catch (error) {
    logger.error(`Gas estimation failed: ${error.message}`);
    throw error;
  }
}

// Export functions for use in other scripts
module.exports = {
  bridgeToKatana,
  bridgeFromKatana,
  getBridgeStatus,
  checkUSDCBalance,
  estimateGasCosts,
  config,
  logger,
  UNIFIED_BRIDGE_ADDRESS,
  KATANA_NETWORK_ID
};

// CLI usage when run directly
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.includes('--help') || args.length === 0) {
    console.log(`
🌉 Unified Bridge Integration for autoUSD

Usage:
  node unified-bridge.js bridge <amount> <recipient>     - Bridge USDC to Katana
  node unified-bridge.js claim <claimData>               - Claim assets from Katana
  node unified-bridge.js status <txHash>                 - Check bridge status
  node unified-bridge.js balance <network> <address>     - Check USDC balance
  node unified-bridge.js estimate <operation> [amount]   - Estimate gas costs

Examples:
  node unified-bridge.js bridge 100 0x123...abc
  node unified-bridge.js balance ethereum 0x123...abc
  node unified-bridge.js estimate bridge 50

Environment variables required:
  PRIVATE_KEY              - Private key for transactions
  ETHEREUM_RPC_URL         - Ethereum RPC endpoint
  KATANA_RPC_URL          - Katana RPC endpoint  
  ETHEREUM_USDC_ADDRESS   - USDC contract address on Ethereum
    `);
    process.exit(0);
  }
  
  async function main() {
    try {
      const command = args[0];
      
      switch (command) {
        case 'bridge':
          if (args.length < 3) {
            throw new Error('Usage: bridge <amount> <recipient>');
          }
          const result = await bridgeToKatana(args[1], args[2]);
          console.log('\n📋 Bridge Result:', JSON.stringify(result, null, 2));
          break;
          
        case 'claim':
          if (args.length < 2) {
            throw new Error('Usage: claim <claimDataJSON>');
          }
          const claimData = JSON.parse(args[1]);
          const claimResult = await bridgeFromKatana(claimData);
          console.log('\n📋 Claim Result:', JSON.stringify(claimResult, null, 2));
          break;
          
        case 'status':
          if (args.length < 2) {
            throw new Error('Usage: status <txHash>');
          }
          const status = await getBridgeStatus(args[1]);
          console.log('\n📋 Bridge Status:', JSON.stringify(status, null, 2));
          break;
          
        case 'balance':
          if (args.length < 3) {
            throw new Error('Usage: balance <network> <address>');
          }
          const balance = await checkUSDCBalance(args[1], args[2]);
          console.log(`\n💰 USDC Balance: ${balance.formatted} USDC`);
          break;
          
        case 'estimate':
          if (args.length < 2) {
            throw new Error('Usage: estimate <operation> [amount]');
          }
          const gasEstimate = await estimateGasCosts(args[1], args[2]);
          console.log('\n⛽ Gas Estimate:', JSON.stringify(gasEstimate, null, 2));
          break;
          
        default:
          throw new Error(`Unknown command: ${command}`);
      }
      
    } catch (error) {
      logger.error(error.message);
      process.exit(1);
    }
  }
  
  main();
}