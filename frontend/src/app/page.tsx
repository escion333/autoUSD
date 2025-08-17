'use client';

export const dynamic = 'force-dynamic';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { useAnvilAuth as useCircleAuth } from '@/hooks/useAnvilAuth';
import { AuthModal } from '@/components/Auth/AuthModal';
import { Dashboard } from '@/components/Dashboard/Dashboard';
import { DepositModal } from '@/components/vault/DepositModal';
import { WithdrawModal } from '@/components/vault/WithdrawModal';
import { OnrampModal } from '@/components/onramp/OnrampModal';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { ModalErrorBoundary } from '@/components/ModalErrorBoundary';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { useMotherVault } from '@/hooks/useMotherVault';
import { Button } from '@/components/ui/Button';
import { Card, CardContent } from '@/components/ui/Card';

export default function Home() {
  const { isAuthenticated, isLoading, user, logout } = useCircleAuth();
  const { userPosition } = useMotherVault();
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [depositModalOpen, setDepositModalOpen] = useState(false);
  const [withdrawModalOpen, setWithdrawModalOpen] = useState(false);
  const [onrampModalOpen, setOnrampModalOpen] = useState(false);

  // Auto-close auth modal when authentication succeeds
  useEffect(() => {
    if (isAuthenticated && authModalOpen) {
      setAuthModalOpen(false);
    }
  }, [isAuthenticated, authModalOpen]);

  if (isLoading) {
    return <LoadingSpinner fullScreen message="Loading autoUSD..." />;
  }

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-background">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="text-center py-16">
            <Image
              src="/LOGO.png"
              alt="autoUSD"
              width={160}
              height={48}
              className="mx-auto mb-8"
              priority
            />
            <h1 className="text-5xl font-heading font-bold text-text-title mb-4">
              Grow Your Dollars
            </h1>
            <p className="text-xl text-text-muted mb-8 max-w-2xl mx-auto">
              Earn ~10% per year on your USDC. No fees. Withdraw anytime.
            </p>
            <Button
              onClick={() => setAuthModalOpen(true)}
              variant="primary"
              size="lg"
              pill
            >
              Get Started
            </Button>
          </div>

          <div className="grid md:grid-cols-3 gap-8 mt-16">
            <Card className="text-center p-6">
              <div className="w-16 h-16 bg-primary-subtle rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <h3 className="text-lg font-heading font-semibold text-text-title mb-2">10% Annual Returns</h3>
              <p className="text-text-muted">Your money grows automatically, every day</p>
            </Card>

            <Card className="text-center p-6">
              <div className="w-16 h-16 bg-success-subtle rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <h3 className="text-lg font-heading font-semibold text-text-title mb-2">No Gas Fees</h3>
              <p className="text-text-muted">Gasless transactions powered by Circle's Paymaster</p>
            </Card>

            <Card className="text-center p-6">
              <div className="w-16 h-16 bg-secondary/20 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-secondary-hover" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
              </div>
              <h3 className="text-lg font-heading font-semibold text-text-title mb-2">100% Your Money</h3>
              <p className="text-text-muted">Withdraw anytime. No penalties or lockups</p>
            </Card>
          </div>
        </div>

        <ModalErrorBoundary>
          <AuthModal
            isOpen={authModalOpen}
            onClose={() => setAuthModalOpen(false)}
            onSuccess={() => {
              setAuthModalOpen(false);
              // Small delay to ensure state updates propagate
              setTimeout(() => {
                window.location.reload();
              }, 100);
            }}
          />
        </ModalErrorBoundary>
      </div>
    );
  }

  return (
    <ErrorBoundary>
      <div className="min-h-screen bg-background">
        {/* Header */}
        <header className="bg-surface border-b border-border">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex justify-between items-center">
              <Image
                src="/LOGO.png"
                alt="autoUSD"
                width={120}
                height={36}
                priority
              />
              <div className="flex items-center gap-4">
                <Button
                  onClick={() => setDepositModalOpen(true)}
                  variant="primary"
                  size="md"
                >
                  Deposit
                </Button>
                {userPosition?.balance && userPosition.balance > 0 ? (
                  <Button
                    onClick={() => setWithdrawModalOpen(true)}
                    variant="ghost"
                    size="md"
                  >
                    Withdraw
                  </Button>
                ) : null}
                <div className="flex items-center gap-2">
                  <span className="text-sm text-text-body">{user?.email}</span>
                  <Button
                    onClick={logout}
                    variant="link"
                    size="sm"
                  >
                    Sign Out
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </header>

        {/* Main Content */}
        <Dashboard onDepositClick={() => setDepositModalOpen(true)} />

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