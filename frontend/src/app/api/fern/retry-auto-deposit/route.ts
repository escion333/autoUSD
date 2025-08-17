import { NextRequest, NextResponse } from 'next/server';
import { webhookProcessor } from '@/lib/fern/webhookProcessor';
import { TransactionCompletedEvent } from '@/lib/fern/types';

// Manual retry endpoint for failed auto-deposits
export async function POST(req: NextRequest) {
  try {
    const { fernTransactionId, userEmail, amount, walletAddress } = await req.json();
    
    if (!fernTransactionId || !userEmail) {
      return NextResponse.json(
        { error: 'Transaction ID and user email are required' },
        { status: 400 }
      );
    }
    
    console.log('🔄 Manual retry requested for auto-deposit:', {
      fernTransactionId,
      userEmail,
      amount,
    });
    
    // Use the webhook processor to retry the deposit
    const retryEvent: TransactionCompletedEvent = {
      transactionId: fernTransactionId,
      amount: amount || 0,
      currency: 'USDC',
      destinationAddress: walletAddress || '',
      transactionHash: '', // Will be populated on success
    };
    
    const result = await webhookProcessor.processWebhook({
      eventId: `retry-${fernTransactionId}-${Date.now()}`,
      eventType: 'transaction.completed',
      timestamp: new Date().toISOString(),
      data: retryEvent,
    });
    
    if (result.success && result.result?.status === 'success') {
      return NextResponse.json({
        success: true,
        message: 'Auto-deposit retry succeeded',
        transactionHash: result.result.transactionHash,
        amount: result.result.amount,
        shares: result.result.shares,
      });
    } else if (result.result?.status === 'skipped') {
      return NextResponse.json({
        success: false,
        message: 'Deposit skipped due to cap limit',
        reason: result.result.reason,
        canRetryAgain: false,
      });
    } else {
      return NextResponse.json({
        success: false,
        message: result.error || 'Auto-deposit retry failed - please try manual deposit',
        canRetryAgain: true, // Allow manual retry unless explicitly blocked
        error: result.error,
        details: result.result,
      });
    }
    
  } catch (error: any) {
    console.error('❌ Auto-deposit retry error:', error.message);
    
    return NextResponse.json(
      { 
        error: error.message || 'Failed to retry auto-deposit',
        success: false,
      },
      { status: 500 }
    );
  }
}

// Get failed auto-deposit records for a user
export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const userEmail = searchParams.get('userEmail');
    
    if (!userEmail) {
      return NextResponse.json(
        { error: 'User email is required' },
        { status: 400 }
      );
    }
    
    console.log('📋 Fetching failed auto-deposits for:', userEmail);
    
    // TODO: In production, fetch from database:
    // const failedDeposits = await db.failedAutoDeposits.findMany({
    //   where: { 
    //     userEmail,
    //     canRetry: true,
    //     retryCount: { lt: 3 } // Max 3 retries
    //   },
    //   orderBy: { createdAt: 'desc' }
    // });
    
    // For development, return mock data
    if (process.env.NODE_ENV === 'development') {
      const mockFailedDeposits = [
        {
          id: '1',
          fernTransactionId: 'fern_tx_123',
          amount: 50.00,
          errorType: 'network_error',
          reason: 'Network timeout during deposit',
          canRetry: true,
          retryCount: 1,
          createdAt: new Date(Date.now() - 1000 * 60 * 30).toISOString(), // 30 minutes ago
        },
        {
          id: '2', 
          fernTransactionId: 'fern_tx_456',
          amount: 25.00,
          errorType: 'gas_estimation_failed',
          reason: 'Failed to estimate gas for transaction',
          canRetry: true,
          retryCount: 0,
          createdAt: new Date(Date.now() - 1000 * 60 * 60 * 2).toISOString(), // 2 hours ago
        }
      ];
      
      return NextResponse.json({
        success: true,
        failedDeposits: mockFailedDeposits,
        count: mockFailedDeposits.length,
      });
    }
    
    return NextResponse.json({
      success: true,
      failedDeposits: [],
      count: 0,
    });
    
  } catch (error: any) {
    console.error('❌ Failed to fetch auto-deposit records:', error.message);
    
    return NextResponse.json(
      { 
        error: error.message || 'Failed to fetch failed deposits',
        success: false,
      },
      { status: 500 }
    );
  }
}