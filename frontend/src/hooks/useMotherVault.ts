'use client';

import { useState, useEffect, useCallback } from 'react';
import { UserPosition, VaultStats } from '@/types/contracts';
import { MockMotherVault } from '@/lib/mocks/MockMotherVault';
import { useCircleAuth } from './useCircleAuth';
import { getUserFriendlyError } from '@/lib/utils/errors';

export function useMotherVault() {
  const [userPosition, setUserPosition] = useState<UserPosition | null>(null);
  const [vaultStats, setVaultStats] = useState<VaultStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const { user } = useCircleAuth();

  const mockVault = MockMotherVault.getInstance();

  const fetchData = useCallback(async () => {
    if (!user?.walletAddress) {
      setUserPosition(null);
      setVaultStats(null);
      setIsLoading(false);
      setError(null);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);
      
      // Fetch user position and vault stats in parallel
      const [position, stats] = await Promise.all([
        mockVault.getUserPosition(user.walletAddress as `0x${string}`),
        mockVault.getVaultStats()
      ]);
      
      setUserPosition(position);
      setVaultStats(stats);
    } catch (err) {
      console.error('Failed to fetch vault data:', err);
      const errorObj = err instanceof Error ? err : new Error('Failed to fetch vault data');
      setError(errorObj);
      // Don't clear data on error to allow retry with existing data visible
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
      // Convert amount to BigInt (assuming 6 decimals for USDC)
      const amountBigInt = BigInt(Math.floor(amount * 1e6));
      const txHash = await mockVault.deposit(amountBigInt, user.walletAddress as `0x${string}`);
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
      // Convert amount to BigInt (assuming 6 decimals for USDC)
      const amountBigInt = BigInt(Math.floor(amount * 1e6));
      const txHash = await mockVault.withdraw(amountBigInt, user.walletAddress as `0x${string}`, user.walletAddress as `0x${string}`);
      await fetchData(); // Refresh data after withdrawal
      return txHash;
    } catch (err) {
      console.error('Withdraw failed:', err);
      const message = getUserFriendlyError(err);
      throw new Error(message);
    }
  }, [user?.walletAddress, fetchData]);

  return {
    userPosition,
    vaultStats,
    isLoading,
    error,
    deposit,
    withdraw,
    refetch: fetchData,
  };
}