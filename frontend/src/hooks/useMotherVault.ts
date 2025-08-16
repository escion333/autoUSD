'use client';

import { useState, useEffect, useCallback } from 'react';
import { UserPosition, VaultStats } from '@/types/contracts';
import { MockMotherVault } from '@/lib/mocks/MockMotherVault';
import { useCircleAuth } from './useCircleAuth';

export function useMotherVault() {
  const [userPosition, setUserPosition] = useState<UserPosition | null>(null);
  const [vaultStats, setVaultStats] = useState<VaultStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const { user } = useCircleAuth();

  const mockVault = MockMotherVault.getInstance();

  const fetchData = useCallback(async () => {
    if (!user?.walletAddress) {
      setUserPosition(null);
      setVaultStats(null);
      setIsLoading(false);
      return;
    }

    try {
      setIsLoading(true);
      
      // Fetch user position and vault stats in parallel
      const [position, stats] = await Promise.all([
        mockVault.getUserPosition(user.walletAddress),
        mockVault.getVaultStats()
      ]);
      
      setUserPosition(position);
      setVaultStats(stats);
    } catch (error) {
      console.error('Failed to fetch vault data:', error);
      // Don't clear data on error to allow retry with existing data visible
      // Only clear loading state to allow user to retry
    } finally {
      setIsLoading(false);
    }
  }, [user?.walletAddress]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const deposit = useCallback(async (amount: number): Promise<string> => {
    if (!user?.walletAddress) {
      throw new Error('No wallet connected');
    }
    
    try {
      const txHash = await mockVault.deposit(amount, user.walletAddress);
      await fetchData(); // Refresh data after deposit
      return txHash;
    } catch (error) {
      console.error('Deposit failed:', error);
      throw error;
    }
  }, [user?.walletAddress, fetchData]);

  const withdraw = useCallback(async (amount: number): Promise<string> => {
    if (!user?.walletAddress) {
      throw new Error('No wallet connected');
    }
    
    try {
      const txHash = await mockVault.withdraw(amount, user.walletAddress, user.walletAddress);
      await fetchData(); // Refresh data after withdrawal
      return txHash;
    } catch (error) {
      console.error('Withdraw failed:', error);
      throw error;
    }
  }, [user?.walletAddress, fetchData]);

  return {
    userPosition,
    vaultStats,
    isLoading,
    deposit,
    withdraw,
    refetch: fetchData,
  };
}