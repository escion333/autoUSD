'use client';

import { useState, useEffect, useCallback } from 'react';
import { CircleWalletService } from '@/lib/circle/wallet';
import { useRouter } from 'next/navigation';

interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: {
    email: string;
    walletAddress?: string;
  } | null;
}

export function useCircleAuth() {
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    isLoading: true,
    user: null,
  });
  const [pendingEmail, setPendingEmail] = useState<string>('');
  const [challengeId, setChallengeId] = useState<string>('');
  const [isVerifying, setIsVerifying] = useState(false);
  const [otpAttempts, setOtpAttempts] = useState(0);
  const [lastAttemptTime, setLastAttemptTime] = useState(0);
  const router = useRouter();

  // Check for existing session on mount
  useEffect(() => {
    const checkSession = async () => {
      try {
        const walletService = CircleWalletService.getInstance();
        const currentUser = await walletService.getCurrentUser();
        
        if (currentUser && currentUser.wallets.length > 0) {
          setAuthState({
            isAuthenticated: true,
            isLoading: false,
            user: {
              email: currentUser.email,
              walletAddress: currentUser.wallets[0].address,
            },
          });
        } else {
          setAuthState({
            isAuthenticated: false,
            isLoading: false,
            user: null,
          });
        }
      } catch (error) {
        console.error('Session check failed:', error);
        setAuthState({
          isAuthenticated: false,
          isLoading: false,
          user: null,
        });
      }
    };

    checkSession();
  }, []);

  const login = useCallback(async (email: string) => {
    setPendingEmail(email);
    const walletService = CircleWalletService.getInstance();
    
    // Initialize session and get challenge ID for OTP
    const { challengeId: newChallengeId } = await walletService.initializeSession(email);
    setChallengeId(newChallengeId);
    
    return true;
  }, []);

  const verifyOtp = useCallback(async (otp: string) => {
    if (!pendingEmail || !challengeId) {
      throw new Error('No pending email verification');
    }

    // Prevent duplicate submissions
    if (isVerifying) {
      throw new Error('Verification already in progress');
    }

    // Rate limiting: max 5 attempts per minute
    const now = Date.now();
    const timeSinceLastAttempt = now - lastAttemptTime;
    
    if (otpAttempts >= 5 && timeSinceLastAttempt < 60000) {
      const waitTime = Math.ceil((60000 - timeSinceLastAttempt) / 1000);
      throw new Error(`Too many attempts. Please wait ${waitTime} seconds before trying again.`);
    }
    
    // Reset counter after 1 minute
    if (timeSinceLastAttempt >= 60000) {
      setOtpAttempts(0);
    }

    setIsVerifying(true);
    setOtpAttempts(prev => prev + 1);
    setLastAttemptTime(now);
    
    const walletService = CircleWalletService.getInstance();
    
    try {
      // Verify OTP and get user with wallets
      const user = await walletService.verifyChallenge(challengeId, otp);
      
      // Create wallet if user doesn't have one (with race condition check)
      if (user.wallets.length === 0) {
        // Double-check wallets after potential delay
        const updatedWallets = await walletService.getWallets(user.userId);
        if (updatedWallets.length === 0) {
          const newWallet = await walletService.createWallet(user.userId);
          user.wallets.push(newWallet);
        } else {
          user.wallets = updatedWallets;
        }
      }
      
      setAuthState({
        isAuthenticated: true,
        isLoading: false,
        user: {
          email: user.email,
          walletAddress: user.wallets[0].address,
        },
      });
      
      setPendingEmail('');
      setChallengeId('');
      setOtpAttempts(0); // Reset attempts on successful verification
      setLastAttemptTime(0);
      return true;
    } catch (error) {
      throw new Error('Invalid verification code');
    } finally {
      setIsVerifying(false);
    }
  }, [pendingEmail, challengeId, isVerifying, otpAttempts, lastAttemptTime]);

  const resendOtp = useCallback(async () => {
    if (!pendingEmail) {
      throw new Error('No pending email verification');
    }
    
    const walletService = CircleWalletService.getInstance();
    const { challengeId: newChallengeId } = await walletService.initializeSession(pendingEmail);
    setChallengeId(newChallengeId);
    
    return true;
  }, [pendingEmail]);

  const logout = useCallback(() => {
    const walletService = CircleWalletService.getInstance();
    walletService.logout();
    
    setAuthState({
      isAuthenticated: false,
      isLoading: false,
      user: null,
    });
    
    router.push('/');
  }, [router]);

  return {
    ...authState,
    login,
    verifyOtp,
    resendOtp,
    logout,
  };
}