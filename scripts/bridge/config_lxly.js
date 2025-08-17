require('dotenv').config();

/**
 * LxLy.js Configuration for Polygon-Katana Bridge
 * Based on official AggLayer documentation
 */

const config = {
  // User configuration from environment
  user1: {
    privateKey: process.env.PRIVATE_KEY,
    address: process.env.USER_ADDRESS
  },
  
  // Network configurations for LxLy.js
  // Network IDs in AggLayer:
  // 0 = Ethereum/Sepolia
  // 1 = Polygon zkEVM/Cardona  
  // 7 = Polygon PoS (Amoy for testnet)
  // Custom IDs for other chains like Katana
  
  configuration: {
    // Polygon Amoy Testnet (Network ID: 7 in AggLayer)
    7: {
      rpc: 'https://rpc-amoy.polygon.technology',
      bridgeAddress: '0x528e26b25a34a4A5d0dbDa1d57D318153d2ED582', // Unified Bridge on Polygon Amoy
      bridgeExtensionAddress: '0x0000000000000000000000000000000000000000', // Not required for basic bridging
      wrapperAddress: '0x0000000000000000000000000000000000000000', // Not required for USDC
      chainId: 80002,
      name: 'Polygon Amoy Testnet'
    },
    
    // Katana Network - Already integrated with AggLayer's Unified Bridge
    // Katana uses CDK OP Stack with AggLayer shared bridge
    // Network ID to be confirmed - using placeholder for now
    100: {
      rpc: 'https://rpc.tatara.katana.tools',
      bridgeAddress: '0x0000000000000000000000000000000000000000', // Handled by AggLayer Unified Bridge
      bridgeExtensionAddress: '0x0000000000000000000000000000000000000000',
      chainId: 2040, // Katana Tatara testnet chain ID
      name: 'Katana Tatara Testnet'
    }
  },
  
  // Token addresses
  tokens: {
    // Polygon Amoy tokens
    7: {
      usdc: '0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582', // USDC on Polygon Amoy
      ether: '0x0000000000000000000000000000000000000000' // Native token placeholder
    },
    
    // Katana Tatara tokens  
    100: {
      vbusdc: '0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD', // VBUSDC on Katana
      usdt: '0xA617Ec5cBC004A6a8b8ECd965B1ef848350e7e73', // USDT on Katana
      ether: '0x0000000000000000000000000000000000000000' // Native token placeholder
    }
  },
  
  // Contract addresses (filled after deployment)
  contracts: {
    motherVault: process.env.MOTHER_VAULT_BASE || '',
    bridgeVault: process.env.BRIDGE_VAULT_POLYGON || '',
    katanaChildVault: process.env.KATANA_CHILD_VAULT || '',
    aggLayerAdapter: process.env.AGGLAYER_ADAPTER || ''
  },
  
  // API configuration
  api: {
    key: process.env.POLYGON_API_KEY || '',
    endpoints: {
      testnet: {
        transactions: 'https://api-gateway.polygon.technology/api/v3/transactions/testnet',
        proof: 'https://api-gateway.polygon.technology/api/v3/proof/testnet/merkle-proof'
      },
      mainnet: {
        transactions: 'https://api-gateway.polygon.technology/api/v3/transactions/mainnet',
        proof: 'https://api-gateway.polygon.technology/api/v3/proof/mainnet/merkle-proof'
      }
    }
  }
};

module.exports = config;