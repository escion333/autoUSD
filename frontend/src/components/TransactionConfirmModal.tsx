'use client';

import { useState, useEffect } from 'react';
import { formatUSDC } from '@/lib/utils/format';
import { toast } from 'react-hot-toast';

export type TransactionType = 'deposit' | 'withdraw' | 'auto-deposit' | 'manual-deposit';

interface TransactionDetails {
  type: TransactionType;
  amount: number;
  estimatedGas?: number;
  estimatedTime?: string;
  fromChain?: string;
  toChain?: string;
  currentBalance?: number;
  newBalance?: number;
  apy?: number;
  
  // Fern-specific fields
  purchaseAmount?: number;
  remainingAmount?: number;
  fernTransactionId?: string;
  fernTxHash?: string;
  usdcWalletBalance?: number;
  isPartialDeposit?: boolean;
  depositCapReached?: boolean;
  
  // Auto-deposit specific
  requiresConfirmation?: boolean;
  autoDepositEnabled?: boolean;
  
  // Manual deposit specific
  walletAddress?: string;
  errorMessage?: string;
}

interface TransactionConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => Promise<void>;
  details: TransactionDetails;
}

export function TransactionConfirmModal({
  isOpen,
  onClose,
  onConfirm,
  details,
}: TransactionConfirmModalProps) {
  const [isProcessing, setIsProcessing] = useState(false);
  const [step, setStep] = useState<'confirm' | 'processing' | 'success' | 'error'>('confirm');
  const [error, setError] = useState<string>('');
  const [txHash, setTxHash] = useState<string>('');

  useEffect(() => {
    if (!isOpen) {
      setStep('confirm');
      setError('');
      setTxHash('');
      setIsProcessing(false);
    }
  }, [isOpen]);

  const handleConfirm = async () => {
    setIsProcessing(true);
    setStep('processing');
    setError('');

    try {
      // Simulate transaction processing
      await onConfirm();
      
      // Mock transaction hash
      const mockHash = `0x${Math.random().toString(16).substring(2, 66)}`;
      setTxHash(mockHash);
      setStep('success');
      
      // Show success toast
      toast.success(`${details.type === 'deposit' ? 'Deposit' : 'Withdrawal'} successful!`);
      
      // Auto-close after 3 seconds on success
      setTimeout(() => {
        onClose();
      }, 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Transaction failed');
      setStep('error');
      toast.error('Transaction failed. Please try again.');
    } finally {
      setIsProcessing(false);
    }
  };

  const getIcon = () => {
    switch (step) {
      case 'confirm':
        if (details.type === 'auto-deposit') {
          return (
            <svg className="w-12 h-12 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
          );
        } else if (details.type === 'manual-deposit') {
          return (
            <svg className="w-12 h-12 text-warning" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          );
        } else if (details.type === 'deposit') {
          return (
            <svg className="w-12 h-12 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 11l5-5m0 0l5 5m-5-5v12" />
            </svg>
          );
        } else {
          return (
            <svg className="w-12 h-12 text-warning" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 13l-5 5m0 0l-5-5m5 5V6" />
            </svg>
          );
        }
      case 'processing':
        return (
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
        );
      case 'success':
        return (
          <svg className="w-12 h-12 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
      case 'error':
        return (
          <svg className="w-12 h-12 text-error" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl max-w-md w-full mx-4 overflow-hidden shadow-lg">
        {/* Header */}
        <div className={`px-6 py-4 ${
          details.type === 'deposit' ? 'bg-success-subtle' : 'bg-warning-subtle'
        }`}>
          <div className="flex justify-between items-center">
            <h2 className="text-xl font-heading font-semibold text-text-title">
              {step === 'confirm' && `Confirm ${details.type === 'deposit' ? 'Deposit' : 'Withdrawal'}`}
              {step === 'processing' && 'Processing Transaction'}
              {step === 'success' && 'Transaction Successful'}
              {step === 'error' && 'Transaction Failed'}
            </h2>
            {step === 'confirm' && (
              <button
                onClick={onClose}
                className="text-text-muted hover:text-text-body transition-colors"
                disabled={isProcessing}
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            )}
          </div>
        </div>

        {/* Body */}
        <div className="p-6">
          {/* Icon */}
          <div className="flex justify-center mb-6">
            {getIcon()}
          </div>

          {/* Content based on step */}
          {step === 'confirm' && (
            <>
              {/* Amount Display */}
              <div className="bg-surface rounded-lg p-4 mb-4 border border-border">
                <div className="text-center">
                  <p className="text-sm text-text-muted mb-1">Amount</p>
                  <p className="text-3xl font-bold text-text-title tabular-nums">{formatUSDC(details.amount)}</p>
                </div>
              </div>

              {/* Transaction Details */}
              <div className="space-y-3 mb-6">
                {details.currentBalance !== undefined && (
                  <div className="flex justify-between text-sm">
                    <span className="text-text-muted">Current Balance</span>
                    <span className="font-medium text-text-title">{formatUSDC(details.currentBalance)}</span>
                  </div>
                )}
                
                {details.newBalance !== undefined && (
                  <div className="flex justify-between text-sm">
                    <span className="text-text-muted">New Balance</span>
                    <span className="font-medium text-text-title">{formatUSDC(details.newBalance)}</span>
                  </div>
                )}

                {details.apy !== undefined && (
                  <div className="flex justify-between text-sm">
                    <span className="text-text-muted">Current APY</span>
                    <span className="font-medium text-primary">{details.apy.toFixed(2)}%</span>
                  </div>
                )}

                {details.estimatedTime && (
                  <div className="flex justify-between text-sm">
                    <span className="text-text-muted">Estimated Time</span>
                    <span className="font-medium text-text-title">{details.estimatedTime}</span>
                  </div>
                )}

                {details.estimatedGas !== undefined && (
                  <div className="flex justify-between text-sm">
                    <span className="text-text-muted">Network Fee</span>
                    <span className="font-medium text-text-title">
                      {details.estimatedGas === 0 ? 'Gasless (Sponsored)' : `~$${details.estimatedGas.toFixed(2)}`}
                    </span>
                  </div>
                )}
              </div>

              {/* Warning for withdrawals */}
              {details.type === 'withdraw' && (
                <div className="bg-warning-subtle border border-warning/20 rounded-lg p-3 mb-4">
                  <p className="text-sm text-warning">
                    Withdrawals may take 1-3 minutes to process across chains
                  </p>
                </div>
              )}

              {/* Action Buttons */}
              <div className="flex gap-3">
                <button
                  onClick={onClose}
                  disabled={isProcessing}
                  className="flex-1 py-3 px-4 border border-border text-text-body rounded-lg font-medium hover:bg-mist disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                >
                  Cancel
                </button>
                <button
                  onClick={handleConfirm}
                  disabled={isProcessing}
                  className={`flex-1 py-3 px-4 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm hover:shadow-md ${
                    details.type === 'deposit' 
                      ? 'bg-success hover:bg-success/90' 
                      : 'bg-warning hover:bg-warning/90'
                  }`}
                >
                  Confirm {details.type === 'deposit' ? 'Deposit' : 'Withdrawal'}
                </button>
              </div>
            </>
          )}

          {step === 'processing' && (
            <div className="text-center">
              <p className="text-text-body mb-2">
                Processing your {details.type === 'deposit' ? 'deposit' : 'withdrawal'}...
              </p>
              <p className="text-sm text-text-muted">
                This may take a few moments. Please don't close this window.
              </p>
              {details.estimatedTime && (
                <p className="text-sm text-gray-600 mt-2">
                  Estimated time: {details.estimatedTime}
                </p>
              )}
            </div>
          )}

          {step === 'success' && (
            <div className="text-center">
              <p className="text-gray-900 font-medium mb-2">
                Your {details.type === 'deposit' ? 'deposit' : 'withdrawal'} of {formatUSDC(details.amount)} was successful!
              </p>
              {txHash && (
                <div className="bg-gray-50 rounded-lg p-3 mt-4">
                  <p className="text-xs text-gray-600 mb-1">Transaction Hash</p>
                  <p className="text-xs font-mono text-gray-900 break-all">{txHash}</p>
                </div>
              )}
              <p className="text-sm text-gray-600 mt-4">
                Closing automatically...
              </p>
            </div>
          )}

          {step === 'error' && (
            <div className="text-center">
              <p className="text-red-600 font-medium mb-2">Transaction Failed</p>
              <p className="text-sm text-gray-700 mb-4">{error || 'An unexpected error occurred'}</p>
              <div className="flex gap-3">
                <button
                  onClick={onClose}
                  className="flex-1 py-2 px-4 border border-gray-300 text-gray-700 rounded-lg font-medium hover:bg-gray-50"
                >
                  Close
                </button>
                <button
                  onClick={handleConfirm}
                  disabled={isProcessing}
                  className="flex-1 py-2 px-4 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50"
                >
                  Try Again
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}