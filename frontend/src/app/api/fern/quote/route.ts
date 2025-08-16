import { NextRequest, NextResponse } from 'next/server';
import { fernAPI } from '@/lib/fern/api';

export async function POST(req: NextRequest) {
  let requestBody: any;
  
  try {
    requestBody = await req.json();
    const { 
      customerId, 
      amount, 
      destinationAddress 
    } = requestBody;
    
    // Validate required fields
    if (!customerId || !amount || !destinationAddress) {
      return NextResponse.json(
        { error: 'Missing required fields: customerId, amount, destinationAddress' },
        { status: 400 }
      );
    }
    
    // Validate amount
    if (typeof amount !== 'number' || amount <= 0 || amount > 100) {
      return NextResponse.json(
        { error: 'Amount must be a number between $1 and $100' },
        { status: 400 }
      );
    }
    
    // Validate destination address format
    if (typeof destinationAddress !== 'string' || !destinationAddress.match(/^0x[a-fA-F0-9]{40}$/)) {
      return NextResponse.json(
        { error: 'Invalid destination address format' },
        { status: 400 }
      );
    }
    
    console.log('📝 Creating Fern quote:', {
      customerId,
      amount,
      destinationAddress: destinationAddress.substring(0, 10) + '...',
    });
    
    // Check if customer exists and is verified
    const customer = await fernAPI.getCustomer(customerId);
    if (!fernAPI.isCustomerVerified(customer)) {
      return NextResponse.json(
        { error: 'Customer must complete KYC verification before creating quotes' },
        { status: 403 }
      );
    }
    
    // Create quote with appropriate network
    const network = process.env.NODE_ENV === 'production' ? 'BASE' : 'BASE-SEPOLIA';
    const quote = await fernAPI.createQuote({
      customerId,
      fromCurrency: 'USD',
      toCurrency: 'USDC',
      fromAmount: amount,
      destinationAddress,
      network,
    });
    
    console.log('✅ Quote created successfully:', {
      quoteId: quote.quoteId,
      fromAmount: quote.fromAmount,
      toAmount: quote.toAmount,
      totalFee: quote.fees.totalFee,
    });
    
    return NextResponse.json({
      quoteId: quote.quoteId,
      fromAmount: quote.fromAmount,
      toAmount: quote.toAmount,
      exchangeRate: quote.exchangeRate,
      fees: quote.fees,
      expiresAt: quote.expiresAt,
      network,
    });
    
  } catch (error: any) {
    console.error('❌ Quote creation error:', {
      error: error.message,
      customerId: requestBody?.customerId,
      amount: requestBody?.amount,
    });
    
    // Handle specific Fern API errors
    if (error.message?.includes('Customer not found')) {
      return NextResponse.json(
        { error: 'Customer not found. Please create an account first.' },
        { status: 404 }
      );
    }
    
    if (error.message?.includes('KYC not verified')) {
      return NextResponse.json(
        { error: 'KYC verification required. Please complete identity verification.' },
        { status: 403 }
      );
    }
    
    if (error.message?.includes('Daily limit exceeded')) {
      return NextResponse.json(
        { error: 'Daily purchase limit exceeded. Please try again tomorrow.' },
        { status: 429 }
      );
    }
    
    // In development, return mock quote on API failures
    if (process.env.NODE_ENV === 'development') {
      console.log('🔧 Falling back to mock quote in development');
      
      try {
        const { amount, destinationAddress } = requestBody || {};
        if (!amount || !destinationAddress) {
          throw new Error('Missing required fields for mock quote');
        }
        const mockQuote = await fernAPI.mockCreateQuote(amount, destinationAddress);
        
        return NextResponse.json({
          quoteId: mockQuote.quoteId,
          fromAmount: mockQuote.fromAmount,
          toAmount: mockQuote.toAmount,
          exchangeRate: mockQuote.exchangeRate,
          fees: mockQuote.fees,
          expiresAt: mockQuote.expiresAt,
          network: 'BASE-SEPOLIA',
          isMock: true,
        });
      } catch (mockError) {
        console.error('Mock quote creation failed:', mockError);
      }
    }
    
    return NextResponse.json(
      { 
        error: error.message || 'Failed to create quote',
        code: 'QUOTE_CREATION_FAILED'
      },
      { status: 500 }
    );
  }
}

export async function GET(req: NextRequest) {
  try {
    const quoteId = req.nextUrl.searchParams.get('quoteId');
    
    if (!quoteId) {
      return NextResponse.json(
        { error: 'Quote ID is required' },
        { status: 400 }
      );
    }
    
    const quote = await fernAPI.getQuote(quoteId);
    
    return NextResponse.json({
      quoteId: quote.quoteId,
      fromAmount: quote.fromAmount,
      toAmount: quote.toAmount,
      exchangeRate: quote.exchangeRate,
      fees: quote.fees,
      expiresAt: quote.expiresAt,
      isExpired: new Date(quote.expiresAt) < new Date(),
    });
  } catch (error: any) {
    console.error('Quote fetch error:', error);
    
    return NextResponse.json(
      { error: error.message || 'Failed to fetch quote' },
      { status: 500 }
    );
  }
}