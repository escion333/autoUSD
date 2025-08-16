import { NextRequest, NextResponse } from 'next/server';
import { randomUUID } from 'crypto';

// For Developer Controlled Wallets, we handle our own authentication
// Circle doesn't send emails - we manage the entire auth flow
// In production, you'd integrate with an email service like SendGrid, AWS SES, etc.

export async function POST(request: NextRequest) {
  try {
    const { email } = await request.json();
    
    if (!email) {
      return NextResponse.json({ error: 'Email is required' }, { status: 400 });
    }

    console.log('Attempting to send OTP to:', email);

    // Generate a 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const challengeId = randomUUID();
    
    // Store the OTP session (in production, use Redis or database)
    const otpSession = {
      challengeId,
      email,
      otp,
      expiresAt: Date.now() + 10 * 60 * 1000 // 10 minutes
    };
    
    // In-memory storage for development (replace with Redis/DB in production)
    global.otpSessions = global.otpSessions || new Map();
    global.otpSessions.set(challengeId, otpSession);
    
    // TODO: In production, send real email here
    // Example with SendGrid:
    // await sendgrid.send({
    //   to: email,
    //   from: 'noreply@autousd.com',
    //   subject: 'Your autoUSD verification code',
    //   text: `Your verification code is: ${otp}`,
    //   html: `<p>Your verification code is: <strong>${otp}</strong></p>`
    // });
    
    // For development/testing, we'll return the OTP in console and response
    console.log('================================');
    console.log(`📧 Email OTP for ${email}`);
    console.log(`📱 Verification Code: ${otp}`);
    console.log('================================');
    
    // In production, don't include the OTP in the response!
    const isDevelopment = process.env.NODE_ENV === 'development';
    
    return NextResponse.json({
      success: true,
      challengeId,
      message: isDevelopment 
        ? `Development mode: Check console for OTP (${otp})` 
        : 'Verification code sent to your email',
      // Only include OTP in development
      ...(isDevelopment && { debugOtp: otp })
    });
    
  } catch (error: any) {
    console.error('Send OTP error:', error);
    return NextResponse.json(
      { error: error?.message || 'Failed to send OTP' },
      { status: 500 }
    );
  }
}