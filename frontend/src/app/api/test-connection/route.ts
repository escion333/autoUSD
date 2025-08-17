// Test endpoint to verify frontend-backend connection
import { NextResponse } from 'next/server';

export async function GET() {
  try {
    // Test connection to backend
    const response = await fetch('http://localhost:3002/health', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error(`Backend health check failed: ${response.status}`);
    }

    const backendHealth = await response.json();

    return NextResponse.json({
      status: 'healthy',
      frontend: 'running',
      backend: backendHealth,
      integration: 'connected',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Backend connection test failed:', error);
    return NextResponse.json({
      status: 'error',
      frontend: 'running',
      backend: 'disconnected',
      error: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString(),
    }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    
    // Test user creation flow
    const response = await fetch('http://localhost:3002/api/circle/wallets/create', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: body.email || 'demo@autousd.com',
        userId: body.userId || 'demo-user-test',
      }),
    });

    const result = await response.json();

    return NextResponse.json({
      status: 'success',
      message: 'Frontend-backend integration working',
      walletCreation: result,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Frontend-backend integration test failed:', error);
    return NextResponse.json({
      status: 'error',
      error: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString(),
    }, { status: 500 });
  }
}