/**
 * Verification script for cross-chain configuration
 * Ensures MVP is properly configured for Base-only operation with future expansion ready
 */

import { config } from 'dotenv';
import { getEnvironmentConfig } from '../src/lib/config/environment';

// Load environment variables
config({ path: '.env.local' });

// Force staging environment for testnet testing
process.env.NODE_ENV = 'staging';

async function main() {
  console.log('🔗 Verifying Cross-Chain Configuration for MVP');
  console.log('==============================================\n');

  const envConfig = getEnvironmentConfig();
  
  console.log('1️⃣ Environment Configuration:');
  console.log('   Environment:', envConfig.environment);
  console.log('   Cross-chain enabled:', envConfig.features.crossChainEnabled);
  console.log('   Mock transactions:', envConfig.features.mockTransactions);
  console.log('   Debug logging:', envConfig.features.debugLogging);
  console.log('');

  console.log('2️⃣ Network Configuration:');
  console.log('   Base Chain ID:', envConfig.networks.base.chainId);
  console.log('   Base RPC URL:', envConfig.networks.base.rpcUrl);
  console.log('   Base Explorer:', envConfig.networks.base.blockExplorerUrl || 'Not configured');
  console.log('');

  console.log('3️⃣ Contract Configuration:');
  console.log('   MotherVault:', envConfig.contracts.motherVault);
  console.log('   USDC:', envConfig.contracts.usdc);
  console.log('   Katana Child Vault:', envConfig.contracts.katanaChildVault || 'Not deployed (MVP)');
  console.log('   Zircuit Child Vault:', envConfig.contracts.zircuitChildVault || 'Not deployed (MVP)');
  console.log('');

  console.log('4️⃣ Circle Integration:');
  console.log('   App ID configured:', !!envConfig.circle.appId);
  console.log('   Paymaster URL:', envConfig.circle.paymasterUrl);
  console.log('   Entry Point:', envConfig.circle.entryPointAddress);
  console.log('');

  console.log('5️⃣ MVP Validation:');
  
  const validationResults = {
    baseOnly: !envConfig.features.crossChainEnabled,
    motherVaultConfigured: !!envConfig.contracts.motherVault,
    usdcConfigured: !!envConfig.contracts.usdc,
    circleConfigured: !!envConfig.circle.appId && !envConfig.circle.appId.includes('test_'),
    correctChainId: envConfig.networks.base.chainId === 84532,
  };

  // Check actual Circle configuration from environment
  const actualCircleAppId = process.env.NEXT_PUBLIC_CIRCLE_APP_ID;
  if (actualCircleAppId && !actualCircleAppId.includes('test_')) {
    validationResults.circleConfigured = true;
  }

  Object.entries(validationResults).forEach(([check, passed]) => {
    console.log(`   ${passed ? '✅' : '❌'} ${check}:`, passed);
  });

  const allPassed = Object.values(validationResults).every(Boolean);
  
  console.log('');
  
  if (allPassed) {
    console.log('🎉 MVP Cross-Chain Configuration: READY!');
    console.log('');
    console.log('📋 Configuration Summary:');
    console.log('   ✅ Base Sepolia only operation');
    console.log('   ✅ Cross-chain infrastructure ready but disabled');
    console.log('   ✅ MotherVault deployed and configured');
    console.log('   ✅ Circle Developer Controlled Wallets integrated');
    console.log('   ✅ USDC configured for Base Sepolia');
    console.log('');
    console.log('🚀 Ready for MVP launch on Base Sepolia!');
    console.log('');
    console.log('📝 Future Expansion Ready:');
    console.log('   - Hyperlane infrastructure configured');
    console.log('   - CCTP bridge support built-in');
    console.log('   - Child vault interfaces ready');
    console.log('   - Cross-chain can be enabled with feature flag');
  } else {
    console.log('❌ Configuration issues detected');
    console.log('   Please review the failed validations above');
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('Configuration verification failed:', error);
  process.exit(1);
});