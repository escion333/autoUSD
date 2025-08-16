'use client';

import { useState } from 'react';
import { FernWidget } from './FernWidget';
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
  const { deposit, userPosition } = useMotherVault();

  const handlePurchaseComplete = async (amount: number, txHash: string) => {
    setIsPurchasing(true);
    
    try {
      // Auto-deposit the purchased USDC
      await deposit(amount);
      setPurchaseComplete(true);
      
      // Show success for 2 seconds then close
      setTimeout(() => {
        onSuccess();
        onClose();
        setPurchaseComplete(false);
        setIsPurchasing(false);
      }, 2000);
    } catch (error) {
      console.error('Failed to auto-deposit:', error);
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
            <p className="text-sm text-gray-600 mt-1">Purchase and auto-deposit in one step</p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
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
            <p className="text-sm text-amber-800">
              You can purchase up to {formatUSDC(remainingCap)} more due to the beta deposit cap.
            </p>
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
            <p className="text-gray-600">Your USDC has been automatically deposited to earn yield.</p>
          </div>
        ) : isPurchasing ? (
          <div className="py-12 text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <p className="text-gray-600">Depositing your USDC...</p>
          </div>
        ) : (
          <>
            {/* Fern Widget */}
            <FernWidget 
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
                  <p className="text-xs text-gray-600">USDC automatically deposited to start earning</p>
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
                  <p className="text-xs text-gray-600">2% processing fee, no gas costs</p>
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
                  <p className="text-xs text-gray-600">KYC verified, regulatory compliant</p>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}