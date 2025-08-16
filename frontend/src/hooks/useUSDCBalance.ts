'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { useCircleAuth } from './useCircleAuth';

export interface USDCBalance {
  amount: number;
  blockchain?: string;
  contractAddress?: string;
  hasBalance: boolean;
  isDepositReady: boolean;
  totalUSDValue: number;
  timestamp: string;
  walletId?: string;
  address?: string;
}

export interface UseUSDCBalanceOptions {
  enabled?: boolean;
  pollInterval?: number; // milliseconds
  walletId?: string;
  address?: string;
  onBalanceIncrease?: (newBalance: USDCBalance, previousBalance: USDCBalance) => void;
  onDepositReady?: (balance: USDCBalance) => void;
  threshold?: number; // Minimum amount to trigger onBalanceIncrease
}

export interface UseUSDCBalanceReturn {
  balance: USDCBalance | null;
  isLoading: boolean;
  error: string | null;
  refreshBalance: () => Promise<void>;
  startMonitoring: () => void;
  stopMonitoring: () => void;
  isMonitoring: boolean;
}

export function useUSDCBalance({
  enabled = true,
  pollInterval = 10000, // 10 seconds
  walletId,
  address,
  onBalanceIncrease,
  onDepositReady,
  threshold = 0.01, // $0.01 minimum change
}: UseUSDCBalanceOptions = {}): UseUSDCBalanceReturn {
  const [balance, setBalance] = useState<USDCBalance | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isMonitoring, setIsMonitoring] = useState(false);
  
  const { user } = useCircleAuth();
  const intervalRef = useRef<NodeJS.Timeout | null>(null);
  const mountedRef = useRef(true);
  const previousBalanceRef = useRef<USDCBalance | null>(null);
  
  // Cleanup on unmount
  useEffect(() => {
    return () => {
      mountedRef.current = false;
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, []);
  
  const checkBalance = useCallback(async (): Promise<void> => {
    if (!mountedRef.current) return;
    
    // Determine what to use for balance check
    const checkWalletId = walletId; // Only use provided walletId
    const checkAddress = address || user?.walletAddress;
    
    if (!checkWalletId && !checkAddress) {
      setError('No wallet available for balance check');
      return;
    }
    
    setIsLoading(true);
    setError(null);
    
    try {
      let response;
      
      if (checkWalletId) {
        // Use GET method with wallet ID
        response = await fetch(`/api/wallet/balance?walletId=${checkWalletId}&currency=USDC`);
      } else {
        // Use POST method with address
        response = await fetch('/api/wallet/balance', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ 
            address: checkAddress,
            currency: 'USDC'
          }),
        });
      }
      
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to check balance');
      }
      
      const data = await response.json();
      
      if (!mountedRef.current) return;
      
      const newBalance: USDCBalance = {
        amount: data.usdc.amount,
        blockchain: data.usdc.blockchain,
        contractAddress: data.usdc.contractAddress,
        hasBalance: data.usdc.hasBalance,
        isDepositReady: data.isDepositReady,
        totalUSDValue: data.totalUSDValue,
        timestamp: data.timestamp,
        walletId: data.walletId,
        address: data.address || checkAddress,
      };
      
      // Check for balance increases
      if (previousBalanceRef.current && onBalanceIncrease) {
        const increase = newBalance.amount - previousBalanceRef.current.amount;
        if (increase > threshold) {
          console.log('📈 USDC balance increased:', {
            from: previousBalanceRef.current.amount,
            to: newBalance.amount,
            increase,
          });
          onBalanceIncrease(newBalance, previousBalanceRef.current);
        }
      }
      
      // Check if deposit is ready
      if (onDepositReady && newBalance.isDepositReady && 
          (!previousBalanceRef.current || !previousBalanceRef.current.isDepositReady)) {
        console.log('✅ USDC deposit ready:', newBalance.amount);
        onDepositReady(newBalance);
      }
      
      setBalance(newBalance);
      previousBalanceRef.current = newBalance;
      
      console.log('💰 USDC balance updated:', {
        amount: newBalance.amount,
        hasBalance: newBalance.hasBalance,
        isDepositReady: newBalance.isDepositReady,
        walletId: newBalance.walletId,
      });
      
    } catch (err: any) {
      console.error('❌ Balance check error:', err.message);
      
      if (!mountedRef.current) return;
      
      setError(err.message);
    } finally {
      if (mountedRef.current) {
        setIsLoading(false);
      }
    }
  }, [
    walletId, 
    address, 
    user?.walletAddress, 
    onBalanceIncrease, 
    onDepositReady, 
    threshold
  ]);
  
  const startMonitoring = useCallback(() => {
    if (!enabled || isMonitoring) return;
    
    console.log('🔄 Starting USDC balance monitoring');
    
    setIsMonitoring(true);
    setError(null);
    
    // Check immediately
    checkBalance();
    
    // Then start interval
    intervalRef.current = setInterval(checkBalance, pollInterval);
  }, [enabled, isMonitoring, checkBalance, pollInterval]);
  
  const stopMonitoring = useCallback(() => {
    console.log('⏹️ Stopping USDC balance monitoring');
    
    setIsMonitoring(false);
    
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);
  
  const refreshBalance = useCallback(async (): Promise<void> => {
    await checkBalance();
  }, [checkBalance]);
  
  // Auto-start monitoring when conditions are met
  useEffect(() => {
    if (enabled && (user?.walletAddress || walletId || address) && !isMonitoring) {
      const timer = setTimeout(startMonitoring, 100);
      return () => clearTimeout(timer);
    }
  }, [enabled, user?.walletAddress, walletId, address, isMonitoring, startMonitoring]);
  
  // Stop monitoring when disabled
  useEffect(() => {
    if (!enabled && isMonitoring) {
      stopMonitoring();
    }
  }, [enabled, isMonitoring, stopMonitoring]);
  
  return {
    balance,
    isLoading,
    error,
    refreshBalance,
    startMonitoring,
    stopMonitoring,
    isMonitoring,
  };
}

// Helper hook for monitoring balance increases (for Fern purchases)
export function useUSDCBalanceMonitor(options: {
  onNewUSDCDetected?: (balance: USDCBalance) => void;
  onDepositReady?: (balance: USDCBalance) => void;
  enabled?: boolean;
} = {}) {
  return useUSDCBalance({
    enabled: options.enabled,
    pollInterval: 5000, // Check every 5 seconds for new USDC
    threshold: 0.50, // Trigger on $0.50+ increases (to avoid noise)
    onBalanceIncrease: options.onNewUSDCDetected,
    onDepositReady: options.onDepositReady,
  });
}