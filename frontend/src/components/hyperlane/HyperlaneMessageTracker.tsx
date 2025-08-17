'use client';

import React, { useState, useEffect } from 'react';
import { Card } from '../ui/Card';
import { Badge } from '../ui/Badge';
import { Button } from '../ui/Button';
import { formatDistanceToNow } from 'date-fns';
import { ExternalLink, RefreshCw, Clock, CheckCircle, XCircle, AlertCircle, ArrowRight } from 'lucide-react';

export interface HyperlaneMessage {
  id: string;
  messageId: string;
  status: 'pending' | 'dispatched' | 'delivered' | 'failed';
  origin: {
    chain: string;
    domain: number;
    txHash: string;
    timestamp: number;
  };
  destination: {
    chain: string;
    domain: number;
    txHash?: string;
    timestamp?: number;
  };
  sender: string;
  recipient: string;
  nonce: number;
  gasPayment?: {
    amount: string;
    token: string;
    txHash: string;
  };
  retryCount?: number;
  error?: string;
}

interface HyperlaneMessageTrackerProps {
  messages?: HyperlaneMessage[];
  onRetry?: (messageId: string) => Promise<void>;
  autoRefresh?: boolean;
  refreshInterval?: number;
}

const CHAIN_EXPLORERS: Record<string, string> = {
  'base-sepolia': 'https://sepolia.basescan.org',
  'ethereum-sepolia': 'https://sepolia.etherscan.io',
  'katana-tatara': 'https://explorer.katana.network',
};

const HYPERLANE_EXPLORER = 'https://explorer.hyperlane.xyz';

const getStatusIcon = (status: HyperlaneMessage['status']) => {
  switch (status) {
    case 'pending':
      return <Clock className="w-4 h-4 text-yellow-500" />;
    case 'dispatched':
      return <ArrowRight className="w-4 h-4 text-blue-500" />;
    case 'delivered':
      return <CheckCircle className="w-4 h-4 text-green-500" />;
    case 'failed':
      return <XCircle className="w-4 h-4 text-red-500" />;
    default:
      return <AlertCircle className="w-4 h-4 text-gray-500" />;
  }
};

const getStatusColor = (status: HyperlaneMessage['status']): 'warning' | 'primary' | 'positive' | 'error' | 'neutral' => {
  switch (status) {
    case 'pending':
      return 'warning';
    case 'dispatched':
      return 'primary';
    case 'delivered':
      return 'positive';
    case 'failed':
      return 'error';
    default:
      return 'neutral';
  }
};

export const HyperlaneMessageTracker: React.FC<HyperlaneMessageTrackerProps> = ({
  messages = [],
  onRetry,
  autoRefresh = true,
  refreshInterval = 10000,
}) => {
  const [localMessages, setLocalMessages] = useState<HyperlaneMessage[]>(messages);
  const [retryingMessageId, setRetryingMessageId] = useState<string | null>(null);
  const [lastRefresh, setLastRefresh] = useState<Date>(new Date());

  useEffect(() => {
    setLocalMessages(messages);
  }, [messages]);

  useEffect(() => {
    if (!autoRefresh) return;

    const interval = setInterval(() => {
      setLastRefresh(new Date());
    }, refreshInterval);

    return () => clearInterval(interval);
  }, [autoRefresh, refreshInterval]);

  const handleRetry = async (messageId: string) => {
    if (!onRetry) return;

    setRetryingMessageId(messageId);
    try {
      await onRetry(messageId);
      setLocalMessages((prev) =>
        prev.map((msg) =>
          msg.messageId === messageId
            ? { ...msg, status: 'pending', retryCount: (msg.retryCount || 0) + 1 }
            : msg
        )
      );
    } catch (error) {
      console.error('Failed to retry message:', error);
    } finally {
      setRetryingMessageId(null);
    }
  };

  const getExplorerUrl = (chain: string, txHash: string) => {
    const baseUrl = CHAIN_EXPLORERS[chain];
    if (!baseUrl) return null;
    return `${baseUrl}/tx/${txHash}`;
  };

  const getHyperlaneExplorerUrl = (messageId: string) => {
    return `${HYPERLANE_EXPLORER}/message/${messageId}`;
  };

  const formatGasPayment = (gasPayment?: HyperlaneMessage['gasPayment']) => {
    if (!gasPayment) return 'No gas payment';
    return `${gasPayment.amount} ${gasPayment.token}`;
  };

  if (localMessages.length === 0) {
    return (
      <Card className="p-6">
        <div className="text-center text-gray-500">
          <AlertCircle className="w-12 h-12 mx-auto mb-3 text-gray-400" />
          <p className="text-lg font-medium">No Messages</p>
          <p className="text-sm mt-1">Cross-chain messages will appear here</p>
        </div>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold">Hyperlane Messages</h3>
        <div className="flex items-center gap-2 text-sm text-gray-500">
          <Clock className="w-4 h-4" />
          Last updated: {formatDistanceToNow(lastRefresh, { addSuffix: true })}
        </div>
      </div>

      <div className="space-y-3">
        {localMessages.map((message) => (
          <Card key={message.id} className="p-4">
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-center gap-2">
                {getStatusIcon(message.status)}
                <Badge variant={getStatusColor(message.status)}>
                  {message.status.toUpperCase()}
                </Badge>
                {message.retryCount && message.retryCount > 0 && (
                  <Badge variant="neutral" className="text-xs">
                    Retry #{message.retryCount}
                  </Badge>
                )}
              </div>
              <div className="flex items-center gap-2">
                <a
                  href={getHyperlaneExplorerUrl(message.messageId)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-500 hover:text-blue-600 transition-colors"
                >
                  <ExternalLink className="w-4 h-4" />
                </a>
                {message.status === 'failed' && onRetry && (
                  <Button
                    size="sm"
                    variant="secondary"
                    onClick={() => handleRetry(message.messageId)}
                    disabled={retryingMessageId === message.messageId}
                  >
                    {retryingMessageId === message.messageId ? (
                      <RefreshCw className="w-4 h-4 animate-spin" />
                    ) : (
                      <RefreshCw className="w-4 h-4" />
                    )}
                  </Button>
                )}
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-500">Route:</span>
                <div className="flex items-center gap-2">
                  <span className="font-medium">{message.origin.chain}</span>
                  <ArrowRight className="w-4 h-4 text-gray-400" />
                  <span className="font-medium">{message.destination.chain}</span>
                </div>
              </div>

              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-500">Message ID:</span>
                <span className="font-mono text-xs">
                  {message.messageId.slice(0, 10)}...{message.messageId.slice(-8)}
                </span>
              </div>

              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-500">IGP Payment:</span>
                <span className="font-medium">{formatGasPayment(message.gasPayment)}</span>
              </div>

              {message.gasPayment && getExplorerUrl(message.origin.chain, message.gasPayment.txHash) && (
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Gas Payment Tx:</span>
                  <a
                    href={getExplorerUrl(message.origin.chain, message.gasPayment.txHash)!}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-500 hover:text-blue-600 transition-colors flex items-center gap-1"
                  >
                    <span className="font-mono text-xs">
                      {message.gasPayment.txHash.slice(0, 6)}...{message.gasPayment.txHash.slice(-4)}
                    </span>
                    <ExternalLink className="w-3 h-3" />
                  </a>
                </div>
              )}

              {getExplorerUrl(message.origin.chain, message.origin.txHash) ? (
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Origin Tx:</span>
                  <a
                    href={getExplorerUrl(message.origin.chain, message.origin.txHash)!}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-500 hover:text-blue-600 transition-colors flex items-center gap-1"
                  >
                    <span className="font-mono text-xs">
                      {message.origin.txHash.slice(0, 6)}...{message.origin.txHash.slice(-4)}
                    </span>
                    <ExternalLink className="w-3 h-3" />
                  </a>
                </div>
              ) : (
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Origin Tx:</span>
                  <span className="font-mono text-xs">
                    {message.origin.txHash.slice(0, 6)}...{message.origin.txHash.slice(-4)}
                  </span>
                </div>
              )}

              {message.destination.txHash && getExplorerUrl(message.destination.chain, message.destination.txHash) ? (
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Destination Tx:</span>
                  <a
                    href={getExplorerUrl(message.destination.chain, message.destination.txHash)!}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-500 hover:text-blue-600 transition-colors flex items-center gap-1"
                  >
                    <span className="font-mono text-xs">
                      {message.destination.txHash.slice(0, 6)}...{message.destination.txHash.slice(-4)}
                    </span>
                    <ExternalLink className="w-3 h-3" />
                  </a>
                </div>
              ) : message.destination.txHash ? (
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Destination Tx:</span>
                  <span className="font-mono text-xs">
                    {message.destination.txHash.slice(0, 6)}...{message.destination.txHash.slice(-4)}
                  </span>
                </div>
              ) : null}

              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-500">Nonce:</span>
                <span className="font-mono">{message.nonce}</span>
              </div>

              {message.error && (
                <div className="mt-2 p-2 bg-red-50 border border-red-200 rounded-md">
                  <p className="text-sm text-red-600">{message.error}</p>
                </div>
              )}

              <div className="pt-2 border-t border-gray-100">
                <div className="flex items-center justify-between text-xs text-gray-500">
                  <span>Dispatched {formatDistanceToNow(message.origin.timestamp, { addSuffix: true })}</span>
                  {message.destination.timestamp && (
                    <span>Delivered {formatDistanceToNow(message.destination.timestamp, { addSuffix: true })}</span>
                  )}
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
};

export default HyperlaneMessageTracker;