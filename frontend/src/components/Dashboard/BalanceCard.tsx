'use client';

import { formatUSDC } from '@/lib/utils/format';

interface BalanceCardProps {
  title: string;
  amount: number;
  change?: number;
  changePercent?: number;
  isPercentage?: boolean;
  isCountdown?: boolean;
  subtitle?: string;
  hidePercent?: boolean;
}

export function BalanceCard({
  title,
  amount,
  change = 0,
  changePercent = 0,
  isPercentage = false,
  isCountdown = false,
  subtitle,
  hidePercent = false,
}: BalanceCardProps) {
  const formatAmount = () => {
    if (isPercentage) {
      return `${amount.toFixed(2)}%`;
    }
    if (isCountdown) {
      // Calculate hours until next rebalance (every 24 hours)
      const hoursUntilRebalance = 24 - (new Date().getHours() % 24);
      return `${hoursUntilRebalance}h`;
    }
    return formatUSDC(amount);
  };

  const isPositive = change >= 0;

  return (
    <div className="bg-white rounded-xl shadow-sm p-6">
      <div className="flex justify-between items-start mb-2">
        <h3 className="text-sm font-medium text-gray-500">{title}</h3>
        {change !== 0 && !isCountdown && !hidePercent && (
          <span
            className={`text-xs font-medium px-2 py-1 rounded-full ${
              isPositive 
                ? 'bg-green-50 text-green-600' 
                : 'bg-red-50 text-red-600'
            }`}
          >
            {isPositive ? '+' : ''}{changePercent.toFixed(2)}%
          </span>
        )}
      </div>
      
      <div className="flex items-baseline gap-2">
        <span className="text-2xl font-bold text-gray-900">
          {formatAmount()}
        </span>
        {change !== 0 && !isCountdown && (
          <span className={`text-sm ${isPositive ? 'text-green-600' : 'text-red-600'}`}>
            {isPositive ? '+' : ''}{formatUSDC(change)}
          </span>
        )}
      </div>
      
      {subtitle && (
        <p className="text-xs text-gray-500 mt-2">{subtitle}</p>
      )}
    </div>
  );
}