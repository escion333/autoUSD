import { NextRequest, NextResponse } from 'next/server';
import { DeveloperWalletService } from '@/lib/circle/developer-wallet';

export async function POST(request: NextRequest) {
  try {
    const { email } = await request.json();
    
    if (!email) {
      return NextResponse.json({ error: 'Email is required' }, { status: 400 });
    }

    console.log('Creating developer-controlled wallet for:', email);

    // Initialize service and create wallet
    const walletService = DeveloperWalletService.getInstance();
    const wallet = await walletService.getOrCreateWallet(email);
    
    return NextResponse.json({
      success: true,
      wallet: {
        address: wallet.walletAddress,
        walletId: wallet.walletId,
        blockchain: wallet.blockchain,
      },
      message: 'Wallet created successfully',
    });
    
  } catch (error: any) {
    console.error('Create wallet error:', error);
    return NextResponse.json(
      { error: error?.message || 'Failed to create wallet' },
      { status: 500 }
    );
  }
}