'use client';

import { useState, useEffect } from 'react';
import { MockMotherVault } from '@/lib/mocks/MockMotherVault';
import { useCircleAuth } from './useCircleAuth';
import { TransactionStatus } from '@/types/contracts';

export function useTransactionHistory() {
  const [transactions, setTransactions] = useState<TransactionStatus[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const { user } = useCircleAuth();

  useEffect(() => {
    const fetchTransactions = async () => {
      if (!user?.walletAddress) {
        setTransactions([]);
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      try {
        const mockVault = MockMotherVault.getInstance();
        const history = await mockVault.getTransactionHistory(user.walletAddress);
        setTransactions(history);
      } catch (error) {
        console.error('Failed to fetch transaction history:', error);
        setTransactions([]);
      } finally {
        setIsLoading(false);
      }
    };

    fetchTransactions();
  }, [user?.walletAddress]);

  return { transactions, isLoading };
}