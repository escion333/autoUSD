'use client';

import { useState, useEffect, useCallback } from 'react';
import { UserPosition, VaultStats } from '@/types/contracts';
import { ReadOnlyMotherVault } from '@/lib/contracts/ReadOnlyMotherVault';
import { CircleWalletVault } from '@/lib/contracts/CircleWalletVault';
import { useAnvilAuth as useCircleAuth } from './useAnvilAuth';
import { getUserFriendlyError } from '@/lib/utils/errors';

export function useMotherVault() {
  const [userPosition, setUserPosition] = useState<UserPosition | null>(null);
  const [vaultStats, setVaultStats] = useState<VaultStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const { user } = useCircleAuth();

  const readOnlyVault = ReadOnlyMotherVault.getInstance();
  const circleWallet = CircleWalletVault.getInstance();

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
      
      // Fetch user position and vault stats in parallel using read-only vault
      const [position, stats] = await Promise.all([
        readOnlyVault.getUserPosition(user.walletAddress as `0x${string}`),
        readOnlyVault.getVaultStats()
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
      // Use Circle wallet for gasless transactions
      // For development: user?.walletId would come from Circle auth
      const walletId = user?.walletId || 'mock-wallet-id';
      const txHash = await circleWallet.deposit(amount, walletId);
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
      // Use Circle wallet for gasless transactions
      // For development: user?.walletId would come from Circle auth
      const walletId = user?.walletId || 'mock-wallet-id';
      const txHash = await circleWallet.withdraw(amount, walletId);
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