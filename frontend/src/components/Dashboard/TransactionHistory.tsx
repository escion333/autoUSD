'use client';

import { useTransactionHistory } from '@/hooks/useTransactionHistory';
import { formatUSDC } from '@/lib/utils/format';
import { TransactionStatus } from '@/types/contracts';
import { Button } from '@/components/ui/Button';

const statusConfig = {
  pending: {
    bg: 'bg-warning-subtle',
    text: 'text-warning',
    label: 'Processing',
    icon: '⏳',
  },
  success: {
    bg: 'bg-success-subtle',
    text: 'text-success',
    label: 'Complete',
    icon: '✓',
  },
  failed: {
    bg: 'bg-error-subtle',
    text: 'text-error',
    label: 'Failed',
    icon: '✕',
  },
};

const typeConfig = {
  deposit: {
    icon: '↓',
    label: 'Deposit',
    color: 'text-success',
    bg: 'bg-success-subtle',
  },
  withdraw: {
    icon: '↑',
    label: 'Withdraw',
    color: 'text-primary',
    bg: 'bg-primary-subtle',
  },
  rebalance: {
    icon: '⟲',
    label: 'Auto-Rebalance',
    color: 'text-secondary-hover',
    bg: 'bg-secondary/20',
  },
};

function formatTimeAgo(timestamp: number): string {
  const now = Date.now();
  const diff = now - timestamp;
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);
  
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return `${minutes}m ago`;
  if (hours < 24) return `${hours}h ago`;
  if (days < 7) return `${days}d ago`;
  
  return new Date(timestamp).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: days > 365 ? 'numeric' : undefined,
  });
}

export function TransactionHistory() {
  const { transactions, isLoading } = useTransactionHistory();

  if (isLoading) {
    return (
      <div className="divide-y divide-border">
        {[...Array(3)].map((_, i) => (
          <div key={i} className="p-4 animate-pulse">
            <div className="flex items-center gap-4">
              <div className="w-10 h-10 bg-accent-mist rounded-full"></div>
              <div className="flex-1">
                <div className="h-4 bg-accent-mist rounded w-32 mb-2"></div>
                <div className="h-3 bg-accent-mist rounded w-24"></div>
              </div>
              <div className="text-right">
                <div className="h-4 bg-accent-mist rounded w-20 mb-2"></div>
                <div className="h-3 bg-accent-mist rounded w-16"></div>
              </div>
            </div>
          </div>
        ))}
      </div>
    );
  }

  if (!transactions || transactions.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 px-4">
        <div className="w-16 h-16 bg-accent-mist rounded-full flex items-center justify-center mb-4">
          <svg className="w-8 h-8 text-text-muted" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} 
              d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
          </svg>
        </div>
        <p className="text-text-title font-medium mb-1">No activity yet</p>
        <p className="text-sm text-text-muted text-center mb-4">
          Your transaction history will appear here
        </p>
      </div>
    );
  }

  return (
    <div className="divide-y divide-border">
      {transactions.map((tx) => {
        const config = typeConfig[tx.type];
        const status = statusConfig[tx.status];
        const isRecent = Date.now() - tx.timestamp < 3600000; // Within last hour
        
        return (
          <div
            key={tx.hash}
            className="group flex items-center gap-4 p-4 hover:bg-accent-mist/30 transition-colors"
          >
            {/* Icon */}
            <div className={`relative w-10 h-10 ${config.bg} rounded-full flex items-center justify-center ${config.color} font-bold text-lg flex-shrink-0`}>
              {config.icon}
              {isRecent && tx.status === 'pending' && (
                <div className="absolute -top-1 -right-1 w-3 h-3">
                  <span className="absolute inline-flex h-full w-full rounded-full bg-warning opacity-75 animate-ping"></span>
                  <span className="relative inline-flex rounded-full h-3 w-3 bg-warning"></span>
                </div>
              )}
            </div>
            
            {/* Details */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <p className="font-medium text-text-title">
                  {config.label}
                </p>
                {tx.type !== 'rebalance' && (
                  <span className="font-mono text-text-title">
                    {formatUSDC(Number(tx.amount))}
                  </span>
                )}
              </div>
              <div className="flex items-center gap-2 mt-0.5">
                <p className="text-sm text-text-muted">
                  {formatTimeAgo(tx.timestamp)}
                </p>
                {tx.hash && /^0x[a-fA-F0-9]{64}$/.test(tx.hash) && (
                  <>
                    <span className="text-text-muted">•</span>
                    <a
                      href={`https://basescan.org/tx/${tx.hash}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-sm text-primary hover:text-primary-hover transition-colors"
                      onClick={(e) => e.stopPropagation()}
                    >
                      View tx
                    </a>
                  </>
                )}
              </div>
            </div>
            
            {/* Status */}
            <div className="flex items-center gap-2">
              <span className={`inline-flex items-center gap-1 px-2.5 py-1 text-xs font-medium rounded-full ${status.bg} ${status.text}`}>
                <span className="text-[10px]">{status.icon}</span>
                {status.label}
              </span>
            </div>
          </div>
        );
      })}
      
      {transactions.length >= 5 && (
        <div className="p-4 text-center">
          <button className="text-sm text-primary hover:text-primary-hover font-medium">
            Load more transactions
          </button>
        </div>
      )}
    </div>
  );
}