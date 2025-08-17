'use client';

import { useEffect, useState } from 'react';
import { useMotherVault } from '@/hooks/useMotherVault';
import { APYChart } from './APYChart';
import { TransactionHistory } from './TransactionHistory';
import { DashboardSkeleton } from '@/components/LoadingStates';
import { ErrorAlert } from '@/components/ErrorAlert';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';

interface DashboardProps {
  onDepositClick?: () => void;
}

export function Dashboard({ onDepositClick }: DashboardProps) {
  const { userPosition, vaultStats, isLoading, error, refetch } = useMotherVault();
  const [showDepositCTA, setShowDepositCTA] = useState(false);

  useEffect(() => {
    const interval = setInterval(() => {
      refetch();
    }, 30000);
    return () => clearInterval(interval);
  }, [refetch]);

  useEffect(() => {
    setShowDepositCTA(!userPosition?.balance || userPosition.balance === 0);
  }, [userPosition?.balance]);

  if (isLoading && !userPosition) {
    return <DashboardSkeleton />;
  }

  if (error && !userPosition) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center p-4">
        <div className="max-w-md w-full">
          <ErrorAlert error={error} onRetry={refetch} />
        </div>
      </div>
    );
  }

  const generateSparkline = (trend: 'up' | 'down' | 'flat') => {
    const base = 100;
    if (trend === 'flat') return Array(7).fill(base);
    const modifier = trend === 'up' ? 1 : -1;
    return Array.from({ length: 7 }, (_, i) => base + (i * 2 * modifier) + Math.random() * 5);
  };

  const hasBalance = userPosition?.balance && userPosition.balance > 0;
  const weeklyEarnings = (userPosition?.earnings24h || 0) * 7;
  const totalEarned = typeof userPosition?.totalEarnings === 'number' ? userPosition.totalEarnings : 0;
  const currentAPY = vaultStats?.currentAPY || 10;

  return (
    <div className="min-h-screen bg-gradient-to-b from-background to-accent-mist/30 p-4 md:p-6 lg:p-8">
      <div className="max-w-6xl mx-auto">
        
        {/* Primary Portfolio Section */}
        <div className="mb-8">
          {/* Portfolio Value Card - Emphasized */}
          <Card className="bg-white shadow-lg border-none overflow-hidden mb-6">
            <div className="bg-gradient-to-r from-primary-subtle to-success-subtle/50 p-0.5">
              <CardContent className="bg-white rounded-t-sm p-8 text-center">
                <p className="text-xs font-body font-medium text-text-muted uppercase tracking-wider mb-3">
                  Total Portfolio Value
                </p>
                <h1 className="text-5xl md:text-6xl font-heading font-bold text-text-title mb-4">
                  ${hasBalance ? userPosition.balance.toFixed(2) : '0.00'}
                </h1>
                
                {hasBalance ? (
                  <div className="flex items-center justify-center gap-2">
                    <span className="text-success font-body font-semibold text-lg">
                      +${userPosition.earnings24h?.toFixed(2) || '0.00'}
                    </span>
                    <span className="text-text-muted font-body">earned today</span>
                  </div>
                ) : (
                  <p className="text-text-muted font-body text-base">
                    Ready to start earning ~{currentAPY.toFixed(0)}% APY?
                  </p>
                )}

                {/* Primary CTA for empty state */}
                {showDepositCTA && (
                  <div className="mt-6">
                    <Button
                      onClick={onDepositClick}
                      variant="primary"
                      size="lg"
                      className="px-8 py-3 font-body font-semibold shadow-md hover:shadow-lg transition-all"
                    >
                      Make Your First Deposit
                    </Button>
                    <p className="text-sm font-body text-text-muted mt-3">
                      Start with as little as $10 • Withdraw anytime
                    </p>
                  </div>
                )}
              </CardContent>
            </div>
          </Card>

          {/* Key Metrics - Grouped with hierarchy */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* This Week - Primary metric */}
            <Card className="bg-white border border-border/50 hover:shadow-md transition-shadow">
              <CardContent className="p-5">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <p className="text-xs font-body font-medium text-text-muted uppercase tracking-wider mb-1.5">
                      This Week
                    </p>
                    <p className="text-2xl font-heading font-bold text-text-title">
                      ${weeklyEarnings.toFixed(2)}
                    </p>
                  </div>
                  {hasBalance && weeklyEarnings > 0 ? (
                    <span className="text-xs font-body bg-success-subtle text-success px-2 py-1 rounded-md font-medium">
                      +{((weeklyEarnings / userPosition.balance) * 100).toFixed(1)}%
                    </span>
                  ) : null}
                </div>
                <div className="h-10 mt-2">
                  {/* Mini sparkline placeholder */}
                  <svg className="w-full h-full" viewBox="0 0 100 40" preserveAspectRatio="none">
                    <defs>
                      <linearGradient id="weekGradient" x1="0" y1="0" x2="0" y2="100%">
                        <stop offset="0%" stopColor="#4CA8A1" stopOpacity="0.3" />
                        <stop offset="100%" stopColor="#4CA8A1" stopOpacity="0" />
                      </linearGradient>
                    </defs>
                    <polygon
                      fill="url(#weekGradient)"
                      points={`0,40 ${generateSparkline('up').map((v, i) => `${(i / 6) * 100},${40 - ((v - 95) * 2)}`).join(' ')} 100,40`}
                    />
                    <polyline
                      fill="none"
                      stroke="#4CA8A1"
                      strokeWidth="2"
                      points={generateSparkline('up').map((v, i) => `${(i / 6) * 100},${40 - ((v - 95) * 2)}`).join(' ')}
                    />
                  </svg>
                </div>
              </CardContent>
            </Card>

            {/* Total Earned - Secondary */}
            <Card className="bg-white border border-border/50 hover:shadow-md transition-shadow">
              <CardContent className="p-5">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <p className="text-xs font-body font-medium text-text-muted uppercase tracking-wider mb-1.5">
                      Total Earned
                    </p>
                    <p className="text-2xl font-heading font-bold text-text-title">
                      ${totalEarned.toFixed(2)}
                    </p>
                  </div>
                  {totalEarned > 0 ? (
                    <span className="text-xs font-body text-text-muted">
                      All time
                    </span>
                  ) : null}
                </div>
                <div className="h-10 mt-2">
                  <svg className="w-full h-full" viewBox="0 0 100 40" preserveAspectRatio="none">
                    <defs>
                      <linearGradient id="totalGradient" x1="0" y1="0" x2="0" y2="100%">
                        <stop offset="0%" stopColor="#4CA8A1" stopOpacity="0.3" />
                        <stop offset="100%" stopColor="#4CA8A1" stopOpacity="0" />
                      </linearGradient>
                    </defs>
                    <polygon
                      fill="url(#totalGradient)"
                      points={`0,40 ${generateSparkline('up').map((v, i) => `${(i / 6) * 100},${40 - ((v - 95) * 2)}`).join(' ')} 100,40`}
                    />
                    <polyline
                      fill="none"
                      stroke="#4CA8A1"
                      strokeWidth="2"
                      points={generateSparkline('up').map((v, i) => `${(i / 6) * 100},${40 - ((v - 95) * 2)}`).join(' ')}
                    />
                  </svg>
                </div>
              </CardContent>
            </Card>

            {/* Annual Rate - Tertiary */}
            <Card className="bg-white border border-border/50 hover:shadow-md transition-shadow">
              <CardContent className="p-5">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <p className="text-xs font-body font-medium text-text-muted uppercase tracking-wider mb-1.5">
                      Annual Rate
                    </p>
                    <p className="text-2xl font-heading font-bold text-text-title">
                      ~{currentAPY.toFixed(0)}%
                    </p>
                  </div>
                  <span className="text-xs font-body bg-primary-subtle text-primary px-2 py-1 rounded-md font-medium">
                    Stable
                  </span>
                </div>
                <div className="h-10 mt-2">
                  <svg className="w-full h-full" viewBox="0 0 100 40" preserveAspectRatio="none">
                    <line x1="0" y1="20" x2="100" y2="20" stroke="#D6C7A1" strokeWidth="2" strokeDasharray="2,2" opacity="0.5" />
                    <polyline
                      fill="none"
                      stroke="#D6C7A1"
                      strokeWidth="2"
                      points="0,20 16,19 33,20 50,19 66,20 83,19 100,20"
                    />
                  </svg>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* Growth Chart - Enhanced */}
        <div className="mb-8">
          <Card className="bg-white shadow-md border-none">
            <CardHeader className="border-b border-border/30 px-6 py-4">
              <div className="flex justify-between items-center">
                <div>
                  <CardTitle className="text-lg font-heading font-semibold text-text-title">
                    Portfolio Performance
                  </CardTitle>
                  <p className="text-sm font-body text-text-muted mt-0.5">
                    {hasBalance ? 'Track your daily growth' : 'See how your money could grow'}
                  </p>
                </div>
                <div className="flex gap-1">
                  <button className="text-sm font-body px-3 py-1.5 rounded-md bg-primary-subtle text-primary font-medium transition-colors">
                    7D
                  </button>
                  <button className="text-sm font-body px-3 py-1.5 rounded-md text-text-muted hover:bg-accent-mist transition-colors">
                    30D
                  </button>
                  <button className="text-sm font-body px-3 py-1.5 rounded-md text-text-muted hover:bg-accent-mist transition-colors">
                    All
                  </button>
                </div>
              </div>
            </CardHeader>
            <CardContent className="p-6">
              {hasBalance ? (
                <APYChart timeframe={'7d'} />
              ) : (
                <div className="h-64 flex flex-col items-center justify-center text-center">
                  <div className="mb-4">
                    <svg className="w-14 h-14 text-primary/20" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M16 6l2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6z"/>
                    </svg>
                  </div>
                  <p className="font-body text-text-muted mb-4">
                    Your growth chart will appear here
                  </p>
                  <Button
                    onClick={onDepositClick}
                    variant="primary"
                    size="md"
                    className="font-body"
                  >
                    Start Growing
                  </Button>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Transaction History - Improved */}
        <Card className="bg-white shadow-md border-none">
          <CardHeader className="border-b border-border/30 px-6 py-4">
            <div className="flex justify-between items-center">
              <CardTitle className="text-lg font-heading font-semibold text-text-title">
                Recent Activity
              </CardTitle>
              {hasBalance ? (
                <button className="text-sm font-body text-primary hover:text-primary-hover font-medium transition-colors">
                  View All
                </button>
              ) : null}
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <TransactionHistory />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}