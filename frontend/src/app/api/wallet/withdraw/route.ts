import { NextRequest, NextResponse } from 'next/server';
import { DeveloperWalletService } from '@/lib/circle/developer-wallet';
import { getEnvironmentConfig } from '@/lib/config/environment';
import { createPublicClient, http, Address } from 'viem';
import { baseSepolia } from 'viem/chains';

const MOTHER_VAULT_ABI = [
  {
    "type": "function",
    "name": "withdraw",
    "inputs": [
      {"name": "amount", "type": "uint256", "internalType": "uint256"},
      {"name": "receiver", "type": "address", "internalType": "address"},
      {"name": "owner", "type": "address", "internalType": "address"}
    ],
    "outputs": [{"name": "shares", "type": "uint256", "internalType": "uint256"}],
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
    const { walletId, amount, vaultAddress } = requestBody;
    
    if (!walletId) {
      return NextResponse.json({ error: 'Wallet ID is required' }, { status: 400 });
    }
    
    if (!amount || parseFloat(amount) <= 0) {
      return NextResponse.json({ error: 'Valid amount is required' }, { status: 400 });
    }

    console.log('🏧 Processing gasless withdrawal:', { walletId, amount, vaultAddress });

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
    
    // Check vault share balance
    const shareBalance = await publicClient.readContract({
      address: vaultAddress as Address,
      abi: MOTHER_VAULT_ABI,
      functionName: 'balanceOf',
      args: [userAddress],
    });
    
    console.log('📊 Vault share balance:', shareBalance.toString());
    
    const withdrawAmount = BigInt(amount);
    
    if (shareBalance < withdrawAmount) {
      return NextResponse.json({ 
        error: 'Insufficient vault balance',
        required: withdrawAmount.toString(),
        available: shareBalance.toString(),
      }, { status: 400 });
    }

    try {
      // Execute withdrawal
      console.log('📝 Executing vault withdrawal...');
      
      const withdrawResult = await walletService.executeTransaction(walletId, {
        to: vaultAddress,
        data: walletService.encodeTransactionData({
          abi: MOTHER_VAULT_ABI,
          functionName: 'withdraw',
          args: [withdrawAmount, userAddress, userAddress],
        }),
        value: '0',
      });
      
      console.log('✅ Vault withdrawal transaction:', withdrawResult.transactionHash);
      
      const response = {
        success: true,
        transactionHash: withdrawResult.transactionHash,
        amount: withdrawAmount.toString(),
        userAddress,
        vaultAddress,
        timestamp: new Date().toISOString(),
      };
      
      console.log('✅ Gasless withdrawal completed:', {
        walletId,
        amount: withdrawAmount.toString(),
        txHash: withdrawResult.transactionHash,
      });
      
      return NextResponse.json(response);
      
    } catch (transactionError: any) {
      console.error('❌ Transaction execution failed:', transactionError);
      
      return NextResponse.json({
        error: 'Transaction failed',
        details: transactionError.message,
        walletId,
        amount: withdrawAmount.toString(),
      }, { status: 500 });
    }
    
  } catch (error: any) {
    console.error('❌ Withdrawal API error:', {
      error: error.message,
      body: requestBody || 'unknown',
    });
    
    return NextResponse.json(
      { 
        error: error?.message || 'Withdrawal failed',
        success: false,
      },
      { status: 500 }
    );
  }
}