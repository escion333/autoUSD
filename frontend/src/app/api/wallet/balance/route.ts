import { NextRequest, NextResponse } from 'next/server';
import { DeveloperWalletService } from '@/lib/circle/developer-wallet';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const walletId = searchParams.get('walletId');
    const currency = searchParams.get('currency') || 'USDC'; // Default to USDC
    
    if (!walletId) {
      return NextResponse.json({ error: 'Wallet ID is required' }, { status: 400 });
    }

    console.log('💰 Checking wallet balance:', { walletId, currency });

    const walletService = DeveloperWalletService.getInstance();
    const balances = await walletService.getWalletBalance(walletId);
    
    console.log('📊 Raw balances from Circle:', balances);
    
    // Format balances for frontend
    const formattedBalances = balances.map((balance: any) => ({
      token: balance.token?.symbol || 'Unknown',
      amount: parseFloat(balance.amount || '0'),
      decimals: balance.token?.decimals || 18,
      blockchain: balance.token?.blockchain,
      contractAddress: balance.token?.tokenAddress,
      isNative: !balance.token?.tokenAddress, // Native ETH/MATIC etc.
    }));
    
    // Find specific currency balance (USDC by default)
    const targetBalance = formattedBalances.find((b: any) => 
      b.token.toUpperCase() === currency.toUpperCase()
    );
    
    const response = {
      success: true,
      walletId,
      currency,
      balance: targetBalance?.amount || 0,
      balances: formattedBalances,
      
      // USDC-specific information
      usdc: {
        amount: formattedBalances.find((b: any) => b.token.toUpperCase() === 'USDC')?.amount || 0,
        blockchain: formattedBalances.find((b: any) => b.token.toUpperCase() === 'USDC')?.blockchain,
        contractAddress: formattedBalances.find((b: any) => b.token.toUpperCase() === 'USDC')?.contractAddress,
      },
      
      // Total USD value (assuming USDC = $1)
      totalUSDValue: formattedBalances.reduce((total: number, balance: any) => {
        if (balance.token.toUpperCase() === 'USDC') {
          return total + balance.amount;
        }
        return total;
      }, 0),
      
      timestamp: new Date().toISOString(),
    };
    
    console.log('✅ Formatted balance response:', {
      walletId,
      currency,
      balance: response.balance,
      usdcAmount: response.usdc.amount,
      totalTokens: formattedBalances.length,
    });
    
    return NextResponse.json(response);
    
  } catch (error: any) {
    console.error('❌ Get balance error:', {
      error: error.message,
      walletId: request.nextUrl.searchParams.get('walletId'),
    });
    
    return NextResponse.json(
      { 
        error: error?.message || 'Failed to get balance',
        success: false,
        walletId: request.nextUrl.searchParams.get('walletId'),
      },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  let requestBody: any;
  
  try {
    requestBody = await request.json();
    const { address, walletId, currency = 'USDC' } = requestBody;
    
    if (!address && !walletId) {
      return NextResponse.json({ 
        error: 'Either wallet address or wallet ID is required' 
      }, { status: 400 });
    }

    console.log('💰 Checking wallet balance via POST:', { address, walletId, currency });

    const walletService = DeveloperWalletService.getInstance();
    let balances;
    let actualWalletId = walletId;
    
    if (walletId) {
      // Use wallet ID directly
      balances = await walletService.getWalletBalance(walletId);
    } else {
      // Find wallet by address and get balance
      console.log('🔍 Looking up wallet by address:', address);
      
      try {
        const actualWalletId = await walletService.getWalletIdByAddress(address);
        
        if (!actualWalletId) {
          return NextResponse.json({
            error: 'No wallet found for the provided address',
            success: false,
            address,
          }, { status: 404 });
        }
        
        console.log('✅ Found wallet ID for address:', { address, walletId: actualWalletId });
        balances = await walletService.getWalletBalance(actualWalletId);
        
      } catch (error: any) {
        console.error('Failed to lookup wallet by address:', error);
        return NextResponse.json({
          error: `Failed to lookup wallet: ${error.message}`,
          success: false,
          address,
        }, { status: 500 });
      }
    }
    
    console.log('📊 Raw balances from Circle:', balances);
    
    // Format balances for frontend
    const formattedBalances = balances.map((balance: any) => ({
      token: balance.token?.symbol || 'Unknown',
      amount: parseFloat(balance.amount || '0'),
      decimals: balance.token?.decimals || 18,
      blockchain: balance.token?.blockchain,
      contractAddress: balance.token?.tokenAddress,
      isNative: !balance.token?.tokenAddress,
    }));
    
    // Find specific currency balance
    const targetBalance = formattedBalances.find((b: any) => 
      b.token.toUpperCase() === currency.toUpperCase()
    );
    
    // Find USDC specifically
    const usdcBalance = formattedBalances.find((b: any) => 
      b.token.toUpperCase() === 'USDC'
    );
    
    const response = {
      success: true,
      walletId: actualWalletId,
      address,
      currency,
      balance: targetBalance?.amount || 0,
      balances: formattedBalances,
      
      // USDC-specific information
      usdc: {
        amount: usdcBalance?.amount || 0,
        blockchain: usdcBalance?.blockchain,
        contractAddress: usdcBalance?.contractAddress,
        hasBalance: (usdcBalance?.amount || 0) > 0,
      },
      
      // Detection flags for webhook/auto-deposit
      hasIncomingUSDC: (usdcBalance?.amount || 0) > 0,
      isDepositReady: (usdcBalance?.amount || 0) >= 1, // Minimum $1 for deposit
      
      // Total USD value
      totalUSDValue: formattedBalances.reduce((total: number, balance: any) => {
        if (balance.token.toUpperCase() === 'USDC') {
          return total + balance.amount;
        }
        return total;
      }, 0),
      
      timestamp: new Date().toISOString(),
    };
    
    console.log('✅ Balance check complete:', {
      walletId: actualWalletId,
      address,
      currency,
      balance: response.balance,
      usdcAmount: response.usdc.amount,
      hasIncomingUSDC: response.hasIncomingUSDC,
      isDepositReady: response.isDepositReady,
    });
    
    return NextResponse.json(response);
    
  } catch (error: any) {
    console.error('❌ POST balance check error:', {
      error: error.message,
      body: requestBody || 'unknown',
    });
    
    return NextResponse.json(
      { 
        error: error?.message || 'Failed to check balance',
        success: false,
      },
      { status: 500 }
    );
  }
}