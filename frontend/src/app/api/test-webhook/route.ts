import { NextRequest, NextResponse } from 'next/server';
import { createHmac } from 'crypto';

// Test endpoint to simulate Fern webhook events
export async function POST(req: NextRequest) {
  try {
    const { eventType, data } = await req.json();
    
    if (!eventType) {
      return NextResponse.json(
        { error: 'Event type is required' },
        { status: 400 }
      );
    }
    
    console.log('🧪 Testing webhook event:', eventType);
    
    // Create mock webhook payload
    const mockEvent = {
      eventId: `test_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      eventType,
      timestamp: new Date().toISOString(),
      data: data || getDefaultDataForEventType(eventType),
    };
    
    // Generate test signature (only in development)
    const body = JSON.stringify(mockEvent);
    let signature = '';
    
    if (process.env.NODE_ENV === 'development' && process.env.FERN_WEBHOOK_SECRET) {
      signature = createHmac('sha256', process.env.FERN_WEBHOOK_SECRET)
        .update(body)
        .digest('hex');
    }
    
    // Send webhook to our own endpoint
    const webhookUrl = new URL('/api/fern/webhook', req.url).toString();
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    
    if (signature) {
      headers['x-fern-signature'] = `sha256=${signature}`;
    }
    
    console.log('📤 Sending test webhook to:', webhookUrl);
    console.log('📦 Payload:', mockEvent);
    
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers,
      body,
    });
    
    const result = await response.json();
    
    console.log('📥 Webhook response:', {
      status: response.status,
      result,
    });
    
    return NextResponse.json({
      success: true,
      testEvent: mockEvent,
      webhookResponse: {
        status: response.status,
        body: result,
      },
    });
    
  } catch (error: any) {
    console.error('❌ Webhook test error:', error.message);
    
    return NextResponse.json(
      { 
        error: error.message || 'Failed to test webhook',
        success: false,
      },
      { status: 500 }
    );
  }
}

function getDefaultDataForEventType(eventType: string): any {
  const baseCustomerId = 'test_customer_123';
  const baseTransactionId = `test_tx_${Date.now()}`;
  const testWalletAddress = '0x742d35cc6644c0532925a3b8d0b74e7c297b0eae'; // Example address
  
  switch (eventType) {
    case 'customer.created':
      return {
        customerId: baseCustomerId,
        email: 'test@example.com',
        status: 'created',
      };
      
    case 'customer.verified':
      return {
        customerId: baseCustomerId,
        verificationLevel: 'basic',
        limits: {
          daily: 1000,
          monthly: 10000,
        },
      };
      
    case 'customer.rejected':
      return {
        customerId: baseCustomerId,
        reason: 'Test rejection for webhook testing',
      };
      
    case 'transaction.pending':
      return {
        transactionId: baseTransactionId,
        customerId: baseCustomerId,
        amount: 100,
        currency: 'USD',
        destinationAddress: testWalletAddress,
      };
      
    case 'transaction.processing':
      return {
        transactionId: baseTransactionId,
        customerId: baseCustomerId,
        amount: 100,
        currency: 'USD',
        destinationAddress: testWalletAddress,
        estimatedCompletion: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
      };
      
    case 'transaction.completed':
      return {
        transactionId: baseTransactionId,
        customerId: baseCustomerId,
        amount: 100,
        currency: 'USD',
        destinationAddress: testWalletAddress,
        transactionHash: `0x${Math.random().toString(16).substring(2, 66)}`,
        completedAt: new Date().toISOString(),
      };
      
    case 'transaction.failed':
      return {
        transactionId: baseTransactionId,
        customerId: baseCustomerId,
        amount: 100,
        currency: 'USD',
        destinationAddress: testWalletAddress,
        reason: 'Test failure for webhook testing',
        failedAt: new Date().toISOString(),
      };
      
    default:
      return {
        message: `Test data for event type: ${eventType}`,
        timestamp: new Date().toISOString(),
      };
  }
}

// GET endpoint to list available test events
export async function GET(req: NextRequest) {
  const availableEvents = [
    'customer.created',
    'customer.verified', 
    'customer.rejected',
    'transaction.pending',
    'transaction.processing',
    'transaction.completed',
    'transaction.failed',
  ];
  
  return NextResponse.json({
    success: true,
    availableEvents,
    usage: {
      method: 'POST',
      endpoint: '/api/test-webhook',
      payload: {
        eventType: 'transaction.completed',
        data: '(optional) custom event data',
      },
    },
    examples: [
      {
        name: 'Test successful transaction completion',
        payload: {
          eventType: 'transaction.completed',
          data: {
            transactionId: 'custom_tx_123',
            amount: 50,
            destinationAddress: '0x742d35cc6644c0532925a3b8d0b74e7c297b0eae',
          },
        },
      },
      {
        name: 'Test transaction failure',
        payload: {
          eventType: 'transaction.failed',
          data: {
            transactionId: 'custom_tx_456',
            amount: 25,
            reason: 'Insufficient funds',
          },
        },
      },
    ],
  });
}