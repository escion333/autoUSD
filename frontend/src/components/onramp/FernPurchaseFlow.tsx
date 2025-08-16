'use client';

import { useState, useEffect } from 'react';
import { useCircleAuth } from '@/hooks/useCircleAuth';
import { FernErrorHandler, FernError, isFernError } from '@/lib/errors/fernErrors';
import { ErrorAlert } from '@/components/ErrorAlert';
import { useTransactionPolling } from '@/hooks/usePurchasePolling';

interface FernPurchaseFlowProps {
  onPurchaseComplete: (amount: number, txHash: string) => void;
  defaultAmount?: number;
}

interface FernCustomer {
  customerId: string;
  status: string;
  kycLink: string;
  isVerified: boolean;
}

interface FernQuote {
  quoteId: string;
  fromAmount: number;
  toAmount: number;
  fees: {
    fernFee: number;
    networkFee: number;
    totalFee: number;
  };
  expiresAt: string;
}

interface FernTransaction {
  transactionId: string;
  status: string;
  paymentInstructions: string;
  rawInstructions?: {
    method: string;
    referenceNumber: string;
    deadline: string;
  };
}

export function FernPurchaseFlow({ onPurchaseComplete, defaultAmount = 100 }: FernPurchaseFlowProps) {
  const [amount, setAmount] = useState(defaultAmount);
  const [isProcessing, setIsProcessing] = useState(false);
  const [customer, setCustomer] = useState<FernCustomer | null>(null);
  const [quote, setQuote] = useState<FernQuote | null>(null);
  const [transaction, setTransaction] = useState<FernTransaction | null>(null);
  const [error, setError] = useState<FernError | null>(null);
  const [step, setStep] = useState<'amount' | 'kyc' | 'quote' | 'payment'>('amount');
  const [devForceUnverified, setDevForceUnverified] = useState(false);
  const [retryCount, setRetryCount] = useState(0);
  
  const { user } = useCircleAuth();
  
  // Use transaction polling for real-time status updates
  const { 
    status: pollStatus, 
    isLoading: isPolling, 
    error: pollError 
  } = useTransactionPolling(
    transaction?.transactionId || null,
    {
      enabled: !!transaction && transaction.status !== 'completed' && transaction.status !== 'failed',
      onComplete: (status) => {
        console.log('✅ Transaction completed via polling:', status);
        onPurchaseComplete(status.toAmount, status.transactionHash || 'completed');
      },
      onFailed: (status) => {
        console.log('❌ Transaction failed via polling:', status);
        setError(FernErrorHandler.parse(`Transaction failed: ${status.status}`, 'transaction-polling'));
      },
    }
  );

  // Check/create Fern customer on mount
  useEffect(() => {
    if (user?.email) {
      checkOrCreateCustomer();
    }
  }, [user?.email]);

  const checkOrCreateCustomer = async () => {
    if (!user?.email) return;
    
    const operationId = `customer-check-${user.email}`;
    
    try {
      setError(null);
      
      await FernErrorHandler.handleWithRetry(async () => {
        const headers: HeadersInit = { 'Content-Type': 'application/json' };
        
        // In development, allow forcing unverified state for testing
        if (process.env.NODE_ENV === 'development' && devForceUnverified) {
          headers['x-force-unverified'] = 'true';
        }
        
        const response = await fetch('/api/fern/customer', {
          method: 'POST',
          headers,
          body: JSON.stringify({ email: user.email }),
        });
        
        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(errorData.error || 'Failed to check customer');
        }
        
        const data = await response.json();
        setCustomer(data);
        
        // If customer is not verified, show KYC step
        if (!data.isVerified) {
          setStep('kyc');
        }
        
        return data;
      }, operationId, (fernError, attempt) => {
        console.log(`🔄 Retrying customer check (attempt ${attempt}):`, fernError.message);
        setError(fernError);
      });
      
      FernErrorHandler.clearRetryAttempts(operationId);
      
    } catch (rawError) {
      const fernError = FernErrorHandler.parse(rawError, 'customer-check');
      console.error('❌ Failed to check/create customer:', fernError);
      setError(fernError);
    }
  };

  const handleGenerateQuote = async () => {
    if (!customer || !user?.walletAddress) {
      setError(FernErrorHandler.parse('Please complete KYC first', 'quote-generation'));
      return;
    }
    
    setIsProcessing(true);
    setError(null);
    
    const operationId = `quote-${customer.customerId}-${amount}`;
    
    try {
      await FernErrorHandler.handleWithRetry(async () => {
        const response = await fetch('/api/fern/quote', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            customerId: customer.customerId,
            amount,
            destinationAddress: user.walletAddress,
          }),
        });
        
        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(errorData.error || 'Failed to generate quote');
        }
        
        const quoteData = await response.json();
        setQuote(quoteData);
        setStep('quote');
        
        return quoteData;
      }, operationId, (fernError, attempt) => {
        console.log(`🔄 Retrying quote generation (attempt ${attempt}):`, fernError.message);
        setError(fernError);
      });
      
      FernErrorHandler.clearRetryAttempts(operationId);
      
    } catch (rawError) {
      const fernError = FernErrorHandler.parse(rawError, 'quote-generation');
      console.error('❌ Quote generation failed:', fernError);
      setError(fernError);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleConfirmQuote = async () => {
    if (!customer || !quote) return;
    
    setIsProcessing(true);
    setError(null);
    
    try {
      const response = await fetch('/api/fern/transaction', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          customerId: customer.customerId,
          quoteId: quote.quoteId,
          paymentMethod: 'wire',
        }),
      });
      
      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to create transaction');
      }
      
      const txData = await response.json();
      setTransaction(txData);
      setStep('payment');
      
      // Start polling for transaction status
      pollTransactionStatus(txData.transactionId);
    } catch (err: any) {
      setError(err.message || 'Failed to create transaction');
    } finally {
      setIsProcessing(false);
    }
  };

  const pollTransactionStatus = async (transactionId: string) => {
    const checkStatus = async () => {
      try {
        const response = await fetch(`/api/fern/transaction?transactionId=${transactionId}`);
        const data = await response.json();
        
        if (data.status === 'completed') {
          // Transaction complete! Trigger auto-deposit
          onPurchaseComplete(amount, data.transactionHash || 'mock-hash');
        } else if (data.status === 'failed') {
          setError(FernErrorHandler.parse('Transaction failed. Please try again.', 'transaction-polling'));
        } else {
          // Keep polling
          setTimeout(checkStatus, 5000); // Check every 5 seconds
        }
      } catch (err) {
        console.error('Failed to check transaction status:', err);
      }
    };
    
    // In development, simulate completion after 5 seconds
    if (process.env.NODE_ENV === 'development') {
      setTimeout(() => {
        onPurchaseComplete(amount, `0x${Math.random().toString(16).substring(2, 66)}`);
      }, 5000);
    } else {
      checkStatus();
    }
  };

  const renderKYCStep = () => (
    <div className="space-y-4">
      <div className="p-4 bg-amber-50 border border-amber-200 rounded-lg">
        <h3 className="font-medium text-amber-900 mb-2">KYC Required</h3>
        <p className="text-sm text-amber-800 mb-3">
          Please complete identity verification to purchase USDC.
        </p>
        <a
          href={customer?.kycLink || '#'}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 px-4 py-2 bg-amber-600 text-white rounded-lg hover:bg-amber-700 transition-colors"
        >
          Complete KYC
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
          </svg>
        </a>
      </div>
      <button
        onClick={checkOrCreateCustomer}
        className="w-full py-2 px-4 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
      >
        Check Verification Status
      </button>
    </div>
  );

  const renderAmountStep = () => (
    <div className="space-y-4">
      {/* Dev mode toggle */}
      {process.env.NODE_ENV === 'development' && (
        <div className="p-3 bg-gray-100 border border-gray-300 rounded-lg">
          <label className="flex items-center gap-2 text-sm text-gray-700">
            <input
              type="checkbox"
              checked={devForceUnverified}
              onChange={(e) => {
                setDevForceUnverified(e.target.checked);
                setCustomer(null); // Reset customer to force re-check
                setTimeout(() => checkOrCreateCustomer(), 100);
              }}
              className="rounded"
            />
            Dev: Simulate unverified KYC
          </label>
        </div>
      )}
      
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Amount (USD)
        </label>
        <div className="relative">
          <span className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-700">$</span>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(Math.min(100, Math.max(1, Number(e.target.value))))}
            className="w-full pl-8 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            min="1"
            max="100"
            step="1"
            disabled={isProcessing}
          />
        </div>
        <p className="text-xs text-gray-700 mt-1">Beta limit: $100 per deposit</p>
      </div>

      {error && (
        <ErrorAlert
          error={error.userMessage || error.message}
          onRetry={error.isRetryable ? () => {
            setError(null);
            if (error.actionRequired === 'retry') {
              checkOrCreateCustomer();
            }
          } : undefined}
          onDismiss={() => setError(null)}
        />
      )}
      
      {pollError && (
        <ErrorAlert
          error={pollError}
          onDismiss={() => {/* Poll error will clear itself */}}
        />
      )}
      
      {/* Show KYC status */}
      {customer && !customer.isVerified && (
        <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg">
          <p className="text-sm text-amber-800">Please complete KYC first</p>
        </div>
      )}

      <button
        onClick={handleGenerateQuote}
        disabled={isProcessing || amount < 1 || amount > 100 || !customer?.isVerified}
        className={`w-full py-3 px-4 rounded-lg font-medium transition-colors ${
          isProcessing || amount < 1 || amount > 100 || !customer?.isVerified
            ? 'bg-gray-300 text-gray-700 cursor-not-allowed'
            : 'bg-blue-600 text-white hover:bg-blue-700'
        }`}
      >
        {isProcessing ? 'Generating Quote...' : 'Get Quote'}
      </button>

      {!customer?.isVerified && customer && (
        <div className="space-y-2">
          <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg">
            <p className="text-sm text-amber-800">KYC verification required</p>
          </div>
          <button
            onClick={() => {
              if (process.env.NODE_ENV === 'development') {
                // In dev, just simulate verification
                setCustomer({ ...customer, isVerified: true, status: 'verified' });
                setStep('amount');
              } else {
                // In production, open KYC link
                window.open(customer.kycLink || 'https://kyc.fernhq.com', '_blank');
              }
            }}
            className="w-full py-2 px-4 bg-amber-600 text-white rounded-lg hover:bg-amber-700 transition-colors flex items-center justify-center gap-2"
          >
            {process.env.NODE_ENV === 'development' ? 'Simulate KYC Completion' : 'Complete KYC Verification'}
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
            </svg>
          </button>
          <button
            onClick={checkOrCreateCustomer}
            className="w-full py-2 px-4 text-sm text-gray-600 hover:text-gray-800 transition-colors"
          >
            Refresh verification status
          </button>
        </div>
      )}
    </div>
  );

  const renderQuoteStep = () => (
    <div className="space-y-4">
      <div className="p-4 bg-gray-50 rounded-lg space-y-2">
        <h3 className="font-medium text-gray-900">Quote Details</h3>
        <div className="space-y-1 text-sm">
          <div className="flex justify-between">
            <span className="text-gray-700">You Pay:</span>
            <span className="font-medium">${quote?.fromAmount.toFixed(2)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-700">Fern Fee (0.5%):</span>
            <span className="font-medium">${quote?.fees.fernFee.toFixed(2)}</span>
          </div>
          {(quote?.fees.networkFee || 0) > 0 && (
            <div className="flex justify-between">
              <span className="text-gray-700">Network Fee:</span>
              <span className="font-medium">${quote?.fees.networkFee.toFixed(2)}</span>
            </div>
          )}
          <div className="pt-1 border-t border-gray-200">
            <div className="flex justify-between">
              <span className="text-gray-700">You Receive:</span>
              <span className="font-semibold text-green-600">{quote?.toAmount.toFixed(2)} USDC</span>
            </div>
          </div>
        </div>
        <p className="text-xs text-gray-700 mt-2">
          Quote expires: {quote && new Date(quote.expiresAt).toLocaleTimeString()}
        </p>
      </div>

      {error && (
        <ErrorAlert
          error={error.userMessage || error.message}
          onRetry={error.isRetryable ? () => {
            setError(null);
            if (error.actionRequired === 'retry') {
              handleGenerateQuote();
            }
          } : undefined}
          onDismiss={() => setError(null)}
        />
      )}

      <div className="flex gap-3">
        <button
          onClick={() => setStep('amount')}
          className="flex-1 py-2 px-4 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
        >
          Back
        </button>
        <button
          onClick={handleConfirmQuote}
          disabled={isProcessing}
          className={`flex-1 py-2 px-4 rounded-lg font-medium transition-colors ${
            isProcessing
              ? 'bg-gray-300 text-gray-700 cursor-not-allowed'
              : 'bg-blue-600 text-white hover:bg-blue-700'
          }`}
        >
          {isProcessing ? 'Processing...' : 'Confirm & Pay'}
        </button>
      </div>
    </div>
  );

  const renderPaymentStep = () => (
    <div className="space-y-4">
      <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
        <h3 className="font-medium text-green-900 mb-2">Transaction Created!</h3>
        <p className="text-sm text-green-800 mb-3">
          Please complete the payment using the instructions below.
        </p>
      </div>

      <div className="p-4 bg-gray-50 rounded-lg">
        <h4 className="font-medium text-gray-900 mb-3">Payment Instructions</h4>
        <pre className="text-xs text-gray-700 whitespace-pre-wrap font-mono">
          {transaction?.paymentInstructions}
        </pre>
      </div>

      <div className="p-3 bg-blue-50 border border-blue-200 rounded-lg">
        <p className="text-sm text-blue-800">
          Once payment is received, your USDC will be automatically deposited to your vault.
        </p>
      </div>

      <div className="text-center text-sm text-gray-700">
        <div className="animate-pulse">Waiting for payment confirmation...</div>
        {process.env.NODE_ENV === 'development' && (
          <p className="text-xs mt-2">Dev mode: Will auto-complete in 5 seconds</p>
        )}
      </div>
    </div>
  );

  // Show loading while checking customer
  if (!customer && user?.email) {
    return (
      <div className="text-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
        <p className="text-gray-700">Loading...</p>
      </div>
    );
  }

  // Render based on current step
  if (!customer?.isVerified && step === 'kyc') {
    return renderKYCStep();
  }

  switch (step) {
    case 'quote':
      return renderQuoteStep();
    case 'payment':
      return renderPaymentStep();
    default:
      return renderAmountStep();
  }
}