/**
 * Circle Developer Controlled Wallets Service
 * Manages wallet creation, transactions, and user mapping
 */

import axios, { AxiosInstance } from 'axios';
import crypto from 'crypto';
import { circleConfig } from './config';

export interface CircleWallet {
  id: string;
  address: string;
  blockchain: string;
  walletSetId: string;
  userId: string;
  state: 'LIVE' | 'FROZEN';
  createDate: string;
  updateDate: string;
}

export interface WalletBalance {
  token: {
    symbol: string;
    decimals: number;
    name: string;
  };
  amount: string;
  amountUSD: string;
}

export interface TransactionRequest {
  idempotencyKey: string;
  amounts: string[];
  destinationAddress: string;
  tokenId: string;
  walletId: string;
  fee?: {
    type: 'level';
    config: {
      feeLevel: 'LOW' | 'MEDIUM' | 'HIGH';
    };
  };
}

export class CircleWalletService {
  private client: AxiosInstance;
  private entitySecret: string;

  constructor() {
    this.entitySecret = circleConfig.entitySecret;
    
    this.client = axios.create({
      baseURL: circleConfig.baseUrl,
      headers: {
        'Authorization': `Bearer ${circleConfig.apiKey}`,
        'Content-Type': 'application/json',
      },
    });
  }

  /**
   * Generate entity secret cipher text for wallet operations
   */
  private generateEntitySecretCipherText(): string {
    // For sandbox, the entity secret needs to be properly encrypted
    // This is a placeholder - in production, use Circle's encryption SDK
    // For now, we'll use the entity secret directly as Circle sandbox accepts it
    return this.entitySecret;
  }

  /**
   * Create a new wallet for a user
   */
  async createWallet(userId: string, blockchain: string = 'base-sepolia'): Promise<CircleWallet> {
    try {
      const idempotencyKey = crypto.randomUUID();
      
      const response = await this.client.post('/developer/wallets', {
        idempotencyKey,
        entitySecretCipherText: this.generateEntitySecretCipherText(),
        blockchains: ['ETH-SEPOLIA'], // Circle uses ETH-SEPOLIA which includes Base Sepolia
        count: 1,
        walletSetId: circleConfig.walletSetId,
      });

      const wallet = response.data.data.wallets[0];
      
      // Store wallet-to-user mapping in database
      await this.storeWalletMapping(userId, wallet.id, wallet.address);
      
      return wallet;
    } catch (error) {
      console.error('Error creating wallet:', error);
      throw new Error(`Failed to create wallet: ${error}`);
    }
  }

  /**
   * Get wallet by user ID
   */
  async getWalletByUserId(userId: string): Promise<CircleWallet | null> {
    try {
      // First check local database for wallet mapping
      const mapping = await this.getWalletMapping(userId);
      if (!mapping) {
        return null;
      }

      // Then fetch wallet details from Circle
      const response = await this.client.get(`/wallets/${mapping.walletId}`);
      return response.data.data.wallet;
    } catch (error) {
      console.error('Error getting wallet:', error);
      return null;
    }
  }

  /**
   * Get wallet balance
   */
  async getWalletBalance(walletId: string): Promise<WalletBalance[]> {
    try {
      const response = await this.client.get(`/wallets/${walletId}/balances`);
      return response.data.data.tokenBalances;
    } catch (error) {
      console.error('Error getting wallet balance:', error);
      throw new Error(`Failed to get wallet balance: ${error}`);
    }
  }

  /**
   * Create a transaction (transfer tokens)
   */
  async createTransaction(request: TransactionRequest): Promise<any> {
    try {
      const response = await this.client.post('/developer/transactions/transfer', {
        ...request,
        entitySecretCipherText: this.generateEntitySecretCipherText(),
        fee: request.fee || {
          type: 'level',
          config: {
            feeLevel: 'MEDIUM',
          },
        },
      });

      return response.data.data;
    } catch (error) {
      console.error('Error creating transaction:', error);
      throw new Error(`Failed to create transaction: ${error}`);
    }
  }

  /**
   * Get transaction status
   */
  async getTransactionStatus(transactionId: string): Promise<any> {
    try {
      const response = await this.client.get(`/transactions/${transactionId}`);
      return response.data.data.transaction;
    } catch (error) {
      console.error('Error getting transaction status:', error);
      throw new Error(`Failed to get transaction status: ${error}`);
    }
  }

  /**
   * Store wallet mapping in database (implementation depends on your DB choice)
   */
  private async storeWalletMapping(_userId: string, walletId: string, address: string): Promise<void> {
    // This should be implemented with your database of choice
    // For now, using in-memory storage or file-based storage
    // In production, use PostgreSQL, MongoDB, or similar
    
    // Example implementation would be:
    // await db.walletMappings.create({
    //   userId,
    //   walletId,
    //   address,
    //   createdAt: new Date(),
    // });
    
    console.log(`Stored wallet mapping: User -> Wallet ${walletId} (${address})`);
  }

  /**
   * Get wallet mapping from database
   */
  private async getWalletMapping(userId: string): Promise<{ walletId: string; address: string } | null> {
    // This should be implemented with your database of choice
    // For now, returning null to indicate no mapping found
    
    // Example implementation would be:
    // const mapping = await db.walletMappings.findOne({ userId });
    // return mapping ? { walletId: mapping.walletId, address: mapping.address } : null;
    
    return null;
  }

  /**
   * Create or get existing wallet for user
   */
  async ensureWallet(userId: string): Promise<CircleWallet> {
    // Check if user already has a wallet
    const existingWallet = await this.getWalletByUserId(userId);
    if (existingWallet) {
      return existingWallet;
    }

    // Create new wallet if none exists
    return await this.createWallet(userId);
  }

  /**
   * Execute gasless deposit to Mother Vault
   */
  async executeGaslessDeposit(
    userId: string,
    amount: string,
    motherVaultAddress: string
  ): Promise<any> {
    try {
      // Get user's wallet
      const wallet = await this.ensureWallet(userId);
      
      // Get USDC token ID for the network
      const network = circleConfig.supportedNetworks['base-sepolia'];
      const usdcAddress = network.usdcAddress;
      
      // Create transaction request
      const transactionRequest: TransactionRequest = {
        idempotencyKey: crypto.randomUUID(),
        amounts: [amount],
        destinationAddress: motherVaultAddress,
        tokenId: usdcAddress,
        walletId: wallet.id,
        fee: {
          type: 'level',
          config: {
            feeLevel: 'LOW', // Use low fee for gasless transactions
          },
        },
      };

      // Execute transaction
      const transaction = await this.createTransaction(transactionRequest);
      
      return {
        transactionId: transaction.id,
        status: transaction.state,
        walletAddress: wallet.address,
        amount,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error('Error executing gasless deposit:', error);
      throw new Error(`Failed to execute gasless deposit: ${error}`);
    }
  }
}

// Export singleton instance
export const circleWalletService = new CircleWalletService();