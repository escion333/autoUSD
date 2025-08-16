'use client';

import { useState } from 'react';
import { useMotherVault } from '@/hooks/useMotherVault';
import { useChainValidation } from '@/hooks/useChainValidation';
import { formatUSDC } from '@/lib/utils/format';
import { LoadingSpinner } from '@/components/LoadingSpinner';

interface DepositModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

const DEPOSIT_CAP = 100; // $100 cap for MVP

export function DepositModal({ isOpen, onClose, onSuccess }: DepositModalProps) {
  const [amount, setAmount] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const { deposit, userPosition } = useMotherVault();
  const { isCorrectChain, chainName, switchChain, isChecking } = useChainValidation('base');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    // Check chain first
    if (!isCorrectChain) {
      setError(`Please switch to ${chainName} network to deposit`);
      return;
    }

    const depositAmount = parseFloat(amount);
    
    // Validation
    if (isNaN(depositAmount) || depositAmount <= 0) {
      setError('Please enter a valid amount');
      return;
    }

    if (depositAmount > DEPOSIT_CAP) {
      setError(`Maximum deposit is ${formatUSDC(DEPOSIT_CAP)} during beta`);
      return;
    }

    setIsLoading(true);
    try {
      // Re-check balance at time of deposit to prevent race conditions
      const currentBalance = userPosition?.balance || 0;
      if (currentBalance + depositAmount > DEPOSIT_CAP) {
        const remainingCap = Math.max(0, DEPOSIT_CAP - currentBalance);
        setError(`You can only deposit ${formatUSDC(remainingCap)} more (${formatUSDC(DEPOSIT_CAP)} total cap)`);
        setIsLoading(false);
        return;
      }

      await deposit(depositAmount);
      onSuccess();
      setAmount('');
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to deposit');
    } finally {
      setIsLoading(false);
    }
  };

  const handleMax = () => {
    const currentBalance = userPosition?.balance || 0;
    const maxDeposit = Math.max(0, DEPOSIT_CAP - currentBalance);
    setAmount(maxDeposit.toString());
  };

  if (!isOpen) return null;

  const currentBalance = userPosition?.balance || 0;
  const remainingCap = Math.max(0, DEPOSIT_CAP - currentBalance);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-8 max-w-md w-full mx-4">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900">Deposit USDC</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
            disabled={isLoading}
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label htmlFor="amount" className="block text-sm font-medium text-gray-700 mb-2">
              Amount (USDC)
            </label>
            <div className="relative">
              <input
                type="number"
                id="amount"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="w-full px-4 py-2 pr-16 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="0.00"
                step="0.01"
                min="0"
                max={remainingCap}
                required
                disabled={isLoading}
              />
              <button
                type="button"
                onClick={handleMax}
                className="absolute right-2 top-1/2 -translate-y-1/2 px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 rounded-md transition-colors"
                disabled={isLoading || remainingCap === 0}
              >
                MAX
              </button>
            </div>
            <div className="mt-2 flex justify-between text-sm text-gray-600">
              <span>Available to deposit:</span>
              <span className="font-medium">{formatUSDC(remainingCap)}</span>
            </div>
          </div>

          {/* Info Box */}
          <div className="mb-4 p-4 bg-blue-50 rounded-lg">
            <h3 className="text-sm font-medium text-blue-900 mb-1">Beta Deposit Cap</h3>
            <p className="text-xs text-blue-700">
              During our beta phase, deposits are limited to {formatUSDC(DEPOSIT_CAP)} per user for safety.
            </p>
          </div>

          {/* Expected Returns */}
          {amount && parseFloat(amount) > 0 && (
            <div className="mb-4 p-4 bg-gray-50 rounded-lg">
              <h3 className="text-sm font-medium text-gray-900 mb-2">Expected Returns</h3>
              <div className="space-y-1">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Daily (at 10% APY):</span>
                  <span className="font-medium">
                    {formatUSDC(parseFloat(amount) * 0.1 / 365)}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Monthly (at 10% APY):</span>
                  <span className="font-medium">
                    {formatUSDC(parseFloat(amount) * 0.1 / 12)}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Yearly (at 10% APY):</span>
                  <span className="font-medium">
                    {formatUSDC(parseFloat(amount) * 0.1)}
                  </span>
                </div>
              </div>
            </div>
          )}

          {/* Chain Warning */}
          {!isChecking && !isCorrectChain && (
            <div className="mb-4 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
              <p className="text-sm text-yellow-800 mb-2">
                You're on the wrong network. Please switch to {chainName}.
              </p>
              <button
                type="button"
                onClick={switchChain}
                className="text-sm px-3 py-1 bg-yellow-600 text-white rounded hover:bg-yellow-700 transition-colors"
              >
                Switch Network
              </button>
            </div>
          )}

          {error && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
              <p className="text-sm text-red-600">{error}</p>
            </div>
          )}

          <button
            type="submit"
            disabled={isLoading || !amount || parseFloat(amount) <= 0 || !isCorrectChain}
            className="w-full py-3 px-4 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
          >
            {isLoading ? (
              <>
                <LoadingSpinner size="sm" />
                <span>Processing...</span>
              </>
            ) : (
              `Deposit ${amount ? formatUSDC(parseFloat(amount)) : 'USDC'}`
            )}
          </button>

          <p className="mt-4 text-center text-xs text-gray-500">
            No gas fees required • Powered by Circle
          </p>
        </form>
      </div>
    </div>
  );
}