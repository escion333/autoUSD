'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { useCircleAuth } from './useCircleAuth';

export interface KYCStatus {
  customerId: string;
  status: 'pending' | 'verified' | 'rejected' | 'not_started';
  kycLink?: string;
  isVerified: boolean;
  email: string;
  verificationLevel?: 'basic' | 'enhanced';
  limits?: {
    daily: number;
    monthly: number;
  };
  rejectionReason?: string;
  lastChecked: string;
}

export interface UseKYCStatusOptions {
  enabled?: boolean;
  pollInterval?: number; // milliseconds
  maxRetries?: number;
  onStatusChange?: (status: KYCStatus) => void;
  onVerified?: (status: KYCStatus) => void;
  onRejected?: (status: KYCStatus, reason?: string) => void;
}

export interface UseKYCStatusReturn {
  kycStatus: KYCStatus | null;
  isLoading: boolean;
  error: string | null;
  refreshStatus: () => Promise<void>;
  startKYC: () => Promise<string | null>; // Returns KYC link
  isPolling: boolean;
  retryCount: number;
}

export function useKYCStatus({
  enabled = true,
  pollInterval = 30000, // 30 seconds - KYC usually takes longer
  maxRetries = 20, // 10 minutes of polling
  onStatusChange,
  onVerified,
  onRejected,
}: UseKYCStatusOptions = {}): UseKYCStatusReturn {
  const [kycStatus, setKycStatus] = useState<KYCStatus | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isPolling, setIsPolling] = useState(false);
  const [retryCount, setRetryCount] = useState(0);
  
  const { user } = useCircleAuth();
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
  
  const checkKYCStatus = useCallback(async (): Promise<void> => {
    if (!mountedRef.current || !user?.email) {
      return;
    }
    
    setIsLoading(true);
    setError(null);
    
    try {
      const response = await fetch('/api/fern/customer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: user.email }),
      });
      
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to check KYC status');
      }
      
      const data = await response.json();
      
      const newStatus: KYCStatus = {
        customerId: data.customerId,
        status: data.status,
        kycLink: data.kycLink,
        isVerified: data.isVerified,
        email: user.email,
        verificationLevel: data.verificationLevel,
        limits: data.limits,
        rejectionReason: data.rejectionReason,
        lastChecked: new Date().toISOString(),
      };
      
      if (!mountedRef.current) return;
      
      // Check if status changed
      const statusChanged = !kycStatus || kycStatus.status !== newStatus.status;
      
      setKycStatus(newStatus);
      setRetryCount(prev => prev + 1);
      
      if (statusChanged) {
        console.log('🔄 KYC status changed:', {
          email: user.email,
          oldStatus: kycStatus?.status,
          newStatus: newStatus.status,
          isVerified: newStatus.isVerified,
        });
        
        onStatusChange?.(newStatus);
        
        // Handle specific status changes
        if (newStatus.status === 'verified' && newStatus.isVerified) {
          console.log('✅ KYC verification completed!');
          stopPolling();
          onVerified?.(newStatus);
        } else if (newStatus.status === 'rejected') {
          console.log('❌ KYC verification rejected:', newStatus.rejectionReason);
          stopPolling();
          onRejected?.(newStatus, newStatus.rejectionReason);
        }
      }
      
    } catch (err: any) {
      console.error('❌ KYC status check error:', err.message);
      
      if (!mountedRef.current) return;
      
      setError(err.message);
      
      // Stop polling if we've hit max retries
      if (retryCount >= maxRetries) {
        console.log('⏹️ Stopping KYC polling: max retries reached');
        stopPolling();
      }
    } finally {
      if (mountedRef.current) {
        setIsLoading(false);
      }
    }
  }, [user?.email, kycStatus, retryCount, maxRetries, onStatusChange, onVerified, onRejected]);
  
  const startPolling = useCallback(() => {
    if (!enabled || isPolling || !user?.email) {
      return;
    }
    
    console.log('🔄 Starting KYC status polling for:', user.email);
    
    setIsPolling(true);
    setRetryCount(0);
    setError(null);
    
    // Check immediately
    checkKYCStatus();
    
    // Then start interval
    intervalRef.current = setInterval(checkKYCStatus, pollInterval);
  }, [enabled, isPolling, user?.email, checkKYCStatus, pollInterval]);
  
  const stopPolling = useCallback(() => {
    console.log('⏹️ Stopping KYC status polling');
    
    setIsPolling(false);
    
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);
  
  const refreshStatus = useCallback(async (): Promise<void> => {
    await checkKYCStatus();
  }, [checkKYCStatus]);
  
  const startKYC = useCallback(async (): Promise<string | null> => {
    if (!user?.email) {
      throw new Error('User email required to start KYC');
    }
    
    console.log('🚀 Starting KYC process for:', user.email);
    
    try {
      // Get or create customer to ensure KYC link is available
      const response = await fetch('/api/fern/customer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: user.email }),
      });
      
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to get KYC link');
      }
      
      const data = await response.json();
      
      // Update local status
      const newStatus: KYCStatus = {
        customerId: data.customerId,
        status: data.status,
        kycLink: data.kycLink,
        isVerified: data.isVerified,
        email: user.email,
        lastChecked: new Date().toISOString(),
      };
      
      setKycStatus(newStatus);
      
      // Start polling if not already verified
      if (!newStatus.isVerified && !isPolling) {
        startPolling();
      }
      
      return data.kycLink || null;
      
    } catch (err: any) {
      console.error('❌ KYC start error:', err.message);
      setError(err.message);
      throw err;
    }
  }, [user?.email, isPolling, startPolling]);
  
  // Auto-start polling when conditions are met
  useEffect(() => {
    if (enabled && user?.email && !isPolling && kycStatus && !kycStatus.isVerified) {
      // Only auto-start if we have a pending KYC
      if (kycStatus.status === 'pending') {
        const timer = setTimeout(startPolling, 1000);
        return () => clearTimeout(timer);
      }
    }
  }, [enabled, user?.email, isPolling, kycStatus, startPolling]);
  
  // Initial load when user is available
  useEffect(() => {
    if (enabled && user?.email && !kycStatus && !isLoading) {
      checkKYCStatus();
    }
  }, [enabled, user?.email, kycStatus, isLoading, checkKYCStatus]);
  
  // Stop polling when disabled
  useEffect(() => {
    if (!enabled && isPolling) {
      stopPolling();
    }
  }, [enabled, isPolling, stopPolling]);
  
  return {
    kycStatus,
    isLoading,
    error,
    refreshStatus,
    startKYC,
    isPolling,
    retryCount,
  };
}