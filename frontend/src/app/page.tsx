'use client';

import { useState } from 'react';
import { useCircleAuth } from '@/hooks/useCircleAuth';
import { AuthModal } from '@/components/Auth/AuthModal';
import { Dashboard } from '@/components/Dashboard/Dashboard';
import { DepositModal } from '@/components/vault/DepositModal';
import { WithdrawModal } from '@/components/vault/WithdrawModal';
import { OnrampModal } from '@/components/onramp/OnrampModal';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { ModalErrorBoundary } from '@/components/ModalErrorBoundary';
import { LoadingSpinner } from '@/components/LoadingSpinner';

export default function Home() {
  const { isAuthenticated, isLoading, user, logout } = useCircleAuth();
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [depositModalOpen, setDepositModalOpen] = useState(false);
  const [withdrawModalOpen, setWithdrawModalOpen] = useState(false);
  const [onrampModalOpen, setOnrampModalOpen] = useState(false);

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading autoUSD..." />;
  }

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="text-center py-16">
            <h1 className="text-5xl font-bold text-gray-900 mb-4">
              autoUSD
            </h1>
            <p className="text-xl text-gray-600 mb-8">
              Cross-chain USDC yield optimizer with automated rebalancing
            </p>
            <button
              onClick={() => setAuthModalOpen(true)}
              className="px-8 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors"
            >
              Get Started
            </button>
          </div>

          <div className="grid md:grid-cols-3 gap-8 mt-16">
            <div className="text-center">
              <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <h3 className="text-lg font-semibold mb-2">Optimized Yields</h3>
              <p className="text-gray-600">Automatically earn the best yields across multiple L2 networks</p>
            </div>

            <div className="text-center">
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <h3 className="text-lg font-semibold mb-2">No Gas Fees</h3>
              <p className="text-gray-600">Gasless transactions powered by Circle's Paymaster</p>
            </div>

            <div className="text-center">
              <div className="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
              </div>
              <h3 className="text-lg font-semibold mb-2">Auto-Rebalancing</h3>
              <p className="text-gray-600">Smart rebalancing when APY differential exceeds 5%</p>
            </div>
          </div>
        </div>

        <ModalErrorBoundary>
          <AuthModal
            isOpen={authModalOpen}
            onClose={() => setAuthModalOpen(false)}
            onSuccess={() => setAuthModalOpen(false)}
          />
        </ModalErrorBoundary>
      </div>
    );
  }

  return (
    <ErrorBoundary>
      <div className="min-h-screen bg-gray-50">
        {/* Header */}
        <header className="bg-white shadow-sm">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex justify-between items-center">
              <h1 className="text-2xl font-bold text-gray-900">autoUSD</h1>
              <div className="flex items-center gap-4">
                <button
                  onClick={() => setOnrampModalOpen(true)}
                  className="px-4 py-2 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 transition-colors"
                >
                  Buy USDC
                </button>
                <button
                  onClick={() => setDepositModalOpen(true)}
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors"
                >
                  Deposit
                </button>
                <button
                  onClick={() => setWithdrawModalOpen(true)}
                  className="px-4 py-2 bg-gray-600 text-white rounded-lg font-medium hover:bg-gray-700 transition-colors"
                >
                  Withdraw
                </button>
                <div className="flex items-center gap-2">
                  <span className="text-sm text-gray-600">{user?.email}</span>
                  <button
                    onClick={logout}
                    className="text-sm text-gray-500 hover:text-gray-700"
                  >
                    Sign Out
                  </button>
                </div>
              </div>
            </div>
          </div>
        </header>

        {/* Main Content */}
        <Dashboard />

        {/* Modals */}
        <ModalErrorBoundary>
          <DepositModal
            isOpen={depositModalOpen}
            onClose={() => setDepositModalOpen(false)}
            onSuccess={() => setDepositModalOpen(false)}
          />
        </ModalErrorBoundary>
        <ModalErrorBoundary>
          <WithdrawModal
            isOpen={withdrawModalOpen}
            onClose={() => setWithdrawModalOpen(false)}
            onSuccess={() => setWithdrawModalOpen(false)}
          />
        </ModalErrorBoundary>
        <ModalErrorBoundary>
          <OnrampModal
            isOpen={onrampModalOpen}
            onClose={() => setOnrampModalOpen(false)}
            onSuccess={() => setOnrampModalOpen(false)}
          />
        </ModalErrorBoundary>
      </div>
    </ErrorBoundary>
  );
}
