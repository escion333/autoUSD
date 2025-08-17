/**
 * Circle Developer Controlled Wallets Service V2
 * Uses the official Circle SDK
 */

import { initiateDeveloperControlledWalletsClient } from '@circle-fin/developer-controlled-wallets';
import crypto from 'crypto';
import { circleConfig } from './config';
import { walletDB } from './database';

export class CircleWalletServiceV2 {
  private client: any;

  constructor() {
    this.client = initiateDeveloperControlledWalletsClient({
      apiKey: circleConfig.apiKey,
      entitySecret: circleConfig.entitySecret,
    });
  }

  /**
   * Create a new wallet for a user
   */
  async createWallet(userId: string): Promise<any> {
    try {
      const response = await this.client.createWallets({
        accountType: 'SCA', // Smart Contract Account for gasless transactions
        blockchains: ['ETH-SEPOLIA'],
        count: 1,
        walletSetId: circleConfig.walletSetId,
      });

      const wallet = response.data?.wallets?.[0];
      if (!wallet) {
        throw new Error('No wallet returned from Circle API');
      }

      // Store wallet-to-user mapping in database
      console.log(`Created wallet for user ${userId}:`, wallet.address);

      return wallet;
    } catch (error: any) {
      console.error('Error creating wallet:', error?.response?.data || error);
      throw new Error(`Failed to create wallet: ${error?.message || error}`);
    }
  }

  /**
   * Get wallet balance
   */
  async getWalletBalance(walletId: string): Promise<any> {
    try {
      const response = await this.client.getWalletTokenBalance({
        id: walletId,
      });

      return response.data?.tokenBalances || [];
    } catch (error: any) {
      console.error('Error getting wallet balance:', error);
      throw new Error(`Failed to get wallet balance: ${error?.message || error}`);
    }
  }

  /**
   * Create a transaction
   */
  async createTransaction(
    walletId: string,
    destinationAddress: string,
    amount: string,
    tokenId: string
  ): Promise<any> {
    try {
      const response = await this.client.createTransaction({
        walletId,
        destinationAddress,
        amounts: [amount],
        tokenId,
        fee: {
          type: 'level',
          config: {
            feeLevel: 'MEDIUM',
          },
        },
      });

      return response.data;
    } catch (error: any) {
      console.error('Error creating transaction:', error);
      throw new Error(`Failed to create transaction: ${error?.message || error}`);
    }
  }

  /**
   * Get transaction status
   */
  async getTransactionStatus(transactionId: string): Promise<any> {
    try {
      const response = await this.client.getTransaction({
        id: transactionId,
      });

      return response.data?.transaction;
    } catch (error: any) {
      console.error('Error getting transaction status:', error);
      throw new Error(`Failed to get transaction status: ${error?.message || error}`);
    }
  }

  /**
   * Execute gasless deposit to Mother Vault (simplified version)
   */
  async executeGaslessDeposit(
    userId: string,
    amount: string,
    motherVaultAddress: string
  ): Promise<any> {
    // This is a placeholder - in production, this would:
    // 1. Get or create user's wallet
    // 2. Create a gasless transaction using Paymaster
    // 3. Execute deposit to Mother Vault
    return {
      transactionId: crypto.randomUUID(),
      status: 'pending',
      walletAddress: 'placeholder',
      amount,
      timestamp: new Date().toISOString(),
    };
  }
}

// Export singleton instance
export const circleWalletServiceV2 = new CircleWalletServiceV2();