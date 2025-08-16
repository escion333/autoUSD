'use client';

import { useState } from 'react';
import { FernPurchaseFlow } from './FernPurchaseFlow';
import { useMotherVault } from '@/hooks/useMotherVault';
import { formatUSDC } from '@/lib/utils/format';

interface OnrampModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  defaultAmount?: number;
}

export function OnrampModal({ isOpen, onClose, onSuccess, defaultAmount = 100 }: OnrampModalProps) {
  const [isPurchasing, setIsPurchasing] = useState(false);
  const [purchaseComplete, setPurchaseComplete] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { deposit, userPosition } = useMotherVault();

  const handlePurchaseComplete = async (amount: number, txHash: string) => {
    setIsPurchasing(true);
    
    try {
      // Check current position to ensure deposit amount respects limits
      const currentBalance = userPosition?.balance || 0;
      const remainingCap = Math.max(0, 100 - currentBalance);
      const actualDepositAmount = Math.min(amount, remainingCap);
      
      console.log('📤 Processing auto-deposit:', {
        purchaseAmount: amount,
        currentBalance,
        remainingCap,
        actualDepositAmount,
        txHash,
      });
      
      if (actualDepositAmount <= 0) {
        console.warn('⚠️ Cannot deposit: would exceed deposit cap');
        setError('Purchase completed but cannot auto-deposit as it would exceed the $100 beta limit.');
        setIsPurchasing(false);
        return;
      }
      
      if (actualDepositAmount < amount) {
        console.warn('⚠️ Partial deposit due to cap limits');
        setError(`Only $${actualDepositAmount.toFixed(2)} of $${amount.toFixed(2)} can be deposited due to the beta limit.`);
      }
      
      // Auto-deposit the amount (respecting limits)
      await deposit(actualDepositAmount);
      setPurchaseComplete(true);
      
      // Show success for 3 seconds then close
      setTimeout(() => {
        onSuccess();
        onClose();
        setPurchaseComplete(false);
        setIsPurchasing(false);
        setError(null);
      }, 3000);
      
    } catch (error: any) {
      console.error('❌ Auto-deposit failed:', error);
      setError(`Purchase completed but auto-deposit failed: ${error.message}. Please deposit manually from your wallet.`);
      setIsPurchasing(false);
    }
  };

  if (!isOpen) return null;

  const currentBalance = userPosition?.balance || 0;
  const remainingCap = Math.max(0, 100 - currentBalance);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-8 max-w-lg w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-6">
          <div>
            <h2 className="text-2xl font-bold text-gray-900">Buy USDC</h2>
            <p className="text-sm text-gray-700 mt-1">Purchase and auto-deposit in one step</p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-700 hover:text-gray-900"
            disabled={isPurchasing}
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Deposit Cap Warning */}
        {remainingCap < 100 && (
          <div className="mb-4 p-3 bg-amber-50 border border-amber-200 rounded-lg">
            <div className="flex items-start gap-2">
              <svg className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
              <div>
                <p className="text-sm font-medium text-amber-800">Beta Deposit Limit</p>
                <p className="text-sm text-amber-700 mt-1">
                  You have {formatUSDC(currentBalance)} deposited. You can purchase up to {formatUSDC(remainingCap)} more.
                </p>
                {remainingCap <= 0 && (
                  <p className="text-xs text-amber-600 mt-2">
                    You've reached the $100 beta limit. Withdraw funds to make room for new deposits.
                  </p>
                )}
              </div>
            </div>
          </div>
        )}
        
        {/* Error Display */}
        {error && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
            <div className="flex items-start gap-2">
              <svg className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
              </svg>
              <div className="flex-1">
                <p className="text-sm font-medium text-red-800">Auto-deposit Issue</p>
                <p className="text-sm text-red-700 mt-1">{error}</p>
                <button
                  onClick={() => setError(null)}
                  className="text-xs text-red-600 hover:text-red-800 mt-2 underline"
                >
                  Dismiss
                </button>
              </div>
            </div>
          </div>
        )}

        {purchaseComplete ? (
          <div className="py-12 text-center">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Purchase Complete!</h3>
            <p className="text-gray-700">Your USDC has been automatically deposited to earn yield.</p>
          </div>
        ) : isPurchasing ? (
          <div className="py-12 text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <p className="text-gray-700">Depositing your USDC...</p>
          </div>
        ) : (
          <>
            {/* Fern Purchase Flow */}
            <FernPurchaseFlow 
              onPurchaseComplete={handlePurchaseComplete}
              defaultAmount={Math.min(defaultAmount, remainingCap)}
            />

            {/* Benefits */}
            <div className="mt-6 space-y-3">
              <div className="flex items-start gap-3">
                <div className="w-5 h-5 bg-blue-100 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                  <svg className="w-3 h-3 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-900">Instant Deposit</p>
                  <p className="text-xs text-gray-700">USDC automatically deposited to start earning</p>
                </div>
              </div>
              
              <div className="flex items-start gap-3">
                <div className="w-5 h-5 bg-blue-100 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                  <svg className="w-3 h-3 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-900">Low Fees</p>
                  <p className="text-xs text-gray-700">2% processing fee, no gas costs</p>
                </div>
              </div>
              
              <div className="flex items-start gap-3">
                <div className="w-5 h-5 bg-blue-100 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                  <svg className="w-3 h-3 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-900">Secure & Compliant</p>
                  <p className="text-xs text-gray-700">KYC verified, regulatory compliant</p>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}