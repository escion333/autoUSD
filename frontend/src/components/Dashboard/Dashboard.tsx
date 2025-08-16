'use client';

import { useState, useEffect } from 'react';
import { useMotherVault } from '@/hooks/useMotherVault';
import { formatUSDC } from '@/lib/utils/format';
import { BalanceCard } from './BalanceCard';
import { APYChart } from './APYChart';
import { AllocationPie } from './AllocationPie';
import { TransactionHistory } from './TransactionHistory';

export function Dashboard() {
  const { userPosition, vaultStats, isLoading, refetch } = useMotherVault();
  const [selectedTimeframe, setSelectedTimeframe] = useState<'24h' | '7d' | '30d'>('7d');

  useEffect(() => {
    // Refresh data every 30 seconds
    const interval = setInterval(() => {
      refetch();
    }, 30000);

    return () => clearInterval(interval);
  }, [refetch]); // Include refetch in dependencies

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-4 md:p-6 lg:p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Your autoUSD Dashboard</h1>
          <p className="text-gray-600 mt-2">
            Earn optimized yields across multiple chains automatically
          </p>
        </div>

        {/* Main Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <BalanceCard
            title="Total Balance"
            amount={userPosition?.balance || 0}
            change={userPosition?.earnings24h || 0}
            changePercent={userPosition?.balance && userPosition.balance > 0 
              ? ((userPosition?.earnings24h || 0) / userPosition.balance) * 100 
              : 0}
          />
          
          <BalanceCard
            title="Total Earnings"
            amount={userPosition?.totalEarnings || 0}
            change={userPosition?.earnings24h || 0}
            changePercent={0}
            hidePercent
          />
          
          <BalanceCard
            title="Current APY"
            amount={vaultStats?.currentAPY || 0}
            isPercentage
            subtitle={`${vaultStats?.totalValueLocked ? formatUSDC(vaultStats.totalValueLocked) : '$0'} TVL`}
          />
          
          <BalanceCard
            title="Next Rebalance"
            amount={0}
            isCountdown
            subtitle={vaultStats?.lastRebalanceTime ? 
              `Last: ${new Date(vaultStats.lastRebalanceTime).toLocaleDateString()}` : 
              'No rebalances yet'
            }
          />
        </div>

        {/* Charts Row */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          {/* APY Chart - 2 columns */}
          <div className="lg:col-span-2">
            <div className="bg-white rounded-xl shadow-sm p-6">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-lg font-semibold text-gray-900">APY Performance</h2>
                <div className="flex gap-2">
                  {(['24h', '7d', '30d'] as const).map((timeframe) => (
                    <button
                      key={timeframe}
                      onClick={() => setSelectedTimeframe(timeframe)}
                      className={`px-3 py-1 text-sm rounded-lg transition-colors ${
                        selectedTimeframe === timeframe
                          ? 'bg-blue-600 text-white'
                          : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                      }`}
                    >
                      {timeframe}
                    </button>
                  ))}
                </div>
              </div>
              <APYChart timeframe={selectedTimeframe} />
            </div>
          </div>

          {/* Allocation Pie - 1 column */}
          <div className="lg:col-span-1">
            <div className="bg-white rounded-xl shadow-sm p-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Chain Allocation</h2>
              <AllocationPie vaultStats={vaultStats} />
              <div className="mt-4 space-y-2">
                {vaultStats?.chainAllocations && vaultStats.chainAllocations.length > 0 ? (
                  vaultStats.chainAllocations.map((allocation) => (
                    <div key={allocation.chainId} className="flex justify-between text-sm">
                      <span className="text-gray-600">{allocation.name}</span>
                      <span className="font-medium">{allocation.apy.toFixed(2)}% APY</span>
                    </div>
                  ))
                ) : (
                  <p className="text-sm text-gray-500 text-center">No chain allocations yet</p>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Transaction History */}
        <div className="bg-white rounded-xl shadow-sm p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Recent Transactions</h2>
          <TransactionHistory />
        </div>
      </div>
    </div>
  );
}