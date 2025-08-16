import { NextRequest, NextResponse } from 'next/server';
import { fernAPI } from '@/lib/fern/api';

export async function POST(req: NextRequest) {
  let email: string | undefined;
  
  try {
    const body = await req.json();
    email = body.email;
    
    if (!email) {
      return NextResponse.json(
        { error: 'Email is required' },
        { status: 400 }
      );
    }
    
    // Validate email format
    if (!email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
      return NextResponse.json(
        { error: 'Invalid email format' },
        { status: 400 }
      );
    }
    
    console.log('👤 Getting/creating Fern customer for:', email);
    
    // Get or create customer
    const customer = await fernAPI.getOrCreateCustomer(email);
    
    console.log('✅ Customer data retrieved:', {
      customerId: customer.customerId,
      status: customer.customerStatus,
      isVerified: fernAPI.isCustomerVerified(customer),
      hasKycLink: !!customer.kycLink,
    });
    
    return NextResponse.json({
      customerId: customer.customerId,
      status: customer.customerStatus,
      kycLink: customer.kycLink,
      isVerified: fernAPI.isCustomerVerified(customer),
      email: customer.email,
      customerType: customer.customerType,
      createdAt: customer.createdAt,
      updatedAt: customer.updatedAt,
      
      // Additional KYC information
      verificationLevel: getVerificationLevel(customer),
      limits: getCustomerLimits(customer),
      canPurchase: fernAPI.isCustomerVerified(customer),
      
      // Next steps for user
      nextSteps: getKYCNextSteps(customer),
    });
    
  } catch (error: any) {
    console.error('❌ Customer creation/fetch error:', {
      error: error.message,
      email: email || 'unknown',
    });
    
    // Handle specific Fern API errors
    if (error.message?.includes('Invalid email')) {
      return NextResponse.json(
        { error: 'Invalid email address provided' },
        { status: 400 }
      );
    }
    
    if (error.message?.includes('Rate limit')) {
      return NextResponse.json(
        { error: 'Too many requests. Please try again later.' },
        { status: 429 }
      );
    }
    
    // In development, return mock data
    if (process.env.NODE_ENV === 'development') {
      console.log('🔧 Falling back to mock customer data in development');
      
      // For testing, allow toggling KYC status with a query param
      const forceUnverified = req.headers.get('x-force-unverified') === 'true';
      const mockCustomer = getMockCustomer(email || 'test@example.com', forceUnverified);
      
      return NextResponse.json(mockCustomer);
    }
    
    return NextResponse.json(
      { 
        error: error.message || 'Failed to create/fetch customer',
        code: 'CUSTOMER_ERROR'
      },
      { status: 500 }
    );
  }
}

export async function GET(req: NextRequest) {
  try {
    const customerId = req.nextUrl.searchParams.get('customerId');
    
    if (!customerId) {
      return NextResponse.json(
        { error: 'Customer ID is required' },
        { status: 400 }
      );
    }
    
    const customer = await fernAPI.getCustomer(customerId);
    
    return NextResponse.json({
      customerId: customer.customerId,
      status: customer.customerStatus,
      kycLink: customer.kycLink,
      isVerified: fernAPI.isCustomerVerified(customer),
      email: customer.email,
    });
  } catch (error: any) {
    console.error('Customer fetch error:', error);
    
    // In development, return mock data
    if (process.env.NODE_ENV === 'development') {
      return NextResponse.json({
        customerId: req.nextUrl.searchParams.get('customerId'),
        status: 'verified',
        kycLink: 'https://kyc.fernhq.com/mock-link',
        isVerified: true,
        email: 'test@example.com',
      });
    }
    
    return NextResponse.json(
      { error: error.message || 'Failed to fetch customer' },
      { status: 500 }
    );
  }
}

// Helper functions
function getVerificationLevel(customer: any): 'basic' | 'enhanced' | null {
  // In production, this would come from the Fern API
  return customer.customerStatus === 'verified' ? 'basic' : null;
}

function getCustomerLimits(customer: any): { daily: number; monthly: number } | null {
  if (customer.customerStatus !== 'verified') {
    return null;
  }
  
  // In production, these would come from the Fern API
  return {
    daily: 1000,
    monthly: 10000,
  };
}

function getKYCNextSteps(customer: any): string[] {
  switch (customer.customerStatus) {
    case 'pending':
      return [
        'Complete KYC verification using the provided link',
        'Upload required documents (ID, proof of address)',
        'Wait for verification (usually 1-2 business days)',
        'You\'ll receive an email when verification is complete'
      ];
    case 'verified':
      return [
        'KYC verification complete!',
        'You can now purchase USDC',
        'Start by creating a quote for your desired amount'
      ];
    case 'rejected':
      return [
        'KYC verification was rejected',
        'Please contact support for assistance',
        'You may need to provide additional documentation'
      ];
    default:
      return [
        'Click "Complete KYC" to start verification',
        'You\'ll need government-issued ID and proof of address',
        'Verification usually takes 1-2 business days'
      ];
  }
}

function getMockCustomer(email: string, forceUnverified = false): any {
  const isVerified = !forceUnverified;
  const status = isVerified ? 'verified' : 'pending';
  
  return {
    customerId: `mock-customer-${email.split('@')[0]}-${Date.now()}`,
    status,
    kycLink: isVerified ? null : 'https://kyc.fernhq.com/mock-verification',
    isVerified,
    email,
    customerType: 'individual',
    createdAt: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(), // 1 day ago
    updatedAt: new Date().toISOString(),
    verificationLevel: isVerified ? 'basic' : null,
    limits: isVerified ? { daily: 1000, monthly: 10000 } : null,
    canPurchase: isVerified,
    nextSteps: getKYCNextSteps({ customerStatus: status }),
  };
}