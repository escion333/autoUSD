'use client';

import { useState } from 'react';
import { useMotherVault } from '@/hooks/useMotherVault';
import { useChainValidation } from '@/hooks/useChainValidation';
import { formatUSDC } from '@/lib/utils/format';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { TransactionConfirmModal } from '@/components/TransactionConfirmModal';

interface WithdrawModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export function WithdrawModal({ isOpen, onClose, onSuccess }: WithdrawModalProps) {
  const [amount, setAmount] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [showConfirmation, setShowConfirmation] = useState(false);
  const { withdraw, userPosition, vaultStats } = useMotherVault();
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

    // Show confirmation modal
    setShowConfirmation(true);
  };

  const handleConfirmWithdraw = async () => {
    const withdrawAmount = parseFloat(amount);
    setIsLoading(true);
    
    try {
      await withdraw(withdrawAmount);
      setShowConfirmation(false);
      onSuccess();
      setAmount('');
      onClose();
    } catch (err) {
      throw err; // Let the confirmation modal handle the error
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
    <>
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl p-8 max-w-md w-full mx-4 shadow-lg">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-heading font-semibold text-text-title">Withdraw USDC</h2>
          <button
            onClick={onClose}
            className="text-text-muted hover:text-text-body transition-colors"
            disabled={isLoading}
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          {/* Balance Display */}
          <div className="mb-4 p-4 bg-surface rounded-lg border border-border">
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm text-text-muted">Available Balance</span>
              <span className="text-lg font-bold text-text-title">{formatUSDC(currentBalance)}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-text-muted">Total Earnings</span>
              <span className="text-sm font-medium text-success">+{formatUSDC(totalEarnings)}</span>
            </div>
          </div>

          <div className="mb-4">
            <label htmlFor="amount" className="block text-sm font-medium text-text-title mb-2">
              Amount to Withdraw
            </label>
            <div className="relative">
              <input
                type="number"
                id="amount"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="w-full px-4 py-2 pr-16 border border-border rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent transition-all"
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
                className="absolute right-2 top-1/2 -translate-y-1/2 px-3 py-1 text-sm bg-primary-subtle hover:bg-primary/10 text-primary font-medium rounded-md transition-colors"
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
                className="flex-1 py-2 text-sm bg-mist hover:bg-primary-subtle text-text-body font-medium rounded-lg transition-colors hover:text-primary"
                disabled={isLoading || currentBalance === 0}
              >
                {percentage}%
              </button>
            ))}
          </div>

          {/* Withdrawal Info */}
          {amount && parseFloat(amount) > 0 && (
            <div className="mb-4 p-4 bg-primary-subtle rounded-lg border border-primary/20">
              <h3 className="text-sm font-medium text-primary mb-2">Withdrawal Details</h3>
              <div className="space-y-1">
                <div className="flex justify-between text-sm">
                  <span className="text-text-muted">Withdraw Amount:</span>
                  <span className="font-medium text-text-title">{formatUSDC(parseFloat(amount))}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-muted">Remaining Balance:</span>
                  <span className="font-medium text-text-title">
                    {formatUSDC(currentBalance - parseFloat(amount))}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-muted">Processing Time:</span>
                  <span className="font-medium text-text-title">~2-5 minutes</span>
                </div>
              </div>
            </div>
          )}

          {error && (
            <div className="mb-4 p-3 bg-error-subtle border border-error/20 rounded-lg">
              <p className="text-sm text-error">{error}</p>
            </div>
          )}

          <button
            type="submit"
            disabled={isLoading || !amount || parseFloat(amount) <= 0 || parseFloat(amount) > currentBalance}
            className="w-full py-3 px-4 bg-primary text-white rounded-lg font-medium hover:bg-primary-hover disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-fast flex items-center justify-center gap-2 shadow-sm hover:shadow-md"
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

          <p className="mt-4 text-center text-xs text-text-muted">
            Withdrawals are processed on Base L2 • No gas fees
          </p>
        </form>
      </div>
    </div>

      {/* Transaction Confirmation Modal */}
      <TransactionConfirmModal
        isOpen={showConfirmation}
        onClose={() => setShowConfirmation(false)}
        onConfirm={handleConfirmWithdraw}
        details={{
          type: 'withdraw',
          amount: parseFloat(amount) || 0,
          currentBalance: userPosition?.balance || 0,
          newBalance: (userPosition?.balance || 0) - (parseFloat(amount) || 0),
          apy: vaultStats?.currentAPY || 0,
          estimatedGas: 0, // Gasless
          estimatedTime: '1-3 minutes',
        }}
      />
    </>
  );
}