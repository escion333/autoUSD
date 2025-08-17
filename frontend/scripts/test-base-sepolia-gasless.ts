#!/usr/bin/env npx tsx

/**
 * Test gasless transactions on Base Sepolia testnet
 * This script validates Circle Developer Controlled Wallets integration
 */

import { W3SSdk } from '@circle-fin/w3s-pw-web-sdk';
import { ethers } from 'ethers';

// Base Sepolia configuration
const BASE_SEPOLIA_CONFIG = {
  chainId: 84532,
  rpcUrl: 'https://sepolia.base.org',
  usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
  // These will be populated after deployment
  motherVaultAddress: process.env.NEXT_PUBLIC_MOTHER_VAULT_ADDRESS || '',
  paymasterUrl: 'https://api.circle.com/v1/w3s/paymaster',
  entryPointAddress: '0x0000000071727De22E5E9d8BAf0edAc6f37da032'
};

// Circle API configuration
const CIRCLE_CONFIG = {
  apiKey: process.env.CIRCLE_API_KEY!,
  entitySecret: process.env.CIRCLE_ENTITY_SECRET!,
  appId: process.env.NEXT_PUBLIC_CIRCLE_APP_ID!,
  environment: 'sandbox' as const
};

interface TestResults {
  walletCreation: boolean;
  balanceRetrieval: boolean;
  gaslessApproval: boolean;
  gaslessDeposit: boolean;
  errors: string[];
}

class BaseSepolicGaslessTest {
  private sdk: W3SSdk;
  private provider: ethers.Provider;
  private results: TestResults = {
    walletCreation: false,
    balanceRetrieval: false,
    gaslessApproval: false,
    gaslessDeposit: false,
    errors: []
  };

  constructor() {
    this.sdk = new W3SSdk({
      apiKey: CIRCLE_CONFIG.apiKey,
      entitySecret: CIRCLE_CONFIG.entitySecret,
      environment: CIRCLE_CONFIG.environment
    });
    
    this.provider = new ethers.JsonRpcProvider(BASE_SEPOLIA_CONFIG.rpcUrl);
  }

  async runTests(): Promise<TestResults> {
    console.log('🧪 Starting Base Sepolia Gasless Transaction Tests');
    console.log('Network:', BASE_SEPOLIA_CONFIG.chainId, '(Base Sepolia)');
    console.log('USDC Address:', BASE_SEPOLIA_CONFIG.usdcAddress);
    console.log('Mother Vault:', BASE_SEPOLIA_CONFIG.motherVaultAddress || 'NOT DEPLOYED YET');
    console.log();

    try {
      await this.testWalletCreation();
      await this.testBalanceRetrieval();
      await this.testGaslessApproval();
      await this.testGaslessDeposit();
    } catch (error) {
      this.results.errors.push(`Test suite error: ${error}`);
    }

    this.printResults();
    return this.results;
  }

  private async testWalletCreation(): Promise<void> {
    console.log('🔑 Testing wallet creation...');
    
    try {
      const response = await this.sdk.createWallets({
        blockchains: ['BASE-SEPOLIA'],
        count: 1,
        walletSetId: process.env.CIRCLE_WALLET_SET_ID
      });

      if (response.data?.wallets && response.data.wallets.length > 0) {
        const wallet = response.data.wallets[0];
        console.log('✅ Wallet created successfully');
        console.log('   Wallet ID:', wallet.id);
        console.log('   Address:', wallet.address);
        
        this.results.walletCreation = true;
      } else {
        throw new Error('No wallet returned from creation');
      }
    } catch (error) {
      console.log('❌ Wallet creation failed:', error);
      this.results.errors.push(`Wallet creation: ${error}`);
    }
  }

  private async testBalanceRetrieval(): Promise<void> {
    console.log('\n💰 Testing balance retrieval...');
    
    try {
      // Get user wallets for Base Sepolia
      const wallets = await this.sdk.getWallets({
        blockchain: 'BASE-SEPOLIA'
      });

      if (wallets.data?.wallets && wallets.data.wallets.length > 0) {
        const wallet = wallets.data.wallets[0];
        
        // Check ETH balance for gas
        const ethBalance = await this.provider.getBalance(wallet.address);
        console.log('✅ ETH Balance:', ethers.formatEther(ethBalance), 'ETH');
        
        // Check USDC balance
        const usdcContract = new ethers.Contract(
          BASE_SEPOLIA_CONFIG.usdcAddress,
          ['function balanceOf(address) view returns (uint256)'],
          this.provider
        );
        
        const usdcBalance = await usdcContract.balanceOf(wallet.address);
        console.log('✅ USDC Balance:', ethers.formatUnits(usdcBalance, 6), 'USDC');
        
        this.results.balanceRetrieval = true;
      } else {
        throw new Error('No wallets found for balance check');
      }
    } catch (error) {
      console.log('❌ Balance retrieval failed:', error);
      this.results.errors.push(`Balance retrieval: ${error}`);
    }
  }

  private async testGaslessApproval(): Promise<void> {
    console.log('\n⚡ Testing gasless USDC approval...');
    
    if (!BASE_SEPOLIA_CONFIG.motherVaultAddress) {
      console.log('⚠️  Skipping - Mother Vault not deployed yet');
      console.log('   Deploy contracts first, then update NEXT_PUBLIC_MOTHER_VAULT_ADDRESS');
      return;
    }

    try {
      const wallets = await this.sdk.getWallets({
        blockchain: 'BASE-SEPOLIA'
      });

      if (!wallets.data?.wallets || wallets.data.wallets.length === 0) {
        throw new Error('No wallet available for gasless transaction');
      }

      const wallet = wallets.data.wallets[0];
      
      // Prepare USDC approval transaction
      const approvalTx = {
        to: BASE_SEPOLIA_CONFIG.usdcAddress,
        data: ethers.Interface.encodeFunctionData(
          'function approve(address spender, uint256 amount)',
          [BASE_SEPOLIA_CONFIG.motherVaultAddress, ethers.parseUnits('100', 6)] // $100 USDC
        ),
        value: '0'
      };

      // Execute gasless transaction via Circle paymaster
      const response = await this.sdk.executeTransaction({
        walletId: wallet.id,
        transaction: approvalTx,
        gasLimit: '100000',
        gasPrice: 'auto',
        paymaster: {
          url: BASE_SEPOLIA_CONFIG.paymasterUrl,
          context: {
            entryPoint: BASE_SEPOLIA_CONFIG.entryPointAddress,
            sponsorshipPolicy: process.env.CIRCLE_PAYMASTER_POLICY_ID
          }
        }
      });

      console.log('✅ Gasless approval transaction submitted');
      console.log('   Transaction ID:', response.data?.transactionId);
      
      this.results.gaslessApproval = true;
    } catch (error) {
      console.log('❌ Gasless approval failed:', error);
      this.results.errors.push(`Gasless approval: ${error}`);
    }
  }

  private async testGaslessDeposit(): Promise<void> {
    console.log('\n🏦 Testing gasless vault deposit...');
    
    if (!BASE_SEPOLIA_CONFIG.motherVaultAddress) {
      console.log('⚠️  Skipping - Mother Vault not deployed yet');
      return;
    }

    try {
      const wallets = await this.sdk.getWallets({
        blockchain: 'BASE-SEPOLIA'
      });

      if (!wallets.data?.wallets || wallets.data.wallets.length === 0) {
        throw new Error('No wallet available for deposit');
      }

      const wallet = wallets.data.wallets[0];
      
      // Prepare vault deposit transaction
      const depositTx = {
        to: BASE_SEPOLIA_CONFIG.motherVaultAddress,
        data: ethers.Interface.encodeFunctionData(
          'function deposit(uint256 assets, address receiver)',
          [ethers.parseUnits('10', 6), wallet.address] // $10 USDC deposit
        ),
        value: '0'
      };

      // Execute gasless deposit
      const response = await this.sdk.executeTransaction({
        walletId: wallet.id,
        transaction: depositTx,
        gasLimit: '200000',
        gasPrice: 'auto',
        paymaster: {
          url: BASE_SEPOLIA_CONFIG.paymasterUrl,
          context: {
            entryPoint: BASE_SEPOLIA_CONFIG.entryPointAddress,
            sponsorshipPolicy: process.env.CIRCLE_PAYMASTER_POLICY_ID
          }
        }
      });

      console.log('✅ Gasless deposit transaction submitted');
      console.log('   Transaction ID:', response.data?.transactionId);
      
      this.results.gaslessDeposit = true;
    } catch (error) {
      console.log('❌ Gasless deposit failed:', error);
      this.results.errors.push(`Gasless deposit: ${error}`);
    }
  }

  private printResults(): void {
    console.log('\n' + '='.repeat(50));
    console.log('📊 BASE SEPOLIA GASLESS TEST RESULTS');
    console.log('='.repeat(50));
    
    console.log('🔑 Wallet Creation:', this.results.walletCreation ? '✅ PASS' : '❌ FAIL');
    console.log('💰 Balance Retrieval:', this.results.balanceRetrieval ? '✅ PASS' : '❌ FAIL');
    console.log('⚡ Gasless Approval:', this.results.gaslessApproval ? '✅ PASS' : '⚠️  SKIP');
    console.log('🏦 Gasless Deposit:', this.results.gaslessDeposit ? '✅ PASS' : '⚠️  SKIP');
    
    const passed = Object.values(this.results).filter(r => r === true).length;
    const total = 4;
    console.log('\n📈 Overall:', `${passed}/${total} tests passed`);
    
    if (this.results.errors.length > 0) {
      console.log('\n❌ Errors:');
      this.results.errors.forEach(error => console.log(`   • ${error}`));
    }

    console.log('\n📋 Next Steps:');
    if (!BASE_SEPOLIA_CONFIG.motherVaultAddress) {
      console.log('   1. Deploy Mother Vault to Base Sepolia');
      console.log('   2. Update NEXT_PUBLIC_MOTHER_VAULT_ADDRESS in .env.local');
      console.log('   3. Re-run this test to validate gasless transactions');
    } else {
      console.log('   1. Obtain Base Sepolia test USDC from Circle faucet');
      console.log('   2. Test end-to-end deposit/withdrawal flows');
      console.log('   3. Proceed to Phase 3: Cross-chain testnet validation');
    }
  }
}

// Run tests if called directly
if (require.main === module) {
  const tester = new BaseSepolicGaslessTest();
  tester.runTests().catch(console.error);
}

export { BaseSepolicGaslessTest };