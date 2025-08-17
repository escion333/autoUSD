/**
 * Circle Paymaster Service
 * Handles gas sponsorship for Smart Contract Accounts
 */

import axios, { AxiosInstance } from 'axios';
import { ethers } from 'ethers';
import { circleConfig } from './config';

export interface PaymasterRequest {
  userOperation: {
    sender: string;
    nonce: string;
    initCode: string;
    callData: string;
    callGasLimit: string;
    verificationGasLimit: string;
    preVerificationGas: string;
    maxFeePerGas: string;
    maxPriorityFeePerGas: string;
    paymasterAndData: string;
    signature: string;
  };
  entryPoint: string;
  chainId: number;
}

export interface PaymasterResponse {
  paymasterAndData: string;
  verificationGasLimit: string;
  preVerificationGas: string;
  callGasLimit: string;
}

export interface GasEstimate {
  maxFeePerGas: string;
  maxPriorityFeePerGas: string;
  verificationGasLimit: string;
  preVerificationGas: string;
  callGasLimit: string;
}

export class CirclePaymasterService {
  private client: AxiosInstance;
  private provider: ethers.Provider;

  constructor() {
    this.client = axios.create({
      baseURL: circleConfig.paymasterUrl,
      headers: {
        'Authorization': `Bearer ${circleConfig.paymasterApiKey}`,
        'Content-Type': 'application/json',
      },
    });

    this.provider = new ethers.JsonRpcProvider(circleConfig.rpcUrl);
  }

  /**
   * Sponsor a user operation with gas
   */
  async sponsorUserOperation(
    userOp: PaymasterRequest['userOperation'],
    entryPoint: string = circleConfig.entryPointAddress
  ): Promise<PaymasterResponse> {
    try {
      const request: PaymasterRequest = {
        userOperation: userOp,
        entryPoint,
        chainId: circleConfig.chainId,
      };

      const response = await this.client.post('/sponsor', request);
      return response.data;
    } catch (error) {
      console.error('Error sponsoring user operation:', error);
      throw new Error(`Failed to sponsor user operation: ${error}`);
    }
  }

  /**
   * Estimate gas for a user operation
   */
  async estimateGas(
    from: string,
    to: string,
    data: string,
    value: string = '0x0'
  ): Promise<GasEstimate> {
    try {
      // Get current gas prices
      const feeData = await this.provider.getFeeData();
      
      // Estimate gas limit
      const gasLimit = await this.provider.estimateGas({
        from,
        to,
        data,
        value,
      });

      // Calculate gas components for user operation
      const verificationGasLimit = BigInt(100000); // Base verification gas
      const preVerificationGas = BigInt(21000); // Base transaction gas
      const callGasLimit = gasLimit + BigInt(50000); // Add buffer

      return {
        maxFeePerGas: (feeData.maxFeePerGas || BigInt(0)).toString(),
        maxPriorityFeePerGas: (feeData.maxPriorityFeePerGas || BigInt(0)).toString(),
        verificationGasLimit: verificationGasLimit.toString(),
        preVerificationGas: preVerificationGas.toString(),
        callGasLimit: callGasLimit.toString(),
      };
    } catch (error) {
      console.error('Error estimating gas:', error);
      throw new Error(`Failed to estimate gas: ${error}`);
    }
  }

  /**
   * Build a sponsored transaction for deposit
   */
  async buildSponsoredDeposit(
    walletAddress: string,
    motherVaultAddress: string,
    amount: string
  ): Promise<any> {
    try {
      // Get USDC contract interface
      const usdcInterface = new ethers.Interface([
        'function approve(address spender, uint256 amount) returns (bool)',
        'function transfer(address to, uint256 amount) returns (bool)',
      ]);

      // Get Mother Vault interface
      const vaultInterface = new ethers.Interface([
        'function deposit(uint256 assets, address receiver) returns (uint256)',
      ]);

      // Build batched call data for approve and deposit
      // Note: This needs to be executed through a multicall or batch transaction
      const approveData = usdcInterface.encodeFunctionData('approve', [
        motherVaultAddress,
        amount,
      ]);

      const depositData = vaultInterface.encodeFunctionData('deposit', [
        amount,
        walletAddress,
      ]);

      // For now, we'll focus on the deposit call data
      // In production, use multicall to batch approve + deposit
      // or ensure approval is done separately first
      const network = circleConfig.supportedNetworks['base-sepolia'];
      const gasEstimate = await this.estimateGas(
        walletAddress,
        motherVaultAddress,
        depositData
      );

      // Build user operation
      const userOperation = {
        sender: walletAddress,
        nonce: '0x0', // Will be fetched from entry point
        initCode: '0x',
        callData: depositData,
        callGasLimit: gasEstimate.callGasLimit,
        verificationGasLimit: gasEstimate.verificationGasLimit,
        preVerificationGas: gasEstimate.preVerificationGas,
        maxFeePerGas: gasEstimate.maxFeePerGas,
        maxPriorityFeePerGas: gasEstimate.maxPriorityFeePerGas,
        paymasterAndData: '0x', // Will be filled by paymaster
        signature: '0x', // Will be signed by wallet
      };

      // Get paymaster sponsorship
      const sponsorship = await this.sponsorUserOperation(userOperation);

      return {
        userOperation: {
          ...userOperation,
          paymasterAndData: sponsorship.paymasterAndData,
        },
        gasEstimate,
        sponsored: true,
      };
    } catch (error) {
      console.error('Error building sponsored deposit:', error);
      throw new Error(`Failed to build sponsored deposit: ${error}`);
    }
  }

  /**
   * Monitor gas sponsorship usage
   */
  async getGasUsageStats(walletAddress: string): Promise<any> {
    try {
      const response = await this.client.get(`/stats/${walletAddress}`);
      return response.data;
    } catch (error) {
      console.error('Error getting gas usage stats:', error);
      // Return default stats if not available
      return {
        totalSponsored: '0',
        totalTransactions: 0,
        lastSponsoredAt: null,
      };
    }
  }

  /**
   * Check if an operation is eligible for sponsorship
   */
  async checkEligibility(
    walletAddress: string,
    operation: string
  ): Promise<boolean> {
    try {
      // Define sponsorship rules
      const eligibleOperations = [
        'deposit',
        'withdraw',
        'claim',
        'approve',
      ];

      // Check if operation is eligible
      if (!eligibleOperations.includes(operation)) {
        return false;
      }

      // Check wallet limits (example: max 10 sponsored tx per day)
      const stats = await this.getGasUsageStats(walletAddress);
      const today = new Date().toISOString().split('T')[0];
      const lastSponsored = stats.lastSponsoredAt?.split('T')[0];

      if (lastSponsored === today && stats.totalTransactions >= 10) {
        return false;
      }

      return true;
    } catch (error) {
      console.error('Error checking eligibility:', error);
      return false;
    }
  }

  /**
   * Calculate estimated gas cost in USD
   */
  async estimateGasCostUSD(gasEstimate: GasEstimate): Promise<string> {
    try {
      // Calculate total gas units
      const totalGas = 
        BigInt(gasEstimate.callGasLimit) +
        BigInt(gasEstimate.verificationGasLimit) +
        BigInt(gasEstimate.preVerificationGas);

      // Calculate cost in wei
      const costWei = totalGas * BigInt(gasEstimate.maxFeePerGas);

      // Convert to ETH
      const costEth = ethers.formatEther(costWei);

      // For demo, assume 1 ETH = $2000 (should fetch real price in production)
      const ethPrice = 2000;
      const costUSD = parseFloat(costEth) * ethPrice;

      return costUSD.toFixed(4);
    } catch (error) {
      console.error('Error calculating gas cost:', error);
      return '0';
    }
  }
}

// Export singleton instance
export const circlePaymasterService = new CirclePaymasterService();