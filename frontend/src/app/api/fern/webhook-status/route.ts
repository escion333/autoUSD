import { NextRequest, NextResponse } from 'next/server';
import { webhookProcessor } from '@/lib/fern/webhookProcessor';

/**
 * GET /api/fern/webhook-status
 * 
 * Returns the current status of webhook processing and retry queue
 */
export async function GET(req: NextRequest) {
  try {
    // Get retry queue status from webhook processor
    const retryQueueStatus = webhookProcessor.getRetryQueueStatus();
    
    // Calculate health status
    const isHealthy = retryQueueStatus.failed < 5 && // Less than 5 permanent failures
                     retryQueueStatus.pending < 20;  // Less than 20 pending retries
    
    const status = {
      healthy: isHealthy,
      retryQueue: {
        total: retryQueueStatus.total,
        pending: retryQueueStatus.pending,
        failed: retryQueueStatus.failed,
        nextRetryIn: retryQueueStatus.nextRetryIn 
          ? `${retryQueueStatus.nextRetryIn} seconds` 
          : null,
      },
      timestamp: new Date().toISOString(),
      environment: process.env.NEXT_PUBLIC_FERN_ENVIRONMENT || 'sandbox',
    };
    
    console.log('📊 Webhook status check:', status);
    
    return NextResponse.json(status);
    
  } catch (error: any) {
    console.error('❌ Failed to get webhook status:', error);
    
    return NextResponse.json(
      { 
        error: 'Failed to retrieve webhook status',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      { status: 500 }
    );
  }
}

/**
 * POST /api/fern/webhook-status/retry-all
 * 
 * Triggers retry for all pending failed deposits
 */
export async function POST(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const action = searchParams.get('action');
    
    if (action !== 'retry-all') {
      return NextResponse.json(
        { error: 'Invalid action. Use ?action=retry-all' },
        { status: 400 }
      );
    }
    
    console.log('🔄 Triggering retry for all pending deposits...');
    
    // Trigger retry for all pending deposits
    await webhookProcessor.retryFailedDeposits();
    
    // Get updated status
    const retryQueueStatus = webhookProcessor.getRetryQueueStatus();
    
    return NextResponse.json({
      success: true,
      message: 'Retry triggered for all pending deposits',
      retryQueue: {
        total: retryQueueStatus.total,
        pending: retryQueueStatus.pending,
        failed: retryQueueStatus.failed,
      },
    });
    
  } catch (error: any) {
    console.error('❌ Failed to trigger retry:', error);
    
    return NextResponse.json(
      { 
        error: 'Failed to trigger retry',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      },
      { status: 500 }
    );
  }
}