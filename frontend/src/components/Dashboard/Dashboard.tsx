'use client';

import { useEffect } from 'react';
import { useMotherVault } from '@/hooks/useMotherVault';
import { APYChart } from './APYChart';
import { TransactionHistory } from './TransactionHistory';
import { DashboardSkeleton } from '@/components/LoadingStates';
import { ErrorAlert } from '@/components/ErrorAlert';

export function Dashboard() {
  const { userPosition, vaultStats, isLoading, error, refetch } = useMotherVault();

  useEffect(() => {
    // Refresh data every 30 seconds
    const interval = setInterval(() => {
      refetch();
    }, 30000);

    return () => clearInterval(interval);
  }, [refetch]); // Include refetch in dependencies

  if (isLoading && !userPosition) {
    return <DashboardSkeleton />;
  }

  if (error && !userPosition) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="max-w-md w-full">
          <ErrorAlert error={error} onRetry={refetch} />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-4 md:p-6 lg:p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header - Simplified for MVP */}
        <div className="mb-8 text-center">
          <h1 className="text-4xl font-bold text-gray-900">
            ${userPosition?.balance ? userPosition.balance.toFixed(2) : '0.00'}
          </h1>
          <p className="text-lg text-green-600 mt-2">
            {userPosition?.earnings24h && userPosition.earnings24h > 0 ? (
              <>+${userPosition.earnings24h.toFixed(2)} today 🎉</>
            ) : (
              'Start earning ~10% per year'
            )}
          </p>
        </div>

        {/* Simplified Stats - MVP */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8 max-w-3xl mx-auto">
          <div className="bg-white rounded-xl shadow-sm p-6 text-center">
            <p className="text-sm text-gray-600 mb-1">This Week</p>
            <p className="text-2xl font-bold text-green-600">
              +${((userPosition?.earnings24h || 0) * 7).toFixed(2)}
            </p>
          </div>
          
          <div className="bg-white rounded-xl shadow-sm p-6 text-center">
            <p className="text-sm text-gray-600 mb-1">Total Earned</p>
            <p className="text-2xl font-bold text-gray-900">
              ${typeof userPosition?.totalEarnings === 'number' 
                ? userPosition.totalEarnings.toFixed(2) 
                : '0.00'}
            </p>
          </div>
          
          <div className="bg-white rounded-xl shadow-sm p-6 text-center">
            <p className="text-sm text-gray-600 mb-1">Annual Rate</p>
            <p className="text-2xl font-bold text-blue-600">
              ~{vaultStats?.currentAPY?.toFixed(0) || '10'}%
            </p>
          </div>
        </div>

        {/* Simple Growth Chart - MVP */}
        <div className="max-w-3xl mx-auto mb-8">
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Your Growth</h2>
            <APYChart timeframe={'7d'} />
          </div>
        </div>

        {/* Transaction History - Simplified */}
        <div className="max-w-3xl mx-auto">
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Recent Activity</h2>
            <TransactionHistory />
          </div>
        </div>
      </div>
    </div>
  );
}