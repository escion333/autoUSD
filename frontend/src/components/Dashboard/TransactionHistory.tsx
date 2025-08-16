'use client';

import { useTransactionHistory } from '@/hooks/useTransactionHistory';
import { formatUSDC } from '@/lib/utils/format';
import { TransactionStatus } from '@/types/contracts';

const statusColors = {
  pending: 'bg-yellow-100 text-yellow-800',
  success: 'bg-green-100 text-green-800',
  failed: 'bg-red-100 text-red-800',
};

const typeIcons = {
  deposit: '↓',
  withdraw: '↑',
  rebalance: '⟲',
};

export function TransactionHistory() {
  const { transactions, isLoading } = useTransactionHistory();

  if (isLoading) {
    return (
      <div className="space-y-3">
        {[...Array(3)].map((_, i) => (
          <div key={i} className="animate-pulse">
            <div className="h-16 bg-gray-100 rounded-lg"></div>
          </div>
        ))}
      </div>
    );
  }

  if (!transactions || transactions.length === 0) {
    return (
      <div className="text-center py-8">
        <p className="text-gray-500">No transactions yet</p>
        <p className="text-sm text-gray-400 mt-1">Your deposits and withdrawals will appear here</p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {transactions.map((tx) => (
        <div
          key={tx.hash}
          className="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
        >
          <div className="flex items-center gap-4">
            <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 font-bold text-lg">
              {typeIcons[tx.type]}
            </div>
            <div>
              <p className="font-medium text-gray-900">
                {tx.type === 'deposit' ? 'Deposited' : tx.type === 'withdraw' ? 'Withdrew' : 'Rebalanced'}
              </p>
              <p className="text-sm text-gray-500">
                {new Date(tx.timestamp).toLocaleString()}
              </p>
            </div>
          </div>
          
          <div className="flex items-center gap-4">
            <div className="text-right">
              <p className="font-medium text-gray-900">
                {tx.type === 'rebalance' ? 'Auto' : formatUSDC(tx.amount)}
              </p>
              {tx.hash && /^0x[a-fA-F0-9]{64}$/.test(tx.hash) && (
                <a
                  href={`https://basescan.org/tx/${tx.hash}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-xs text-blue-600 hover:text-blue-700"
                >
                  View →
                </a>
              )}
            </div>
            <span className={`px-2 py-1 text-xs font-medium rounded-full ${statusColors[tx.status]}`}>
              {tx.status}
            </span>
          </div>
        </div>
      ))}
    </div>
  );
}