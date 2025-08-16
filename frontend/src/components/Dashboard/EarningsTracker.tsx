'use client';

import { useMemo, useState } from 'react';
import { formatUSDC } from '@/lib/utils/format';

interface EarningsData {
  totalEarnings: number;
  dailyEarnings: number;
  weeklyEarnings: number;
  monthlyEarnings: number;
  apy: number;
  projectedAnnualEarnings: number;
}

interface EarningsTrackerProps {
  principal: number;
  currentBalance: number;
  apy: number;
  startDate: Date;
}

export function EarningsTracker({ 
  principal, 
  currentBalance, 
  apy, 
  startDate 
}: EarningsTrackerProps) {
  const [timeframe, setTimeframe] = useState<'24h' | '7d' | '30d' | 'all'>('7d');

  const earnings = useMemo(() => {
    const now = new Date();
    const daysSinceStart = Math.max(1, (now.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24));
    
    // Calculate actual earnings
    const totalEarnings = currentBalance - principal;
    const dailyRate = apy / 365 / 100;
    
    // Calculate earnings for different periods
    const dailyEarnings = currentBalance * dailyRate;
    const weeklyEarnings = currentBalance * dailyRate * 7;
    const monthlyEarnings = currentBalance * dailyRate * 30;
    const projectedAnnualEarnings = currentBalance * (apy / 100);
    
    return {
      totalEarnings,
      dailyEarnings,
      weeklyEarnings,
      monthlyEarnings,
      apy,
      projectedAnnualEarnings,
    };
  }, [principal, currentBalance, apy, startDate]);

  const displayEarnings = useMemo(() => {
    switch (timeframe) {
      case '24h':
        return {
          label: 'Daily Earnings',
          amount: earnings.dailyEarnings,
          percentage: (earnings.dailyEarnings / currentBalance) * 100,
        };
      case '7d':
        return {
          label: 'Weekly Earnings',
          amount: earnings.weeklyEarnings,
          percentage: (earnings.weeklyEarnings / currentBalance) * 100,
        };
      case '30d':
        return {
          label: 'Monthly Earnings',
          amount: earnings.monthlyEarnings,
          percentage: (earnings.monthlyEarnings / currentBalance) * 100,
        };
      case 'all':
        return {
          label: 'Total Earnings',
          amount: earnings.totalEarnings,
          percentage: (earnings.totalEarnings / principal) * 100,
        };
    }
  }, [timeframe, earnings, currentBalance, principal]);

  const getTimeframeMultiplier = () => {
    switch (timeframe) {
      case '24h': return 365;
      case '7d': return 52.14;
      case '30d': return 12;
      case 'all': return 1;
    }
  };

  const annualizedReturn = displayEarnings.percentage * getTimeframeMultiplier();

  return (
    <div className="bg-white rounded-xl shadow-sm p-6">
      <div className="flex justify-between items-start mb-6">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">Earnings Tracker</h3>
          <p className="text-sm text-gray-600 mt-1">Track your yield generation</p>
        </div>
        
        <div className="flex gap-1 bg-gray-100 rounded-lg p-1">
          {(['24h', '7d', '30d', 'all'] as const).map((period) => (
            <button
              key={period}
              onClick={() => setTimeframe(period)}
              className={`px-3 py-1.5 text-sm font-medium rounded-md transition-colors ${
                timeframe === period
                  ? 'bg-white text-blue-600 shadow-sm'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              {period === 'all' ? 'All Time' : period.toUpperCase()}
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-6">
        {/* Main Earnings Display */}
        <div className="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-lg p-4">
          <div className="flex justify-between items-baseline mb-2">
            <span className="text-sm font-medium text-gray-700">{displayEarnings.label}</span>
            <span className={`text-sm font-medium ${
              displayEarnings.amount >= 0 ? 'text-green-600' : 'text-red-600'
            }`}>
              {displayEarnings.amount >= 0 ? '+' : ''}{displayEarnings.percentage.toFixed(2)}%
            </span>
          </div>
          <div className="text-3xl font-bold text-gray-900">
            {displayEarnings.amount >= 0 ? '+' : ''}{formatUSDC(displayEarnings.amount)}
          </div>
          {timeframe !== 'all' && (
            <div className="mt-2 text-xs text-gray-600">
              Annualized: {annualizedReturn.toFixed(2)}% APY
            </div>
          )}
        </div>

        {/* Breakdown */}
        <div className="space-y-3">
          <div className="flex justify-between items-center py-2 border-b border-gray-100">
            <span className="text-sm text-gray-600">Principal</span>
            <span className="text-sm font-medium text-gray-900">{formatUSDC(principal)}</span>
          </div>
          
          <div className="flex justify-between items-center py-2 border-b border-gray-100">
            <span className="text-sm text-gray-600">Current Balance</span>
            <span className="text-sm font-medium text-gray-900">{formatUSDC(currentBalance)}</span>
          </div>
          
          <div className="flex justify-between items-center py-2 border-b border-gray-100">
            <span className="text-sm text-gray-600">Total Earnings</span>
            <span className={`text-sm font-medium ${
              earnings.totalEarnings >= 0 ? 'text-green-600' : 'text-red-600'
            }`}>
              {earnings.totalEarnings >= 0 ? '+' : ''}{formatUSDC(earnings.totalEarnings)}
            </span>
          </div>
          
          <div className="flex justify-between items-center py-2">
            <span className="text-sm text-gray-600">Current APY</span>
            <span className="text-sm font-medium text-blue-600">{apy.toFixed(2)}%</span>
          </div>
        </div>

        {/* Projections */}
        <div className="bg-blue-50 rounded-lg p-4">
          <h4 className="text-sm font-medium text-gray-900 mb-3">Earnings Projections</h4>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-xs text-gray-600 mb-1">Daily</p>
              <p className="text-sm font-semibold text-gray-900">
                +{formatUSDC(earnings.dailyEarnings)}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-600 mb-1">Weekly</p>
              <p className="text-sm font-semibold text-gray-900">
                +{formatUSDC(earnings.weeklyEarnings)}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-600 mb-1">Monthly</p>
              <p className="text-sm font-semibold text-gray-900">
                +{formatUSDC(earnings.monthlyEarnings)}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-600 mb-1">Annual</p>
              <p className="text-sm font-semibold text-gray-900">
                +{formatUSDC(earnings.projectedAnnualEarnings)}
              </p>
            </div>
          </div>
        </div>

        {/* Compound Interest Note */}
        <div className="bg-gray-50 rounded-lg p-3">
          <div className="flex items-start gap-2">
            <svg className="w-4 h-4 text-gray-400 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p className="text-xs text-gray-600">
              Your earnings are automatically compounded. The projections assume the current APY 
              remains constant, but actual yields may vary based on market conditions.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}