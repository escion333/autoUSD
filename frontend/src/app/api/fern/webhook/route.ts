import { NextRequest, NextResponse } from 'next/server';
import { createHmac, timingSafeEqual } from 'crypto';
import { 
  FernWebhookEvent, 
  CustomerVerifiedEvent, 
  TransactionCompletedEvent 
} from '@/lib/fern/types';

// Webhook signature verification
function verifyWebhookSignature(req: NextRequest, body: string): boolean {
  if (process.env.NODE_ENV === 'development') {
    return true; // Skip verification in development
  }
  
  const signature = req.headers.get('x-fern-signature');
  const secret = process.env.FERN_WEBHOOK_SECRET;
  
  if (!signature || !secret) {
    console.error('Missing webhook signature or secret');
    return false;
  }
  
  try {
    // Fern uses HMAC-SHA256 for webhook signatures
    const expectedSignature = createHmac('sha256', secret)
      .update(body)
      .digest('hex');
    
    // Compare signatures using timing-safe comparison
    const providedSignature = signature.replace('sha256=', '');
    return timingSafeEqual(
      Buffer.from(expectedSignature, 'hex'),
      Buffer.from(providedSignature, 'hex')
    );
  } catch (error) {
    console.error('Signature verification error:', error);
    return false;
  }
}

// Store webhook events for tracking and retry
async function storeWebhookEvent(event: FernWebhookEvent): Promise<void> {
  // In production, store to database for audit trail and retry logic
  console.log('📝 Storing webhook event:', {
    eventId: event.eventId,
    eventType: event.eventType,
    timestamp: event.timestamp,
  });
  
  // TODO: Implement database storage
  // await db.webhookEvents.create({
  //   eventId: event.eventId,
  //   eventType: event.eventType,
  //   data: event.data,
  //   timestamp: event.timestamp,
  //   processed: false,
  // });
}

// Idempotency check to prevent duplicate processing
async function isEventProcessed(eventId: string): Promise<boolean> {
  // In production, check if this event was already processed
  console.log('🔍 Checking if event was already processed:', eventId);
  
  // TODO: Implement database check
  // const existingEvent = await db.webhookEvents.findFirst({
  //   where: { eventId, processed: true }
  // });
  // return !!existingEvent;
  
  return false; // For development
}

// Mark event as processed
async function markEventProcessed(eventId: string): Promise<void> {
  console.log('✅ Marking event as processed:', eventId);
  
  // TODO: Update database
  // await db.webhookEvents.update({
  //   where: { eventId },
  //   data: { processed: true, processedAt: new Date() }
  // });
}

export async function POST(req: NextRequest) {
  let body: string;
  let event: FernWebhookEvent | undefined;
  
  try {
    // Get raw body for signature verification
    body = await req.text();
    
    // Verify webhook signature
    if (!verifyWebhookSignature(req, body)) {
      console.error('❌ Invalid webhook signature');
      return NextResponse.json(
        { error: 'Invalid signature' },
        { status: 401 }
      );
    }

    // Parse event
    event = JSON.parse(body);
    
    if (!event) {
      return NextResponse.json(
        { error: 'Invalid event data' },
        { status: 400 }
      );
    }
    
    console.log('🔔 Received Fern webhook:', {
      eventId: event.eventId,
      eventType: event.eventType,
      timestamp: event.timestamp,
    });

    // Check for duplicate events (idempotency)
    if (await isEventProcessed(event.eventId)) {
      console.log('⚠️ Event already processed, skipping:', event.eventId);
      return NextResponse.json({ received: true, status: 'already_processed' });
    }

    // Store event for audit trail
    await storeWebhookEvent(event);

    // Handle different event types
    let handlerResult: any;
    switch (event.eventType) {
      case 'customer.created':
        handlerResult = await handleCustomerCreated(event);
        break;
      
      case 'customer.verified':
        handlerResult = await handleCustomerVerified(event);
        break;
      
      case 'customer.rejected':
        handlerResult = await handleCustomerRejected(event);
        break;
      
      case 'transaction.pending':
        handlerResult = await handleTransactionPending(event);
        break;
      
      case 'transaction.processing':
        handlerResult = await handleTransactionProcessing(event);
        break;
      
      case 'transaction.completed':
        handlerResult = await handleTransactionCompleted(event);
        break;
      
      case 'transaction.failed':
        handlerResult = await handleTransactionFailed(event);
        break;
      
      default:
        console.log('⚠️ Unhandled event type:', event.eventType);
        handlerResult = { status: 'unhandled_event_type' };
    }

    // Mark event as successfully processed
    await markEventProcessed(event.eventId);

    // Return success response
    return NextResponse.json({ 
      received: true, 
      eventId: event.eventId,
      handlerResult 
    });
    
  } catch (error: any) {
    console.error('💥 Webhook processing error:', {
      error: error.message,
      stack: error.stack,
      eventId: event?.eventId,
      eventType: event?.eventType,
    });
    
    // Return 500 to trigger Fern retry mechanism
    return NextResponse.json(
      { 
        error: 'Webhook processing failed',
        eventId: event?.eventId,
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      },
      { status: 500 }
    );
  }
}

async function handleCustomerCreated(event: FernWebhookEvent) {
  console.log('✅ Customer created:', event.data.customerId);
  // Store customer ID in database if needed
}

async function handleCustomerVerified(event: FernWebhookEvent) {
  const data = event.data as CustomerVerifiedEvent;
  console.log('✅ Customer verified:', data.customerId);
  console.log('  Verification level:', data.verificationLevel);
  console.log('  Daily limit:', data.limits.daily);
  console.log('  Monthly limit:', data.limits.monthly);
  
  // Update user's KYC status in database
  // Enable purchase functionality in UI
}

async function handleCustomerRejected(event: FernWebhookEvent) {
  console.log('❌ Customer rejected:', event.data.customerId);
  console.log('  Reason:', event.data.reason);
  
  // Update user's KYC status
  // Show appropriate message to user
}

async function handleTransactionPending(event: FernWebhookEvent) {
  console.log('⏳ Transaction pending:', event.data.transactionId);
  // Update transaction status in UI
}

async function handleTransactionProcessing(event: FernWebhookEvent) {
  console.log('⚙️ Transaction processing:', event.data.transactionId);
  // Update transaction status in UI
}

async function handleTransactionCompleted(event: FernWebhookEvent) {
  const data = event.data as TransactionCompletedEvent;
  console.log('💰 Transaction completed:', data.transactionId);
  console.log('  Amount:', data.amount, data.currency);
  console.log('  Destination:', data.destinationAddress);
  console.log('  Hash:', data.transactionHash);
  
  try {
    // Auto-deposit to Mother Vault
    await triggerAutoDeposit(data);
  } catch (error) {
    console.error('Auto-deposit failed:', error);
    // Store for retry or manual processing
  }
}

async function handleTransactionFailed(event: FernWebhookEvent) {
  console.log('❌ Transaction failed:', event.data.transactionId);
  console.log('  Reason:', event.data.reason);
  
  // Update transaction status
  // Notify user of failure
  // Offer retry or refund options
}

async function triggerAutoDeposit(data: TransactionCompletedEvent) {
  console.log('🚀 Triggering auto-deposit for:', data.transactionId);
  
  try {
    // 1. Wait a moment for USDC to settle in Circle wallet
    console.log('  Waiting for USDC settlement...');
    await new Promise(resolve => setTimeout(resolve, 5000)); // 5 second delay
    
    // 2. Check wallet balance using address lookup
    console.log('  💰 Checking wallet balance for auto-deposit...');
    
    let balance = 0;
    try {
      // Use DeveloperWalletService to get wallet ID and check balance
      const { DeveloperWalletService } = await import('@/lib/circle/developer-wallet');
      const walletService = DeveloperWalletService.getInstance();
      
      const walletId = await walletService.getWalletIdByAddress(data.destinationAddress);
      
      if (walletId) {
        const balanceData = await walletService.getWalletBalance(walletId);
        
        // Find USDC balance
        const usdcBalance = balanceData.find((b: any) => 
          b.token?.symbol?.toUpperCase() === 'USDC'
        );
        
        balance = parseFloat(usdcBalance?.amount || '0');
        
        console.log(`  ✅ Current USDC balance: ${balance}`);
        
        // Verify we have enough balance for the transaction
        if (balance < data.amount) {
          console.log(`  ⚠️ Insufficient balance for auto-deposit: ${balance} < ${data.amount}`);
          console.log('  Waiting additional time for settlement...');
          
          // Wait a bit more and check again
          await new Promise(resolve => setTimeout(resolve, 10000)); // 10 second additional wait
          
          const retryBalanceData = await walletService.getWalletBalance(walletId);
          const retryUsdcBalance = retryBalanceData.find((b: any) => 
            b.token?.symbol?.toUpperCase() === 'USDC'
          );
          balance = parseFloat(retryUsdcBalance?.amount || '0');
          
          console.log(`  🔄 Balance after retry: ${balance}`);
        }
        
      } else {
        console.log('  ⚠️ Could not find wallet ID for address, using transaction amount as fallback');
        balance = data.amount;
      }
      
    } catch (error) {
      console.error('  ❌ Balance check failed:', error);
      console.log('  ⚠️ Using transaction amount as fallback due to balance check failure');
      balance = data.amount;
    }
    
    // 4. Get user's current vault position to check deposit limits
    const userEmail = await getUserEmailFromWallet(data.destinationAddress);
    if (!userEmail) {
      throw new Error('Could not find user for wallet address');
    }
    
    const currentPosition = await getUserVaultPosition(userEmail);
    const currentBalance = currentPosition?.balance || 0;
    const remainingCap = Math.max(0, 100 - currentBalance);
    
    console.log(`  Current vault balance: ${currentBalance}, Remaining cap: ${remainingCap}`);
    
    // 5. Calculate actual deposit amount (respect $100 cap)
    const maxDepositAmount = Math.min(data.amount, remainingCap);
    console.log(`  Planned deposit amount: ${maxDepositAmount} (after ${100 - currentBalance} cap)`);
    
    if (maxDepositAmount <= 0) {
      console.log('  ⚠️ Skipping auto-deposit: user has reached deposit cap');
      // Store for manual processing or user notification
      await storeFailedAutoDeposit(data, 'deposit_cap_reached');
      return { status: 'skipped', reason: 'deposit_cap_reached' };
    }
    
    // 6. Execute deposit to Mother Vault
    console.log('  📤 Executing deposit to Mother Vault...');
    
    const depositResult = await executeVaultDeposit({
      userEmail,
      amount: maxDepositAmount,
      sourceTransaction: data.transactionId,
      walletAddress: data.destinationAddress,
    });
    
    if (depositResult.success) {
      console.log('✅ Auto-deposit completed successfully:', {
        amount: maxDepositAmount,
        txHash: depositResult.transactionHash,
        vaultShares: depositResult.shares,
      });
      
      // 7. Send success notification to user
      await sendDepositNotification(userEmail, {
        amount: maxDepositAmount,
        transactionHash: depositResult.transactionHash || 'unknown',
        fernTransactionId: data.transactionId,
      });
      
      return { 
        status: 'success', 
        amount: maxDepositAmount,
        transactionHash: depositResult.transactionHash || 'unknown'
      };
    } else {
      throw new Error(`Vault deposit failed: ${depositResult.error}`);
    }
    
  } catch (error: any) {
    console.error('❌ Auto-deposit failed:', error.message);
    
    // Classify error type for better handling
    const errorType = classifyAutoDepositError(error);
    
    // Store failed attempt with error classification
    await storeFailedAutoDeposit(data, error.message, errorType);
    
    // Send appropriate notification based on error type
    const userEmail = await getUserEmailFromWallet(data.destinationAddress);
    if (userEmail) {
      await sendDepositFailureNotification(userEmail, {
        amount: data.amount,
        fernTransactionId: data.transactionId,
        error: error.message,
        errorType: errorType,
        canRetry: isRetryableError(errorType),
      });
    }
    
    // Only re-throw for retryable errors to trigger webhook retry
    // For non-retryable errors, we don't want infinite webhook retries
    if (isRetryableError(errorType)) {
      throw error;
    } else {
      console.log('⚠️ Non-retryable error, not triggering webhook retry');
      return { status: 'failed', reason: error.message, errorType };
    }
  }
}

// Helper functions for auto-deposit
async function getUserEmailFromWallet(walletAddress: string): Promise<string | null> {
  console.log('🔍 Looking up user by wallet:', walletAddress);
  
  try {
    // Use DeveloperWalletService to find user by wallet address
    const { DeveloperWalletService } = await import('@/lib/circle/developer-wallet');
    const walletService = DeveloperWalletService.getInstance();
    
    const userEmail = await walletService.getUserEmailByAddress(walletAddress);
    
    if (userEmail) {
      console.log('✅ Found user for wallet:', { walletAddress, userEmail });
      return userEmail;
    }
    
    console.log('❌ No user found for wallet:', walletAddress);
    
    // In development, return mock email for testing
    if (process.env.NODE_ENV === 'development') {
      console.log('⚠️ Development mode: using mock email');
      return 'test@example.com';
    }
    
    return null;
  } catch (error) {
    console.error('Failed to lookup user by wallet:', error);
    
    // Fallback to mock in development
    if (process.env.NODE_ENV === 'development') {
      console.log('⚠️ Development mode fallback: using mock email');
      return 'test@example.com';
    }
    
    return null;
  }
}

async function getUserVaultPosition(email: string): Promise<{ balance: number } | null> {
  // TODO: Query user's current vault position
  console.log('📊 Getting vault position for:', email);
  
  // In development, return mock position
  if (process.env.NODE_ENV === 'development') {
    return { balance: 0 }; // Fresh user for testing
  }
  
  // In production, query vault contract or database
  return null;
}

async function executeVaultDeposit(params: {
  userEmail: string;
  amount: number;
  sourceTransaction: string;
  walletAddress: string;
}): Promise<{ success: boolean; transactionHash?: string; shares?: number; error?: string }> {
  console.log('💰 Executing vault deposit:', params);
  
  // In development, simulate successful deposit
  if (process.env.NODE_ENV === 'development') {
    await new Promise(resolve => setTimeout(resolve, 2000)); // Simulate network delay
    return {
      success: true,
      transactionHash: `0x${Math.random().toString(16).substring(2, 66)}`,
      shares: params.amount * 0.99, // Mock shares calculation
    };
  }
  
  // TODO: In production, call smart contract
  // const result = await contractService.deposit({
  //   amount: params.amount,
  //   userAddress: params.walletAddress,
  //   sourceRef: params.sourceTransaction,
  // });
  
  return { success: false, error: 'Not implemented in production' };
}

// Error classification types
type AutoDepositErrorType = 
  | 'user_not_found'
  | 'deposit_cap_exceeded' 
  | 'insufficient_balance'
  | 'contract_error'
  | 'network_error'
  | 'vault_paused'
  | 'slippage_exceeded'
  | 'gas_estimation_failed'
  | 'timeout'
  | 'unknown';

function classifyAutoDepositError(error: any): AutoDepositErrorType {
  const message = error.message?.toLowerCase() || '';
  
  // User/account related errors (non-retryable)
  if (message.includes('user') && message.includes('not found')) {
    return 'user_not_found';
  }
  if (message.includes('deposit cap') || message.includes('limit')) {
    return 'deposit_cap_exceeded';
  }
  if (message.includes('insufficient balance')) {
    return 'insufficient_balance';
  }
  
  // Contract/blockchain errors (potentially retryable)
  if (message.includes('contract') || message.includes('revert')) {
    return 'contract_error';
  }
  if (message.includes('vault') && message.includes('paused')) {
    return 'vault_paused';
  }
  if (message.includes('slippage')) {
    return 'slippage_exceeded';
  }
  if (message.includes('gas')) {
    return 'gas_estimation_failed';
  }
  
  // Network errors (retryable)
  if (message.includes('network') || message.includes('timeout') || message.includes('connection')) {
    return 'network_error';
  }
  if (message.includes('timeout')) {
    return 'timeout';
  }
  
  return 'unknown';
}

function isRetryableError(errorType: AutoDepositErrorType): boolean {
  const retryableErrors: AutoDepositErrorType[] = [
    'network_error',
    'timeout',
    'gas_estimation_failed',
    'slippage_exceeded',
    'contract_error', // Some contract errors might be temporary
  ];
  
  return retryableErrors.includes(errorType);
}

async function storeFailedAutoDeposit(
  data: TransactionCompletedEvent, 
  reason: string, 
  errorType: AutoDepositErrorType = 'unknown'
): Promise<void> {
  console.log('💾 Storing failed auto-deposit:', { 
    transactionId: data.transactionId, 
    reason, 
    errorType,
    canRetry: isRetryableError(errorType)
  });
  
  // TODO: Store in database for manual processing and retry attempts
  // await db.failedAutoDeposits.create({
  //   fernTransactionId: data.transactionId,
  //   amount: data.amount,
  //   destinationAddress: data.destinationAddress,
  //   reason,
  //   errorType,
  //   canRetry: isRetryableError(errorType),
  //   retryCount: 0,
  //   createdAt: new Date(),
  //   lastRetryAt: null,
  // });
}

async function sendDepositNotification(email: string, data: {
  amount: number;
  transactionHash: string;
  fernTransactionId: string;
}): Promise<void> {
  console.log('📧 Sending deposit success notification to:', email);
  
  // TODO: Implement email notification
  // await emailService.sendDepositSuccess({
  //   to: email,
  //   amount: data.amount,
  //   transactionHash: data.transactionHash,
  //   fernTransactionId: data.fernTransactionId,
  // });
}

async function sendDepositFailureNotification(email: string, data: {
  amount: number;
  fernTransactionId: string;
  error: string;
  errorType?: AutoDepositErrorType;
  canRetry?: boolean;
}): Promise<void> {
  console.log('📧 Sending deposit failure notification to:', email, {
    errorType: data.errorType,
    canRetry: data.canRetry,
  });
  
  // TODO: Implement email notification with enhanced error information
  // await emailService.sendDepositFailure({
  //   to: email,
  //   amount: data.amount,
  //   fernTransactionId: data.fernTransactionId,
  //   error: data.error,
  //   errorType: data.errorType,
  //   canRetry: data.canRetry,
  //   nextSteps: getNextStepsForErrorType(data.errorType),
  // });
}

function getNextStepsForErrorType(errorType?: AutoDepositErrorType): string[] {
  switch (errorType) {
    case 'user_not_found':
      return ['Please contact support to verify your account setup'];
    case 'deposit_cap_exceeded':
      return ['Withdraw some funds to make room for the deposit', 'Or wait for beta limits to be increased'];
    case 'insufficient_balance':
      return ['Check your wallet balance', 'Wait for the USDC transfer to complete'];
    case 'vault_paused':
      return ['Wait for vault to be unpaused', 'Check system status page for updates'];
    case 'network_error':
    case 'timeout':
    case 'gas_estimation_failed':
      return ['The system will automatically retry', 'Or try depositing manually from your wallet'];
    default:
      return ['Try depositing manually from your wallet', 'Contact support if the issue persists'];
  }
}