import { NextRequest, NextResponse } from 'next/server';
import { randomUUID } from 'crypto';

// Extend global to include our OTP sessions
declare global {
  var otpSessions: Map<string, any> | undefined;
}

export async function POST(request: NextRequest) {
  try {
    const { challengeId, otp } = await request.json();
    
    if (!challengeId || !otp) {
      return NextResponse.json(
        { error: 'Challenge ID and OTP are required' },
        { status: 400 }
      );
    }

    console.log('Verifying OTP for challenge:', challengeId);

    // Check OTP session
    const otpSession = global.otpSessions?.get(challengeId);
    
    if (!otpSession) {
      return NextResponse.json(
        { error: 'Invalid or expired challenge' },
        { status: 400 }
      );
    }
    
    if (Date.now() > otpSession.expiresAt) {
      global.otpSessions?.delete(challengeId);
      return NextResponse.json(
        { error: 'Challenge has expired' },
        { status: 400 }
      );
    }
    
    if (otp !== otpSession.otp) {
      return NextResponse.json(
        { error: 'Invalid OTP' },
        { status: 400 }
      );
    }
    
    // Clean up used session
    global.otpSessions?.delete(challengeId);
    
    // For Developer Controlled Wallets, we generate our own session tokens
    // In production, use proper JWT or session management
    const userToken = `user-token-${randomUUID()}`;
    const sessionId = `session-${randomUUID()}`;
    const userId = `user-${Buffer.from(otpSession.email).toString('base64')}`;
    
    // Store user session (in production, use Redis or database)
    (global as any).userSessions = (global as any).userSessions || new Map();
    (global as any).userSessions.set(sessionId, {
      email: otpSession.email,
      userId,
      createdAt: Date.now(),
      expiresAt: Date.now() + 24 * 60 * 60 * 1000 // 24 hours
    });
    
    // Return authentication data for Developer Controlled Wallets
    return NextResponse.json({
      success: true,
      userToken,
      sessionId,
      userId,
      email: otpSession.email,
      // Developer Controlled Wallets don't need PIN setup
      hasPinSetup: true,
      // Wallet will be created/retrieved on demand
      wallets: [],
      message: 'Authentication successful'
    });
    
  } catch (error: any) {
    console.error('Verify OTP error:', error);
    return NextResponse.json(
      { error: error?.message || 'Failed to verify OTP' },
      { status: 500 }
    );
  }
}