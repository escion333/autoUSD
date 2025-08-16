import { NextRequest, NextResponse } from 'next/server';
import { fernAPI } from '@/lib/fern/api';

export async function POST(req: NextRequest) {
  try {
    const { 
      customerId, 
      quoteId,
      paymentMethod = 'wire'
    } = await req.json();
    
    if (!customerId || !quoteId) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }
    
    // Create transaction
    const transaction = await fernAPI.createTransaction({
      customerId,
      quoteId,
      paymentMethod,
    });
    
    return NextResponse.json({
      transactionId: transaction.transactionId,
      status: transaction.status,
      fromAmount: transaction.fromAmount,
      toAmount: transaction.toAmount,
      fees: transaction.fees,
      paymentInstructions: fernAPI.formatPaymentInstructions(transaction),
      rawInstructions: transaction.paymentInstructions,
    });
  } catch (error: any) {
    console.error('Transaction creation error:', error);
    
    // In development, return mock transaction
    if (process.env.NODE_ENV === 'development') {
      const { quoteId } = await req.json();
      const mockTransaction = await fernAPI.mockCreateTransaction(quoteId);
      
      return NextResponse.json({
        transactionId: mockTransaction.transactionId,
        status: mockTransaction.status,
        fromAmount: mockTransaction.fromAmount,
        toAmount: mockTransaction.toAmount,
        fees: mockTransaction.fees,
        paymentInstructions: fernAPI.formatPaymentInstructions(mockTransaction),
        rawInstructions: mockTransaction.paymentInstructions,
      });
    }
    
    return NextResponse.json(
      { error: error.message || 'Failed to create transaction' },
      { status: 500 }
    );
  }
}

export async function GET(req: NextRequest) {
  try {
    const transactionId = req.nextUrl.searchParams.get('transactionId');
    const customerId = req.nextUrl.searchParams.get('customerId');
    
    if (transactionId) {
      // Get single transaction
      const transaction = await fernAPI.getTransaction(transactionId);
      
      return NextResponse.json({
        transactionId: transaction.transactionId,
        status: transaction.status,
        fromAmount: transaction.fromAmount,
        toAmount: transaction.toAmount,
        fees: transaction.fees,
        paymentInstructions: fernAPI.formatPaymentInstructions(transaction),
        createdAt: transaction.createdAt,
        completedAt: transaction.completedAt,
      });
    } else if (customerId) {
      // Get all transactions for customer
      const transactions = await fernAPI.getTransactionsByCustomer(customerId);
      
      return NextResponse.json({
        transactions: transactions.map(t => ({
          transactionId: t.transactionId,
          status: t.status,
          fromAmount: t.fromAmount,
          toAmount: t.toAmount,
          fees: t.fees,
          createdAt: t.createdAt,
          completedAt: t.completedAt,
        })),
      });
    } else {
      return NextResponse.json(
        { error: 'Transaction ID or Customer ID is required' },
        { status: 400 }
      );
    }
  } catch (error: any) {
    console.error('Transaction fetch error:', error);
    
    // In development, return mock data
    if (process.env.NODE_ENV === 'development') {
      return NextResponse.json({
        transactionId: req.nextUrl.searchParams.get('transactionId') || 'mock-txn',
        status: 'completed',
        fromAmount: 100,
        toAmount: 99.5,
        fees: {
          fernFee: 0.5,
          networkFee: 0,
          totalFee: 0.5,
        },
        paymentInstructions: 'Mock payment instructions',
        createdAt: new Date().toISOString(),
        completedAt: new Date().toISOString(),
      });
    }
    
    return NextResponse.json(
      { error: error.message || 'Failed to fetch transaction' },
      { status: 500 }
    );
  }
}