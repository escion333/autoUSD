require('dotenv').config();

// Network configurations for AggLayer bridge
const config = {
  // Polygon Amoy testnet configuration
  polygonAmoy: {
    networkId: 7, // Polygon Amoy network ID in AggLayer
    rpcUrl: process.env.POLYGON_AMOY_RPC_URL || 'https://rpc-amoy.polygon.technology',
    chainId: 80002,
    name: 'Polygon Amoy Testnet',
    explorer: 'https://amoy.polygonscan.com'
  },
  
  // Katana Tatara testnet configuration
  katanaTatara: {
    networkId: 2, // Katana network ID in AggLayer (needs verification)
    rpcUrl: process.env.KATANA_TATARA_RPC_URL || 'https://rpc.tatara.katana.tools',
    chainId: 2040, // Tatara chain ID (needs verification)
    name: 'Katana Tatara Testnet',
    explorer: 'https://explorer.tatara.katana.tools'
  },
  
  // Bridge configuration
  bridge: {
    // LxLy bridge contract addresses (to be obtained from AggLayer docs)
    polygonBridgeAddress: process.env.POLYGON_BRIDGE_ADDRESS || '',
    katanaBridgeAddress: process.env.KATANA_BRIDGE_ADDRESS || '',
    
    // API endpoints for tracking
    apiGateway: 'https://api-gateway.polygon.technology/api/v3',
    testnetEndpoint: 'https://api-gateway.polygon.technology/api/v3/transactions/testnet'
  },
  
  // Token addresses
  tokens: {
    // USDC on Polygon Amoy
    usdcPolygon: '0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582',
    
    // VBUSDC on Katana Tatara
    vbusdcKatana: '0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD',
    
    // USDT on Katana (for LP pairing)
    usdtKatana: '0xA617Ec5cBC004A6a8b8ECd965B1ef848350e7e73'
  },
  
  // User configuration
  user: {
    privateKey: process.env.PRIVATE_KEY,
    address: process.env.USER_ADDRESS
  },
  
  // Contract addresses (to be filled after deployment)
  contracts: {
    motherVault: process.env.MOTHER_VAULT_BASE || '',
    bridgeVault: process.env.BRIDGE_VAULT_POLYGON || '',
    katanaChildVault: process.env.KATANA_CHILD_VAULT || '',
    aggLayerAdapter: process.env.AGGLAYER_ADAPTER || ''
  }
};

module.exports = config;