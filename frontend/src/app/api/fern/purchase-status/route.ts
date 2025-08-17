import { NextRequest, NextResponse } from 'next/server';
import { fernAPI } from '@/lib/fern/api';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET(req: NextRequest) {
  try {
    const transactionId = req.nextUrl.searchParams.get('transactionId');
    const customerId = req.nextUrl.searchParams.get('customerId');
    
    if (!transactionId && !customerId) {
      return NextResponse.json(
        { error: 'Either transactionId or customerId is required' },
        { status: 400 }
      );
    }
    
    let transactions: any[] = [];
    
    if (transactionId) {
      // Get single transaction status
      console.log('🔍 Checking transaction status:', transactionId);
      
      const transaction = await fernAPI.getTransaction(transactionId);
      transactions = [transaction];
    } else if (customerId) {
      // Get all transactions for customer
      console.log('🔍 Getting transactions for customer:', customerId);
      
      transactions = await fernAPI.getTransactionsByCustomer(customerId);
    }
    
    // Format transaction data with enhanced status info
    const formattedTransactions = transactions.map(tx => ({
      transactionId: tx.transactionId,
      status: tx.status,
      fromAmount: tx.fromAmount,
      toAmount: tx.toAmount,
      fees: tx.fees,
      destinationAddress: tx.destinationAddress,
      transactionHash: tx.transactionHash,
      createdAt: tx.createdAt,
      completedAt: tx.completedAt,
      
      // Enhanced status information
      isCompleted: tx.status === 'completed',
      isFailed: tx.status === 'failed',
      isPending: ['pending', 'processing'].includes(tx.status),
      
      // Estimated completion time based on status
      estimatedCompletionTime: getEstimatedCompletionTime(tx),
      
      // Next steps for user
      nextSteps: getNextSteps(tx),
      
      // Payment instructions if still needed
      paymentInstructions: tx.paymentInstructions ? fernAPI.formatPaymentInstructions(tx) : null,
    }));
    
    if (transactionId) {
      // Return single transaction
      const transaction = formattedTransactions[0];
      
      console.log('📊 Transaction status:', {
        transactionId: transaction.transactionId,
        status: transaction.status,
        isCompleted: transaction.isCompleted,
      });
      
      return NextResponse.json(transaction);
    } else {
      // Return all transactions for customer
      console.log('📊 Customer transactions:', {
        customerId,
        count: formattedTransactions.length,
        statuses: formattedTransactions.map(tx => tx.status),
      });
      
      return NextResponse.json({
        customerId,
        transactions: formattedTransactions,
        summary: {
          total: formattedTransactions.length,
          completed: formattedTransactions.filter(tx => tx.isCompleted).length,
          pending: formattedTransactions.filter(tx => tx.isPending).length,
          failed: formattedTransactions.filter(tx => tx.isFailed).length,
        }
      });
    }
    
  } catch (error: any) {
    console.error('❌ Purchase status check error:', {
      error: error.message,
      transactionId: req.nextUrl.searchParams.get('transactionId'),
      customerId: req.nextUrl.searchParams.get('customerId'),
    });
    
    // In development, return mock status
    if (process.env.NODE_ENV === 'development') {
      const transactionId = req.nextUrl.searchParams.get('transactionId');
      
      if (transactionId) {
        // Return mock transaction status
        const mockStatus = getMockTransactionStatus(transactionId);
        return NextResponse.json(mockStatus);
      } else {
        // Return mock customer transactions
        return NextResponse.json({
          customerId: req.nextUrl.searchParams.get('customerId'),
          transactions: [getMockTransactionStatus('mock-txn-1')],
          summary: { total: 1, completed: 1, pending: 0, failed: 0 }
        });
      }
    }
    
    return NextResponse.json(
      { 
        error: error.message || 'Failed to check purchase status',
        code: 'STATUS_CHECK_FAILED'
      },
      { status: 500 }
    );
  }
}

// Helper functions
function getEstimatedCompletionTime(transaction: any): string | null {
  switch (transaction.status) {
    case 'pending':
      return 'Usually completes within 24 hours';
    case 'processing':
      return 'Usually completes within 2-4 hours';
    case 'completed':
    case 'failed':
      return null;
    default:
      return 'Unknown';
  }
}

function getNextSteps(transaction: any): string[] {
  switch (transaction.status) {
    case 'pending':
      return [
        'Complete payment using the provided instructions',
        'Wait for payment confirmation (up to 24 hours)',
        'USDC will be automatically deposited to your vault'
      ];
    case 'processing':
      return [
        'Payment received and being processed',
        'USDC will be sent to your wallet soon',
        'Auto-deposit will trigger once USDC arrives'
      ];
    case 'completed':
      return [
        'Purchase completed successfully',
        'USDC has been deposited to your vault',
        'You can view your position in the dashboard'
      ];
    case 'failed':
      return [
        'Purchase failed - please contact support',
        'Refund will be processed if payment was received',
        'You can try creating a new purchase'
      ];
    default:
      return ['Status unknown - please contact support'];
  }
}

function getMockTransactionStatus(transactionId: string): any {
  // Simulate different statuses based on transaction ID for testing
  const statusIndex = transactionId.length % 4;
  const statuses = ['pending', 'processing', 'completed', 'failed'];
  const status = statuses[statusIndex];
  
  const baseTransaction = {
    transactionId,
    status,
    fromAmount: 100,
    toAmount: 99.5,
    fees: {
      fernFee: 0.5,
      networkFee: 0,
      totalFee: 0.5,
    },
    destinationAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
    transactionHash: status === 'completed' ? `0x${Math.random().toString(16).substring(2, 66)}` : null,
    createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(), // 2 hours ago
    completedAt: status === 'completed' ? new Date().toISOString() : null,
  };
  
  return {
    ...baseTransaction,
    isCompleted: status === 'completed',
    isFailed: status === 'failed',
    isPending: ['pending', 'processing'].includes(status),
    estimatedCompletionTime: getEstimatedCompletionTime(baseTransaction),
    nextSteps: getNextSteps(baseTransaction),
    paymentInstructions: status === 'pending' ? 'Mock payment instructions...' : null,
  };
}