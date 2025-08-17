'use client';

import React, { useState } from 'react';
import { 
  HyperlaneMessageTracker, 
  CrossChainStatus, 
  EmergencyControls,
  type HyperlaneMessage,
  type ChainStatus,
  type RebalancingStatus,
  type VaultAPY,
  type ChainPauseStatus,
  type EmergencyMessage
} from '@/components/hyperlane';
import { Card } from '@/components/ui/Card';

const MOCK_MESSAGES: HyperlaneMessage[] = [
  {
    id: '1',
    messageId: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    status: 'delivered',
    origin: {
      chain: 'base-sepolia',
      domain: 84532,
      txHash: '0xabc123def456abc123def456abc123def456abc123def456abc123def456abc1',
      timestamp: Date.now() - 300000,
    },
    destination: {
      chain: 'katana-tatara',
      domain: 129399,
      txHash: '0xdef456abc123def456abc123def456abc123def456abc123def456abc123def4',
      timestamp: Date.now() - 240000,
    },
    sender: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5',
    recipient: '0x5aAeb6053f3E94C9b9A09f33669435E7Ef1BeAed',
    nonce: 1,
    gasPayment: {
      amount: '0.01',
      token: 'ETH',
      txHash: '0x789abc123def456789abc123def456789abc123def456789abc123def456789a',
    },
  },
  {
    id: '2',
    messageId: '0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321',
    status: 'dispatched',
    origin: {
      chain: 'base-sepolia',
      domain: 84532,
      txHash: '0xbcd234efa567bcd234efa567bcd234efa567bcd234efa567bcd234efa567bcd2',
      timestamp: Date.now() - 60000,
    },
    destination: {
      chain: 'ethereum-sepolia',
      domain: 11155111,
    },
    sender: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5',
    recipient: '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199',
    nonce: 2,
    gasPayment: {
      amount: '0.005',
      token: 'ETH',
      txHash: '0x456def789abc456def789abc456def789abc456def789abc456def789abc456d',
    },
  },
  {
    id: '3',
    messageId: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    status: 'failed',
    origin: {
      chain: 'katana-tatara',
      domain: 129399,
      txHash: '0xcde345fab678cde345fab678cde345fab678cde345fab678cde345fab678cde3',
      timestamp: Date.now() - 180000,
    },
    destination: {
      chain: 'base-sepolia',
      domain: 84532,
    },
    sender: '0x5aAeb6053f3E94C9b9A09f33669435E7Ef1BeAed',
    recipient: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5',
    nonce: 3,
    error: 'Insufficient gas payment for destination chain',
    retryCount: 1,
  },
];

const MOCK_CHAINS: ChainStatus[] = [
  {
    chainId: 84532,
    name: 'Base',
    type: 'mother',
    isConnected: true,
    lastSync: Date.now() - 5000,
    blockNumber: 12345678,
    health: 'healthy',
    metrics: {
      tvl: '$2,345,678',
      apy: 8.5,
      utilizationRate: 75,
    },
  },
  {
    chainId: 11155111,
    name: 'Ethereum',
    type: 'child',
    isConnected: true,
    lastSync: Date.now() - 8000,
    blockNumber: 9876543,
    health: 'healthy',
    metrics: {
      tvl: '$1,234,567',
      apy: 6.2,
      utilizationRate: 60,
    },
  },
  {
    chainId: 129399,
    name: 'Katana',
    type: 'child',
    isConnected: true,
    lastSync: Date.now() - 3000,
    blockNumber: 5432109,
    health: 'degraded',
    metrics: {
      tvl: '$567,890',
      apy: 12.3,
      utilizationRate: 85,
    },
  },
];

const MOCK_VAULT_APYS: VaultAPY[] = [
  {
    chainName: 'Base',
    currentAPY: 8.5,
    previousAPY: 7.8,
    lastUpdated: Date.now() - 3600000,
    trend: 'up',
  },
  {
    chainName: 'Ethereum',
    currentAPY: 6.2,
    previousAPY: 6.5,
    lastUpdated: Date.now() - 7200000,
    trend: 'down',
  },
  {
    chainName: 'Katana',
    currentAPY: 12.3,
    previousAPY: 11.9,
    lastUpdated: Date.now() - 1800000,
    trend: 'up',
  },
];

const MOCK_CHAIN_PAUSE_STATUS: ChainPauseStatus[] = [
  {
    chainId: 84532,
    chainName: 'Base',
    isPaused: false,
    confirmationStatus: 'confirmed',
  },
  {
    chainId: 11155111,
    chainName: 'Ethereum',
    isPaused: false,
    confirmationStatus: 'confirmed',
  },
  {
    chainId: 129399,
    chainName: 'Katana',
    isPaused: false,
    confirmationStatus: 'confirmed',
  },
];

export default function HyperlaneDemoPage() {
  const [messages, setMessages] = useState<HyperlaneMessage[]>(MOCK_MESSAGES);
  const [chains, setChains] = useState<ChainStatus[]>(MOCK_CHAINS);
  const [rebalancing, setRebalancing] = useState<RebalancingStatus>({
    isActive: false,
    progress: 0,
    stage: 'idle',
  });
  const [pauseStatuses, setPauseStatuses] = useState<ChainPauseStatus[]>(MOCK_CHAIN_PAUSE_STATUS);
  const [activeEmergency, setActiveEmergency] = useState<EmergencyMessage | undefined>();

  const handleRetryMessage = async (messageId: string) => {
    console.log('Retrying message:', messageId);
    setMessages(prev => 
      prev.map(msg => 
        msg.messageId === messageId 
          ? { ...msg, status: 'pending' as const, retryCount: (msg.retryCount || 0) + 1 }
          : msg
      )
    );
  };

  const handleRefreshChains = async () => {
    console.log('Refreshing chain status...');
    setChains(prev => 
      prev.map(chain => ({
        ...chain,
        lastSync: Date.now(),
        blockNumber: chain.blockNumber + Math.floor(Math.random() * 100),
      }))
    );
  };

  const handleStartRebalancing = () => {
    setRebalancing({
      isActive: true,
      progress: 0,
      stage: 'calculating',
      fromChain: 'Ethereum',
      toChain: 'Katana',
      amount: '100,000 USDC',
      reason: 'APY differential exceeds 5%',
      estimatedTime: 120,
    });

    let progress = 0;
    const interval = setInterval(() => {
      progress += 10;
      if (progress >= 100) {
        setRebalancing({
          isActive: false,
          progress: 100,
          stage: 'complete',
        });
        clearInterval(interval);
      } else {
        setRebalancing(prev => ({
          ...prev,
          progress,
          stage: progress < 30 ? 'calculating' : progress < 70 ? 'executing' : 'confirming',
        }));
      }
    }, 1000);
  };

  const handleEmergencyPause = async (reason?: string) => {
    console.log('Emergency pause initiated:', reason);
    
    const emergency: EmergencyMessage = {
      id: Date.now().toString(),
      type: 'pause',
      initiatedAt: Date.now(),
      initiatedBy: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5',
      targetChains: ['Base', 'Ethereum', 'Katana'],
      propagationStatus: [
        { chainName: 'Base', status: 'dispatched', messageId: '0xabc123', timestamp: Date.now() },
        { chainName: 'Ethereum', status: 'dispatched', messageId: '0xdef456', timestamp: Date.now() },
        { chainName: 'Katana', status: 'dispatched', messageId: '0x789abc', timestamp: Date.now() },
      ],
      reason,
    };
    
    setActiveEmergency(emergency);
    setPauseStatuses(prev => 
      prev.map(status => ({
        ...status,
        confirmationStatus: 'confirming' as const,
      }))
    );

    setTimeout(() => {
      setPauseStatuses(prev => 
        prev.map(status => ({
          ...status,
          isPaused: true,
          pausedAt: Date.now(),
          confirmationStatus: 'confirmed' as const,
        }))
      );
      setActiveEmergency(prev => prev ? {
        ...prev,
        propagationStatus: prev.propagationStatus.map(s => ({
          ...s,
          status: 'delivered' as const,
        }))
      } : undefined);
    }, 3000);
  };

  const handleEmergencyUnpause = async () => {
    console.log('Emergency unpause initiated');
    setPauseStatuses(prev => 
      prev.map(status => ({
        ...status,
        isPaused: false,
        confirmationStatus: 'confirmed' as const,
      }))
    );
    setActiveEmergency(undefined);
  };

  return (
    <div className="container mx-auto p-6 space-y-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Hyperlane UI Components Demo</h1>
        <p className="text-gray-600">
          Interactive demonstration of cross-chain messaging and monitoring components
        </p>
      </div>

      {/* Test Controls */}
      <Card className="p-6 bg-blue-50 border-blue-200">
        <h2 className="text-lg font-semibold mb-4">Demo Controls</h2>
        <div className="flex flex-wrap gap-3">
          <button
            onClick={handleStartRebalancing}
            className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 transition-colors"
            disabled={rebalancing.isActive}
          >
            Start Rebalancing Demo
          </button>
          <button
            onClick={() => {
              const newMessage: HyperlaneMessage = {
                id: Date.now().toString(),
                messageId: `0x${Date.now().toString(16)}${'0'.repeat(48)}`,
                status: 'pending',
                origin: {
                  chain: 'base-sepolia',
                  domain: 84532,
                  txHash: `0x${Date.now().toString(16)}${'0'.repeat(48)}`,
                  timestamp: Date.now(),
                },
                destination: {
                  chain: 'katana-tatara',
                  domain: 129399,
                },
                sender: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5',
                recipient: '0x5aAeb6053f3E94C9b9A09f33669435E7Ef1BeAed',
                nonce: messages.length + 1,
              };
              setMessages(prev => [newMessage, ...prev]);
            }}
            className="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600 transition-colors"
          >
            Add New Message
          </button>
          <button
            onClick={() => {
              setChains(prev => 
                prev.map(chain => 
                  chain.name === 'Katana' 
                    ? { ...chain, health: chain.health === 'healthy' ? 'degraded' : 'healthy' } as ChainStatus
                    : chain
                )
              );
            }}
            className="px-4 py-2 bg-yellow-500 text-white rounded hover:bg-yellow-600 transition-colors"
          >
            Toggle Katana Health
          </button>
        </div>
      </Card>

      {/* Emergency Controls */}
      <div>
        <h2 className="text-2xl font-semibold mb-4">Emergency Controls</h2>
        <EmergencyControls
          chainStatuses={pauseStatuses}
          activeEmergency={activeEmergency}
          onPause={handleEmergencyPause}
          onUnpause={handleEmergencyUnpause}
          isOwner={true}
          testMode={true}
        />
      </div>

      {/* Cross-Chain Status */}
      <div>
        <h2 className="text-2xl font-semibold mb-4">Cross-Chain Status</h2>
        <CrossChainStatus
          chains={chains}
          rebalancingStatus={rebalancing}
          vaultAPYs={MOCK_VAULT_APYS}
          onRefresh={handleRefreshChains}
          autoRefresh={false}
        />
      </div>

      {/* Message Tracker */}
      <div>
        <h2 className="text-2xl font-semibold mb-4">Hyperlane Message Tracker</h2>
        <HyperlaneMessageTracker
          messages={messages}
          onRetry={handleRetryMessage}
          autoRefresh={false}
        />
      </div>
    </div>
  );
}