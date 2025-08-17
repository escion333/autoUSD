'use client';

import { useState, useEffect } from 'react';

interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: {
    email: string;
    walletAddress?: string;
    walletId?: string; // Circle wallet ID for transactions
  } | null;
}

export function useAnvilAuth() {
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    isLoading: true,
    user: null,
  });

  // Auto-authenticate with Anvil test account for development
  useEffect(() => {
    const checkSession = async () => {
      try {
        console.log('🔐 AnvilAuth: Auto-authenticating for development...');
        
        // Check if we have a saved session or auto-authenticate for Anvil testing
        const testUser = {
          email: 'test@anvil.local',
          walletAddress: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // First Anvil account
          walletId: 'anvil-test-wallet-id', // Mock Circle wallet ID
        };

        console.log('🔐 AnvilAuth: Setting authenticated user:', testUser);

        setAuthState({
          isAuthenticated: true,
          isLoading: false,
          user: testUser,
        });
      } catch (error) {
        console.error('❌ AnvilAuth: Authentication failed:', error);
        setAuthState({
          isAuthenticated: false,
          isLoading: false,
          user: null,
        });
      }
    };

    // Simulate loading delay with error handling
    const timeoutId = setTimeout(checkSession, 1000);
    
    // Cleanup timeout on unmount
    return () => clearTimeout(timeoutId);
  }, []);

  const login = async (email: string) => {
    try {
      console.log('🔐 AnvilAuth: Login attempt for:', email);
      
      // Validate email input
      if (!email || !email.includes('@')) {
        throw new Error('Valid email address is required');
      }
      
      // For Anvil testing, immediately authenticate with test account
      setAuthState({
        isAuthenticated: true,
        isLoading: false,
        user: {
          email,
          walletAddress: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
          walletId: 'anvil-test-wallet-id',
        },
      });
      
      console.log('✅ AnvilAuth: Login successful for:', email);
      return true;
    } catch (error) {
      console.error('❌ AnvilAuth: Login failed:', error);
      throw error;
    }
  };

  const logout = () => {
    setAuthState({
      isAuthenticated: false,
      isLoading: false,
      user: null,
    });
  };

  return {
    ...authState,
    login,
    logout,
    verifyOtp: () => Promise.resolve(true),
    resendOtp: () => Promise.resolve(true),
    pendingEmail: '',
    isVerifying: false,
  };
}