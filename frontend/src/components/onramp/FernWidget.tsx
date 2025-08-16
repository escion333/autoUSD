'use client';

import { useEffect, useRef } from 'react';
import { useCircleAuth } from '@/hooks/useCircleAuth';

interface FernWidgetProps {
  onPurchaseComplete?: (amount: number, txHash: string) => void;
  defaultAmount?: number;
}

declare global {
  interface Window {
    Fern?: any;
  }
}

export function FernWidget({ onPurchaseComplete, defaultAmount = 100 }: FernWidgetProps) {
  const widgetRef = useRef<HTMLDivElement>(null);
  const { user } = useCircleAuth();

  useEffect(() => {
    if (!user?.walletAddress || !widgetRef.current) return;

    // Load Fern SDK script
    const loadFernScript = () => {
      if (window.Fern) {
        initializeFernWidget();
        return;
      }

      const script = document.createElement('script');
      script.src = 'https://widget.fern.cash/sdk.js';
      script.async = true;
      script.onload = () => {
        initializeFernWidget();
      };
      document.body.appendChild(script);

      return () => {
        document.body.removeChild(script);
      };
    };

    const initializeFernWidget = () => {
      if (!window.Fern || !widgetRef.current) return;

      // Initialize Fern widget with configuration
      const widget = new window.Fern.Widget({
        container: widgetRef.current,
        apiKey: process.env.NEXT_PUBLIC_FERN_API_KEY || 'mock_api_key',
        environment: process.env.NODE_ENV === 'production' ? 'production' : 'sandbox',
        config: {
          // Widget configuration
          defaultCurrency: 'USD',
          defaultCrypto: 'USDC',
          defaultAmount: defaultAmount,
          supportedCryptos: ['USDC'],
          supportedNetworks: ['base'],
          
          // User configuration
          destinationAddress: user.walletAddress,
          userEmail: user.email,
          
          // UI configuration
          theme: 'light',
          primaryColor: '#3B82F6',
          borderRadius: '8px',
          
          // Features
          showKycStatus: true,
          allowRecurringPurchases: false,
          minAmount: 10,
          maxAmount: 100, // Match our deposit cap
          
          // Callbacks
          onSuccess: (data: any) => {
            console.log('Fern purchase successful:', data);
            if (onPurchaseComplete) {
              onPurchaseComplete(data.amount, data.transactionHash);
            }
          },
          onError: (error: any) => {
            console.error('Fern purchase error:', error);
          },
          onClose: () => {
            console.log('Fern widget closed');
          },
        },
      });

      // Mount the widget
      widget.mount();

      // Cleanup function
      return () => {
        widget.unmount();
      };
    };

    const cleanup = loadFernScript();
    return cleanup;
  }, [user?.walletAddress, user?.email, defaultAmount, onPurchaseComplete]);

  if (!user?.walletAddress) {
    return (
      <div className="bg-gray-50 rounded-lg p-8 text-center">
        <p className="text-gray-700">Please sign in to purchase USDC</p>
      </div>
    );
  }

  // For development, show a mock widget
  if (process.env.NODE_ENV === 'development' && !process.env.NEXT_PUBLIC_FERN_API_KEY) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-lg font-semibold mb-4">Buy USDC with Fern</h3>
        
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Amount (USD)
            </label>
            <input
              type="number"
              defaultValue={defaultAmount}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg"
              placeholder="Enter amount"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Payment Method
            </label>
            <select className="w-full px-3 py-2 border border-gray-300 rounded-lg">
              <option>Credit/Debit Card</option>
              <option>Bank Transfer</option>
              <option>Apple Pay</option>
            </select>
          </div>
          
          <div className="bg-blue-50 rounded-lg p-3">
            <div className="flex justify-between text-sm mb-1">
              <span>You pay:</span>
              <span className="font-medium">${defaultAmount}.00 USD</span>
            </div>
            <div className="flex justify-between text-sm">
              <span>You receive:</span>
              <span className="font-medium">{(defaultAmount * 0.98).toFixed(2)} USDC</span>
            </div>
          </div>
          
          <button
            onClick={() => {
              console.log('[Mock] Fern purchase initiated');
              if (onPurchaseComplete) {
                setTimeout(() => {
                  onPurchaseComplete(defaultAmount * 0.98, `0x${Math.random().toString(16).substr(2, 64)}`);
                }, 2000);
              }
            }}
            className="w-full py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors"
          >
            Continue to Payment
          </button>
          
          <p className="text-xs text-gray-700 text-center">
            Mock Fern widget for development • Real widget requires API key
          </p>
        </div>
      </div>
    );
  }

  // Production widget container
  return (
    <div ref={widgetRef} className="fern-widget-container">
      <div className="bg-gray-100 rounded-lg p-8 animate-pulse">
        <div className="h-4 bg-gray-300 rounded w-1/2 mb-4"></div>
        <div className="h-10 bg-gray-300 rounded mb-4"></div>
        <div className="h-10 bg-gray-300 rounded mb-4"></div>
        <div className="h-12 bg-gray-300 rounded"></div>
      </div>
    </div>
  );
}