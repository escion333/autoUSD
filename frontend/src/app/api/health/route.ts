import { NextResponse } from 'next/server';

// Simple health check endpoint for testing
export async function GET() {
  return NextResponse.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'autoUSD Frontend API',
    version: '1.0.0',
    endpoints: {
      fern: {
        webhook: '/api/fern/webhook',
        customer: '/api/fern/customer',
        quote: '/api/fern/quote',
        transaction: '/api/fern/transaction',
        'purchase-status': '/api/fern/purchase-status',
        'retry-auto-deposit': '/api/fern/retry-auto-deposit',
      },
      wallet: {
        balance: '/api/wallet/balance',
        mapping: '/api/wallet/mapping',
      },
      testing: {
        'test-webhook': '/api/test-webhook',
        health: '/api/health',
      },
    },
  });
}