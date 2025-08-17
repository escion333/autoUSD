/**
 * Circle Developer Controlled Wallets Configuration
 * Handles API configuration and environment variables for Circle services
 */

import dotenv from 'dotenv';

// Ensure environment variables are loaded
dotenv.config();

export const circleConfig = {
  // API Configuration
  apiKey: process.env.CIRCLE_API_KEY || '',
  entitySecret: process.env.CIRCLE_ENTITY_SECRET || '',
  walletSetId: process.env.CIRCLE_WALLET_SET_ID || '',
  
  // Paymaster Configuration
  paymasterApiKey: process.env.CIRCLE_PAYMASTER_API_KEY || '',
  paymasterUrl: process.env.NEXT_PUBLIC_PAYMASTER_URL || 'https://api.circle.com/v1/w3s/paymaster',
  entryPointAddress: process.env.NEXT_PUBLIC_ENTRY_POINT_ADDRESS || '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
  
  // Network Configuration
  chainId: parseInt(process.env.NEXT_PUBLIC_CHAIN_ID || '84532'), // Base Sepolia
  rpcUrl: process.env.NEXT_PUBLIC_BASE_RPC_URL || 'https://sepolia.base.org',
  
  // Environment
  environment: process.env.NODE_ENV === 'production' ? 'production' : 'sandbox',
  
  // API Endpoints
  baseUrl: 'https://api.circle.com/v1/w3s',
  
  // Supported Networks for Circle
  supportedNetworks: {
    'base-sepolia': {
      chainId: 84532,
      name: 'Base Sepolia',
      rpcUrl: 'https://sepolia.base.org',
      explorerUrl: 'https://sepolia.basescan.org',
      usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      cctpDomain: 10002,
    },
    'ethereum-sepolia': {
      chainId: 11155111,
      name: 'Ethereum Sepolia',
      rpcUrl: process.env.SEPOLIA_RPC_URL || '',
      explorerUrl: 'https://sepolia.etherscan.io',
      usdcAddress: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
      cctpDomain: 0,
    }
  },
  
  // Wallet Configuration
  walletConfig: {
    accountType: 'SCA', // Smart Contract Account
    maxWalletsPerUser: 1,
    defaultNetwork: 'base-sepolia',
  },
  
  // Transaction Configuration
  transactionConfig: {
    maxRetries: 3,
    retryDelay: 2000, // ms
    confirmationBlocks: 2,
    gasSponsorship: true, // Enable gasless transactions
  }
};

// Validate configuration
export function validateCircleConfig(): boolean {
  const required = [
    'apiKey',
    'entitySecret', 
    'walletSetId',
    'paymasterApiKey'
  ];
  
  // Debug: Log the actual config values
  console.log('Circle config validation:', {
    apiKey: !!circleConfig.apiKey,
    entitySecret: !!circleConfig.entitySecret,
    walletSetId: !!circleConfig.walletSetId,
    paymasterApiKey: !!circleConfig.paymasterApiKey,
  });
  
  for (const field of required) {
    const value = circleConfig[field as keyof typeof circleConfig];
    if (!value || value === '00000000-0000-0000-0000-000000000000') {
      console.error(`Missing or invalid Circle configuration: ${field}`);
      return false;
    }
  }
  
  return true;
}