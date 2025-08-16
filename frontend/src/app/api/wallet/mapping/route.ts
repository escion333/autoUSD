import { NextRequest, NextResponse } from 'next/server';
import { DeveloperWalletService } from '@/lib/circle/developer-wallet';

// Create or update wallet mapping
export async function POST(req: NextRequest) {
  try {
    const { email, walletId, walletAddress } = await req.json();
    
    if (!email || !walletAddress) {
      return NextResponse.json(
        { error: 'Email and wallet address are required' },
        { status: 400 }
      );
    }
    
    console.log('💾 Creating wallet mapping:', { email, walletId, walletAddress });
    
    const walletService = DeveloperWalletService.getInstance();
    
    // If walletId is not provided, try to find it by address
    let actualWalletId = walletId;
    if (!actualWalletId) {
      actualWalletId = await walletService.getWalletIdByAddress(walletAddress);
      
      if (!actualWalletId) {
        return NextResponse.json(
          { error: 'Could not find wallet ID for the provided address' },
          { status: 404 }
        );
      }
    }
    
    // Store the mapping
    await walletService.storeWalletMapping(email, actualWalletId, walletAddress);
    
    return NextResponse.json({
      success: true,
      mapping: {
        email,
        walletId: actualWalletId,
        walletAddress,
      },
    });
    
  } catch (error: any) {
    console.error('❌ Failed to create wallet mapping:', error.message);
    
    return NextResponse.json(
      { 
        error: error.message || 'Failed to create wallet mapping',
        success: false,
      },
      { status: 500 }
    );
  }
}

// Get wallet mapping by email or address
export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const email = searchParams.get('email');
    const address = searchParams.get('address');
    
    if (!email && !address) {
      return NextResponse.json(
        { error: 'Either email or address parameter is required' },
        { status: 400 }
      );
    }
    
    const walletService = DeveloperWalletService.getInstance();
    
    if (email) {
      console.log('🔍 Looking up wallet by email:', email);
      
      // Get wallet by email
      const wallet = await walletService.getOrCreateWallet(email);
      
      return NextResponse.json({
        success: true,
        mapping: {
          email: wallet.email,
          walletId: wallet.walletId,
          walletAddress: wallet.walletAddress,
          blockchain: wallet.blockchain,
        },
      });
    }
    
    if (address) {
      console.log('🔍 Looking up wallet by address:', address);
      
      // Get wallet by address
      const wallet = await walletService.findWalletByAddress(address);
      
      if (!wallet) {
        return NextResponse.json(
          { error: 'No wallet mapping found for the provided address' },
          { status: 404 }
        );
      }
      
      return NextResponse.json({
        success: true,
        mapping: {
          email: wallet.email,
          walletId: wallet.walletId,
          walletAddress: wallet.walletAddress,
          blockchain: wallet.blockchain,
        },
      });
    }
    
  } catch (error: any) {
    console.error('❌ Failed to get wallet mapping:', error.message);
    
    return NextResponse.json(
      { 
        error: error.message || 'Failed to get wallet mapping',
        success: false,
      },
      { status: 500 }
    );
  }
}

// List all wallet mappings (development only)
export async function PATCH(req: NextRequest) {
  if (process.env.NODE_ENV !== 'development') {
    return NextResponse.json(
      { error: 'This endpoint is only available in development mode' },
      { status: 403 }
    );
  }
  
  try {
    const walletService = DeveloperWalletService.getInstance();
    
    // Get all mappings from the in-memory cache
    const mappings: any[] = [];
    
    // Access the private userWallets map via reflection (development only)
    const userWallets = (walletService as any).userWallets;
    
    if (userWallets && userWallets instanceof Map) {
      for (const [email, wallet] of userWallets.entries()) {
        mappings.push({
          email,
          walletId: wallet.walletId,
          walletAddress: wallet.walletAddress,
          blockchain: wallet.blockchain,
          createdAt: wallet.createdAt,
        });
      }
    }
    
    return NextResponse.json({
      success: true,
      mappings,
      count: mappings.length,
    });
    
  } catch (error: any) {
    console.error('❌ Failed to list wallet mappings:', error.message);
    
    return NextResponse.json(
      { 
        error: error.message || 'Failed to list wallet mappings',
        success: false,
      },
      { status: 500 }
    );
  }
}

// Seed test data for development
export async function PUT(req: NextRequest) {
  if (process.env.NODE_ENV !== 'development') {
    return NextResponse.json(
      { error: 'This endpoint is only available in development mode' },
      { status: 403 }
    );
  }
  
  try {
    console.log('🌱 Seeding test wallet mappings...');
    
    const walletService = DeveloperWalletService.getInstance();
    
    // Create test mappings
    const testMappings = [
      {
        email: 'test@example.com',
        walletAddress: '0x742d35cc6644c0532925a3b8d0b74e7c297b0eae',
        walletId: 'test_wallet_1',
      },
      {
        email: 'alice@example.com', 
        walletAddress: '0x123456789abcdef0123456789abcdef012345678',
        walletId: 'test_wallet_2',
      },
      {
        email: 'bob@example.com',
        walletAddress: '0xabcdef0123456789abcdef0123456789abcdef01',
        walletId: 'test_wallet_3',
      },
    ];
    
    for (const mapping of testMappings) {
      await walletService.storeWalletMapping(
        mapping.email, 
        mapping.walletId, 
        mapping.walletAddress
      );
    }
    
    console.log('✅ Seeded test wallet mappings');
    
    return NextResponse.json({
      success: true,
      message: 'Test wallet mappings seeded successfully',
      seededMappings: testMappings,
    });
    
  } catch (error: any) {
    console.error('❌ Failed to seed test mappings:', error.message);
    
    return NextResponse.json(
      { 
        error: error.message || 'Failed to seed test mappings',
        success: false,
      },
      { status: 500 }
    );
  }
}