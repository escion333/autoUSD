'use client';

import { useState } from 'react';
import { useMotherVault } from '@/hooks/useMotherVault';
import { useChainValidation } from '@/hooks/useChainValidation';
import { formatUSDC } from '@/lib/utils/format';
import { LoadingSpinner } from '@/components/LoadingSpinner';

interface WithdrawModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export function WithdrawModal({ isOpen, onClose, onSuccess }: WithdrawModalProps) {
  const [amount, setAmount] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const { withdraw, userPosition } = useMotherVault();
  const { isCorrectChain, chainName, switchChain, isChecking } = useChainValidation('base');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    // Check chain first
    if (!isCorrectChain) {
      setError(`Please switch to ${chainName} network to withdraw`);
      return;
    }

    const withdrawAmount = parseFloat(amount);
    const currentBalance = userPosition?.balance || 0;
    
    // Validation
    if (isNaN(withdrawAmount) || withdrawAmount <= 0) {
      setError('Please enter a valid amount');
      return;
    }

    if (withdrawAmount > currentBalance) {
      setError(`Insufficient balance. You have ${formatUSDC(currentBalance)}`);
      return;
    }

    setIsLoading(true);
    try {
      await withdraw(withdrawAmount);
      onSuccess();
      setAmount('');
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to withdraw');
    } finally {
      setIsLoading(false);
    }
  };

  const handleMax = () => {
    const currentBalance = userPosition?.balance || 0;
    setAmount(currentBalance.toString());
  };

  const handlePercentage = (percentage: number) => {
    const currentBalance = userPosition?.balance || 0;
    setAmount((currentBalance * percentage / 100).toFixed(2));
  };

  if (!isOpen) return null;

  const currentBalance = userPosition?.balance || 0;
  const totalEarnings = userPosition?.totalEarnings || 0;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-8 max-w-md w-full mx-4">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900">Withdraw USDC</h2>
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
          {/* Balance Display */}
          <div className="mb-4 p-4 bg-gray-50 rounded-lg">
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm text-gray-600">Available Balance</span>
              <span className="text-lg font-bold text-gray-900">{formatUSDC(currentBalance)}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-600">Total Earnings</span>
              <span className="text-sm font-medium text-green-600">+{formatUSDC(totalEarnings)}</span>
            </div>
          </div>

          <div className="mb-4">
            <label htmlFor="amount" className="block text-sm font-medium text-gray-700 mb-2">
              Amount to Withdraw
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
                max={currentBalance}
                required
                disabled={isLoading}
              />
              <button
                type="button"
                onClick={handleMax}
                className="absolute right-2 top-1/2 -translate-y-1/2 px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 rounded-md transition-colors"
                disabled={isLoading || currentBalance === 0}
              >
                MAX
              </button>
            </div>
          </div>

          {/* Quick Select Buttons */}
          <div className="mb-4 flex gap-2">
            {[25, 50, 75, 100].map((percentage) => (
              <button
                key={percentage}
                type="button"
                onClick={() => handlePercentage(percentage)}
                className="flex-1 py-2 text-sm bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
                disabled={isLoading || currentBalance === 0}
              >
                {percentage}%
              </button>
            ))}
          </div>

          {/* Withdrawal Info */}
          {amount && parseFloat(amount) > 0 && (
            <div className="mb-4 p-4 bg-blue-50 rounded-lg">
              <h3 className="text-sm font-medium text-blue-900 mb-2">Withdrawal Details</h3>
              <div className="space-y-1">
                <div className="flex justify-between text-sm">
                  <span className="text-blue-700">Withdraw Amount:</span>
                  <span className="font-medium text-blue-900">{formatUSDC(parseFloat(amount))}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-blue-700">Remaining Balance:</span>
                  <span className="font-medium text-blue-900">
                    {formatUSDC(currentBalance - parseFloat(amount))}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-blue-700">Processing Time:</span>
                  <span className="font-medium text-blue-900">~2-5 minutes</span>
                </div>
              </div>
            </div>
          )}

          {error && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
              <p className="text-sm text-red-600">{error}</p>
            </div>
          )}

          <button
            type="submit"
            disabled={isLoading || !amount || parseFloat(amount) <= 0 || parseFloat(amount) > currentBalance}
            className="w-full py-3 px-4 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
          >
            {isLoading ? (
              <>
                <LoadingSpinner size="sm" />
                <span>Processing...</span>
              </>
            ) : (
              `Withdraw ${amount ? formatUSDC(parseFloat(amount)) : 'USDC'}`
            )}
          </button>

          <p className="mt-4 text-center text-xs text-gray-500">
            Withdrawals are processed on Base L2 • No gas fees
          </p>
        </form>
      </div>
    </div>
  );
}