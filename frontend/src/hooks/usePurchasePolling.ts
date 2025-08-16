'use client';

import { useState, useEffect, useCallback, useRef } from 'react';

export interface PurchaseStatus {
  transactionId: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  fromAmount: number;
  toAmount: number;
  fees: {
    fernFee: number;
    networkFee: number;
    totalFee: number;
  };
  destinationAddress?: string;
  transactionHash?: string;
  createdAt: string;
  completedAt?: string;
  isCompleted: boolean;
  isFailed: boolean;
  isPending: boolean;
  estimatedCompletionTime?: string;
  nextSteps: string[];
  paymentInstructions?: string;
}

export interface UsePurchasePollingOptions {
  transactionId?: string;
  customerId?: string;
  enabled?: boolean;
  interval?: number; // milliseconds
  maxRetries?: number;
  onStatusChange?: (status: PurchaseStatus) => void;
  onComplete?: (status: PurchaseStatus) => void;
  onFailed?: (status: PurchaseStatus) => void;
}

export interface UsePurchasePollingReturn {
  status: PurchaseStatus | null;
  isLoading: boolean;
  error: string | null;
  startPolling: () => void;
  stopPolling: () => void;
  checkNow: () => Promise<void>;
  retryCount: number;
}

export function usePurchasePolling({
  transactionId,
  customerId,
  enabled = true,
  interval = 5000, // 5 seconds
  maxRetries = 120, // 10 minutes at 5-second intervals
  onStatusChange,
  onComplete,
  onFailed,
}: UsePurchasePollingOptions): UsePurchasePollingReturn {
  const [status, setStatus] = useState<PurchaseStatus | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState(0);
  const [isPolling, setIsPolling] = useState(false);
  
  const intervalRef = useRef<NodeJS.Timeout | null>(null);
  const mountedRef = useRef(true);
  
  // Cleanup on unmount
  useEffect(() => {
    return () => {
      mountedRef.current = false;
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, []);
  
  const checkStatus = useCallback(async (): Promise<void> => {
    if (!mountedRef.current || (!transactionId && !customerId)) {
      return;
    }
    
    setIsLoading(true);
    setError(null);
    
    try {
      const params = new URLSearchParams();
      if (transactionId) params.set('transactionId', transactionId);
      if (customerId) params.set('customerId', customerId);
      
      const response = await fetch(`/api/fern/purchase-status?${params.toString()}`);
      
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to check status');
      }
      
      const data = await response.json();
      
      // Handle single transaction vs multiple transactions
      const newStatus: PurchaseStatus = data.transactions ? data.transactions[0] : data;
      
      if (!mountedRef.current) return;
      
      // Only update if status actually changed
      const statusChanged = !status || status.status !== newStatus.status;
      
      setStatus(newStatus);
      setRetryCount(prev => prev + 1);
      
      if (statusChanged) {
        console.log('📊 Purchase status changed:', {
          transactionId: newStatus.transactionId,
          oldStatus: status?.status,
          newStatus: newStatus.status,
        });
        
        onStatusChange?.(newStatus);
      }
      
      // Handle terminal states
      if (newStatus.isCompleted) {
        console.log('✅ Purchase completed:', newStatus.transactionId);
        stopPolling();
        onComplete?.(newStatus);
      } else if (newStatus.isFailed) {
        console.log('❌ Purchase failed:', newStatus.transactionId);
        stopPolling();
        onFailed?.(newStatus);
      }
      
    } catch (err: any) {
      console.error('❌ Status check error:', err.message);
      
      if (!mountedRef.current) return;
      
      setError(err.message);
      
      // Stop polling if we've hit max retries
      if (retryCount >= maxRetries) {
        console.log('⏹️ Stopping polling: max retries reached');
        stopPolling();
      }
    } finally {
      if (mountedRef.current) {
        setIsLoading(false);
      }
    }
  }, [transactionId, customerId, status, retryCount, maxRetries, onStatusChange, onComplete, onFailed]);
  
  const startPolling = useCallback(() => {
    if (!enabled || isPolling || (!transactionId && !customerId)) {
      return;
    }
    
    console.log('🔄 Starting purchase status polling:', {
      transactionId,
      customerId,
      interval: `${interval}ms`,
    });
    
    setIsPolling(true);
    setRetryCount(0);
    setError(null);
    
    // Check immediately
    checkStatus();
    
    // Then start interval
    intervalRef.current = setInterval(checkStatus, interval);
  }, [enabled, isPolling, transactionId, customerId, interval, checkStatus]);
  
  const stopPolling = useCallback(() => {
    console.log('⏹️ Stopping purchase status polling');
    
    setIsPolling(false);
    
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);
  
  const checkNow = useCallback(async (): Promise<void> => {
    await checkStatus();
  }, [checkStatus]);
  
  // Auto-start polling when enabled and we have an ID
  useEffect(() => {
    if (enabled && (transactionId || customerId) && !isPolling) {
      // Small delay to allow component to settle
      const timer = setTimeout(startPolling, 100);
      return () => clearTimeout(timer);
    }
  }, [enabled, transactionId, customerId, isPolling, startPolling]);
  
  // Stop polling when disabled
  useEffect(() => {
    if (!enabled && isPolling) {
      stopPolling();
    }
  }, [enabled, isPolling, stopPolling]);
  
  return {
    status,
    isLoading,
    error,
    startPolling,
    stopPolling,
    checkNow,
    retryCount,
  };
}

// Helper hook for polling a specific transaction
export function useTransactionPolling(
  transactionId: string | null,
  options: Omit<UsePurchasePollingOptions, 'transactionId'> = {}
) {
  return usePurchasePolling({
    ...options,
    transactionId: transactionId || undefined,
    enabled: options.enabled !== false && !!transactionId,
  });
}

// Helper hook for polling all customer transactions
export function useCustomerTransactionsPolling(
  customerId: string | null,
  options: Omit<UsePurchasePollingOptions, 'customerId'> = {}
) {
  return usePurchasePolling({
    ...options,
    customerId: customerId || undefined,
    enabled: options.enabled !== false && !!customerId,
  });
}