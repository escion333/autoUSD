'use client';

import { useState, useEffect, useCallback } from 'react';
import { getChainConfigs } from '@/types/contracts';

interface ChainValidationState {
  isCorrectChain: boolean;
  currentChainId: number | null;
  expectedChainId: number;
  chainName: string;
  isChecking: boolean;
}

export function useChainValidation(targetChain: string = 'base') {
  const [state, setState] = useState<ChainValidationState>({
    isCorrectChain: false,
    currentChainId: null,
    expectedChainId: 84532, // Base Sepolia default
    chainName: 'Base',
    isChecking: true,
  });

  const checkChain = useCallback(async () => {
    setState(prev => ({ ...prev, isChecking: true }));
    
    try {
      const configs = getChainConfigs();
      const targetConfig = configs[targetChain];
      
      if (!targetConfig) {
        console.error(`Chain config not found for: ${targetChain}`);
        setState(prev => ({
          ...prev,
          isChecking: false,
          isCorrectChain: false,
        }));
        return;
      }

      // In development/mock mode, assume correct chain
      if (process.env.NODE_ENV === 'development') {
        setState({
          isCorrectChain: true,
          currentChainId: targetConfig.chainId,
          expectedChainId: targetConfig.chainId,
          chainName: targetConfig.name,
          isChecking: false,
        });
        return;
      }

      // Check if Web3 provider is available
      if (typeof window !== 'undefined' && window.ethereum) {
        const chainIdHex = await window.ethereum.request({ 
          method: 'eth_chainId' 
        });
        const currentChainId = parseInt(chainIdHex, 16);
        
        setState({
          isCorrectChain: currentChainId === targetConfig.chainId,
          currentChainId,
          expectedChainId: targetConfig.chainId,
          chainName: targetConfig.name,
          isChecking: false,
        });
      } else {
        // No Web3 provider, using mock
        setState({
          isCorrectChain: true,
          currentChainId: targetConfig.chainId,
          expectedChainId: targetConfig.chainId,
          chainName: targetConfig.name,
          isChecking: false,
        });
      }
    } catch (error) {
      console.error('Chain validation failed:', error);
      setState(prev => ({
        ...prev,
        isChecking: false,
        isCorrectChain: false,
      }));
    }
  }, [targetChain]);

  const switchChain = useCallback(async () => {
    if (!window.ethereum) {
      throw new Error('No Web3 provider found');
    }

    const configs = getChainConfigs();
    const targetConfig = configs[targetChain];
    
    if (!targetConfig) {
      throw new Error(`Chain config not found for: ${targetChain}`);
    }

    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${targetConfig.chainId.toString(16)}` }],
      });
      
      // Re-check chain after switch
      await checkChain();
    } catch (error: any) {
      // This error code indicates that the chain has not been added to MetaMask
      if (error.code === 4902) {
        try {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: `0x${targetConfig.chainId.toString(16)}`,
              chainName: targetConfig.name,
              rpcUrls: [targetConfig.rpcUrl],
              blockExplorerUrls: targetConfig.explorerUrl ? [targetConfig.explorerUrl] : [],
              nativeCurrency: {
                name: 'ETH',
                symbol: 'ETH',
                decimals: 18,
              },
            }],
          });
          
          // Re-check chain after adding
          await checkChain();
        } catch (addError) {
          console.error('Failed to add chain:', addError);
          throw new Error(`Failed to add ${targetConfig.name} to wallet`);
        }
      } else {
        throw error;
      }
    }
  }, [targetChain, checkChain]);

  useEffect(() => {
    checkChain();

    // Listen for chain changes
    if (window.ethereum) {
      const handleChainChanged = () => {
        checkChain();
      };

      window.ethereum.on('chainChanged', handleChainChanged);
      return () => {
        window.ethereum.removeListener('chainChanged', handleChainChanged);
      };
    }
  }, [checkChain]);

  return {
    ...state,
    switchChain,
    checkChain,
  };
}

// Declare ethereum on Window interface
declare global {
  interface Window {
    ethereum?: {
      request: (args: { method: string; params?: any[] }) => Promise<any>;
      on: (event: string, handler: (...args: any[]) => void) => void;
      removeListener: (event: string, handler: (...args: any[]) => void) => void;
    };
  }
}