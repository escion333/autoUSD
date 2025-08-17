'use client';

import { useState } from 'react';
import { useMotherVault } from '@/hooks/useMotherVault';
import { useChainValidation } from '@/hooks/useChainValidation';
import { formatUSDC } from '@/lib/utils/format';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { TransactionConfirmModal } from '@/components/TransactionConfirmModal';

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
  const [showConfirmation, setShowConfirmation] = useState(false);
  const { deposit, userPosition, vaultStats } = useMotherVault();
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

    // Re-check balance at time of deposit to prevent race conditions
    const currentBalance = userPosition?.balance || 0;
    if (currentBalance + depositAmount > DEPOSIT_CAP) {
      const remainingCap = Math.max(0, DEPOSIT_CAP - currentBalance);
      setError(`You can only deposit ${formatUSDC(remainingCap)} more (${formatUSDC(DEPOSIT_CAP)} total cap)`);
      return;
    }

    // Show confirmation modal
    setShowConfirmation(true);
  };

  const handleConfirmDeposit = async () => {
    const depositAmount = parseFloat(amount);
    setIsLoading(true);
    
    try {
      await deposit(depositAmount);
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
    const maxDeposit = Math.max(0, DEPOSIT_CAP - currentBalance);
    setAmount(maxDeposit.toString());
  };

  if (!isOpen) return null;

  const currentBalance = userPosition?.balance || 0;
  const remainingCap = Math.max(0, DEPOSIT_CAP - currentBalance);

  return (
    <>
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl p-8 max-w-md w-full mx-4 shadow-lg">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-heading font-semibold text-text-title">Deposit USDC</h2>
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
          <div className="mb-4">
            <label htmlFor="amount" className="block text-sm font-medium text-text-title mb-2">
              Amount (USDC)
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
                max={remainingCap}
                required
                disabled={isLoading}
              />
              <button
                type="button"
                onClick={handleMax}
                className="absolute right-2 top-1/2 -translate-y-1/2 px-3 py-1 text-sm bg-primary-subtle hover:bg-primary/10 text-primary font-medium rounded-md transition-colors"
                disabled={isLoading || remainingCap === 0}
              >
                MAX
              </button>
            </div>
            <div className="mt-2 flex justify-between text-sm text-text-muted">
              <span>Available to deposit:</span>
              <span className="font-medium text-text-body">{formatUSDC(remainingCap)}</span>
            </div>
          </div>

          {/* Info Box */}
          <div className="mb-4 p-4 bg-primary-subtle rounded-lg border border-primary/20">
            <h3 className="text-sm font-medium text-primary mb-1">Beta Deposit Cap</h3>
            <p className="text-xs text-text-muted">
              During our beta phase, deposits are limited to {formatUSDC(DEPOSIT_CAP)} per user for safety.
            </p>
          </div>

          {/* Expected Returns */}
          {amount && parseFloat(amount) > 0 && (
            <div className="mb-4 p-4 bg-surface rounded-lg border border-border">
              <h3 className="text-sm font-medium text-text-title mb-2">Expected Returns</h3>
              <div className="space-y-1">
                <div className="flex justify-between text-sm">
                  <span className="text-text-muted">Daily (at 10% APY):</span>
                  <span className="font-medium">
                    {formatUSDC(parseFloat(amount) * 0.1 / 365)}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-muted">Monthly (at 10% APY):</span>
                  <span className="font-medium">
                    {formatUSDC(parseFloat(amount) * 0.1 / 12)}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-muted">Yearly (at 10% APY):</span>
                  <span className="font-medium">
                    {formatUSDC(parseFloat(amount) * 0.1)}
                  </span>
                </div>
              </div>
            </div>
          )}

          {/* Chain Warning */}
          {!isChecking && !isCorrectChain && (
            <div className="mb-4 p-4 bg-warning-subtle border border-warning/20 rounded-lg">
              <p className="text-sm text-warning mb-2">
                You're on the wrong network. Please switch to {chainName}.
              </p>
              <button
                type="button"
                onClick={switchChain}
                className="text-sm px-3 py-1 bg-warning text-white rounded-md hover:bg-warning/90 transition-colors"
              >
                Switch Network
              </button>
            </div>
          )}

          {error && (
            <div className="mb-4 p-3 bg-error-subtle border border-error/20 rounded-lg">
              <p className="text-sm text-error">{error}</p>
            </div>
          )}

          <button
            type="submit"
            disabled={isLoading || !amount || parseFloat(amount) <= 0 || !isCorrectChain}
            className="w-full py-3 px-4 bg-primary text-white rounded-lg font-medium hover:bg-primary-hover disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-fast flex items-center justify-center gap-2 shadow-sm hover:shadow-md"
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

          <p className="mt-4 text-center text-xs text-text-muted">
            No gas fees required • Powered by Circle
          </p>
        </form>
      </div>
    </div>

      {/* Transaction Confirmation Modal */}
      <TransactionConfirmModal
        isOpen={showConfirmation}
        onClose={() => setShowConfirmation(false)}
        onConfirm={handleConfirmDeposit}
        details={{
          type: 'deposit',
          amount: parseFloat(amount) || 0,
          currentBalance: userPosition?.balance || 0,
          newBalance: (userPosition?.balance || 0) + (parseFloat(amount) || 0),
          apy: vaultStats?.currentAPY || 0,
          estimatedGas: 0, // Gasless
          estimatedTime: '30 seconds',
        }}
      />
    </>
  );
}