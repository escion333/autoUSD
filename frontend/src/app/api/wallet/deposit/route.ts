import { NextRequest, NextResponse } from 'next/server';
import { DeveloperWalletService } from '@/lib/circle/developer-wallet';
import { getEnvironmentConfig } from '@/lib/config/environment';
import { createPublicClient, http, Address, parseUnits } from 'viem';
import { baseSepolia } from 'viem/chains';

const MOTHER_VAULT_ABI = [
  {
    "type": "function",
    "name": "deposit",
    "inputs": [
      {"name": "amount", "type": "uint256", "internalType": "uint256"},
      {"name": "receiver", "type": "address", "internalType": "address"}
    ],
    "outputs": [{"name": "shares", "type": "uint256", "internalType": "uint256"}],
    "stateMutability": "nonpayable"
  }
] as const;

const USDC_ABI = [
  {
    "type": "function", 
    "name": "approve",
    "inputs": [
      {"name": "spender", "type": "address", "internalType": "address"},
      {"name": "amount", "type": "uint256", "internalType": "uint256"}
    ],
    "outputs": [{"name": "", "type": "bool", "internalType": "bool"}],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "balanceOf", 
    "inputs": [{"name": "account", "type": "address", "internalType": "address"}],
    "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
    "stateMutability": "view"
  }
] as const;

export async function POST(request: NextRequest) {
  let requestBody: any;
  
  try {
    requestBody = await request.json();
    const { walletId, amount, vaultAddress, usdcAddress } = requestBody;
    
    if (!walletId) {
      return NextResponse.json({ error: 'Wallet ID is required' }, { status: 400 });
    }
    
    if (!amount || parseFloat(amount) <= 0) {
      return NextResponse.json({ error: 'Valid amount is required' }, { status: 400 });
    }

    console.log('💰 Processing gasless deposit:', { walletId, amount, vaultAddress, usdcAddress });

    const config = getEnvironmentConfig();
    const walletService = DeveloperWalletService.getInstance();
    
    // Get wallet details
    const walletDetails = await walletService.getWallet(walletId);
    const userAddress = walletDetails.address as Address;
    
    console.log('👤 User wallet address:', userAddress);
    
    // Create public client for reading blockchain state
    const publicClient = createPublicClient({
      chain: baseSepolia,
      transport: http(config.networks.base.rpcUrl),
    });
    
    // Check USDC balance
    const usdcBalance = await publicClient.readContract({
      address: usdcAddress as Address,
      abi: USDC_ABI,
      functionName: 'balanceOf',
      args: [userAddress],
    });
    
    console.log('💵 USDC balance:', usdcBalance.toString());
    
    const depositAmount = BigInt(amount);
    
    if (usdcBalance < depositAmount) {
      return NextResponse.json({ 
        error: 'Insufficient USDC balance',
        required: depositAmount.toString(),
        available: usdcBalance.toString(),
      }, { status: 400 });
    }

    try {
      // Step 1: Approve USDC spending
      console.log('📝 Step 1: Approving USDC spending...');
      
      const approveResult = await walletService.executeTransaction(walletId, {
        to: usdcAddress,
        data: walletService.encodeTransactionData({
          abi: USDC_ABI,
          functionName: 'approve',
          args: [vaultAddress, depositAmount],
        }),
        value: '0',
      });
      
      console.log('✅ USDC approval transaction:', approveResult.transactionHash);
      
      // Wait for approval confirmation
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      // Step 2: Deposit to vault
      console.log('📝 Step 2: Executing vault deposit...');
      
      const depositResult = await walletService.executeTransaction(walletId, {
        to: vaultAddress,
        data: walletService.encodeTransactionData({
          abi: MOTHER_VAULT_ABI,
          functionName: 'deposit',
          args: [depositAmount, userAddress],
        }),
        value: '0',
      });
      
      console.log('✅ Vault deposit transaction:', depositResult.transactionHash);
      
      const response = {
        success: true,
        transactionHash: depositResult.transactionHash,
        approvalHash: approveResult.transactionHash,
        amount: depositAmount.toString(),
        userAddress,
        vaultAddress,
        timestamp: new Date().toISOString(),
      };
      
      console.log('✅ Gasless deposit completed:', {
        walletId,
        amount: depositAmount.toString(),
        txHash: depositResult.transactionHash,
      });
      
      return NextResponse.json(response);
      
    } catch (transactionError: any) {
      console.error('❌ Transaction execution failed:', transactionError);
      
      return NextResponse.json({
        error: 'Transaction failed',
        details: transactionError.message,
        walletId,
        amount: depositAmount.toString(),
      }, { status: 500 });
    }
    
  } catch (error: any) {
    console.error('❌ Deposit API error:', {
      error: error.message,
      body: requestBody || 'unknown',
    });
    
    return NextResponse.json(
      { 
        error: error?.message || 'Deposit failed',
        success: false,
      },
      { status: 500 }
    );
  }
}