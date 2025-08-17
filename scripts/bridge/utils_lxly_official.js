const { LxLyClient } = require('@polygon.technology/lxlyjs');
const HDWalletProvider = require('@truffle/hdwallet-provider');
const config = require('./config_lxly');

/**
 * Initialize LxLy client with HDWalletProvider
 * Following official AggLayer documentation pattern
 */
const getLxLyClient = async (network = 'testnet') => {
  // Validate configuration
  if (!config.user1.privateKey) {
    throw new Error('Private key not configured in environment');
  }
  if (!config.user1.address) {
    throw new Error('User address not configured in environment');
  }
  
  try {
    const lxLyClient = new LxLyClient();
    
    // For Polygon Amoy <-> Katana bridging
    // Katana is already integrated with AggLayer's Unified Bridge
    
    return await lxLyClient.init({
    log: true,
    network: network,
    providers: {
      // Polygon Amoy (Network ID: 7)
      7: {
        provider: new HDWalletProvider(
          [config.user1.privateKey], 
          config.configuration[7].rpc
        ),
        configuration: {
          bridgeAddress: config.configuration[7].bridgeAddress,
          bridgeExtensionAddress: config.configuration[7].bridgeExtensionAddress,
          wrapperAddress: config.configuration[7].wrapperAddress,
          isEIP1559Supported: true
        },
        defaultConfig: {
          from: config.user1.address
        }
      },
      
      // Katana Tatara (Network ID: 100 - placeholder, needs AggLayer registration)
      100: {
        provider: new HDWalletProvider(
          [config.user1.privateKey], 
          config.configuration[100].rpc
        ),
        configuration: {
          bridgeAddress: config.configuration[100].bridgeAddress,
          bridgeExtensionAddress: config.configuration[100].bridgeExtensionAddress,
          isEIP1559Supported: false // Katana may not support EIP-1559
        },
        defaultConfig: {
          from: config.user1.address
        }
      }
    }
  });
  } catch (error) {
    console.error('Failed to initialize LxLy client:', error);
    throw error;
  }
};

/**
 * Get token configuration for a specific network
 */
const getTokens = () => {
  return config.tokens;
};

/**
 * Check transaction status via API
 */
const checkTransactionStatus = async (userAddress, isTestnet = true) => {
  const endpoint = isTestnet 
    ? config.api.endpoints.testnet.transactions
    : config.api.endpoints.mainnet.transactions;
    
  const url = `${endpoint}?userAddress=${userAddress}`;
  
  try {
    const response = await fetch(url, {
      headers: {
        'x-api-key': config.api.key
      }
    });
    
    if (!response.ok) {
      throw new Error(`API request failed: ${response.status}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('Error checking transaction status:', error);
    throw error;
  }
};

/**
 * Get merkle proof for claiming
 */
const getMerkleProof = async (networkId, depositCount, isTestnet = true) => {
  const endpoint = isTestnet
    ? config.api.endpoints.testnet.proof
    : config.api.endpoints.mainnet.proof;
    
  const url = `${endpoint}?networkId=${networkId}&depositCount=${depositCount}`;
  
  try {
    const response = await fetch(url, {
      headers: {
        'x-api-key': config.api.key
      }
    });
    
    if (!response.ok) {
      throw new Error(`API request failed: ${response.status}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('Error getting merkle proof:', error);
    throw error;
  }
};

/**
 * Wait for transaction to be ready to claim
 */
const waitForReadyToClaim = async (txHash, maxAttempts = 60, interval = 10000) => {
  console.log(`Waiting for transaction ${txHash} to be ready to claim...`);
  
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const status = await checkTransactionStatus(config.user1.address);
      
      // Find our transaction
      const tx = status.transactions?.find(t => 
        t.transactionHash === txHash || 
        t.bridgeTransactionHash === txHash
      );
      
      if (!tx) {
        console.log(`Attempt ${i + 1}/${maxAttempts}: Transaction not found yet`);
      } else if (tx.status === 'READY_TO_CLAIM') {
        console.log('Transaction is ready to claim!');
        return tx;
      } else if (tx.status === 'CLAIMED') {
        console.log('Transaction already claimed');
        return tx;
      } else {
        console.log(`Attempt ${i + 1}/${maxAttempts}: Status is ${tx.status}`);
      }
      
      // Wait before next check
      await new Promise(resolve => setTimeout(resolve, interval));
    } catch (error) {
      console.error(`Error checking status: ${error.message}`);
    }
  }
  
  throw new Error('Timeout waiting for transaction to be ready');
};

module.exports = {
  getLxLyClient,
  getTokens,
  checkTransactionStatus,
  getMerkleProof,
  waitForReadyToClaim,
  tokens: config.tokens
};