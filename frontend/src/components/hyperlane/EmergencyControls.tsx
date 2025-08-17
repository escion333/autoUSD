'use client';

import React, { useState, useEffect } from 'react';
import { Card } from '../ui/Card';
import { Button } from '../ui/Button';
import { Badge } from '../ui/Badge';
import { formatDistanceToNow } from 'date-fns';
import { 
  AlertTriangle, 
  Shield, 
  PauseCircle, 
  PlayCircle,
  CheckCircle,
  XCircle,
  Loader2,
  AlertCircle,
  RefreshCw,
  ArrowRight,
  Clock
} from 'lucide-react';

export interface ChainPauseStatus {
  chainId: number;
  chainName: string;
  isPaused: boolean;
  pausedAt?: number;
  pausedBy?: string;
  messageId?: string;
  confirmationStatus: 'pending' | 'confirming' | 'confirmed' | 'failed';
  blockNumber?: number;
}

export interface EmergencyMessage {
  id: string;
  type: 'pause' | 'unpause';
  initiatedAt: number;
  initiatedBy: string;
  targetChains: string[];
  propagationStatus: {
    chainName: string;
    status: 'dispatched' | 'delivered' | 'failed';
    messageId: string;
    timestamp: number;
  }[];
  reason?: string;
}

interface EmergencyControlsProps {
  chainStatuses?: ChainPauseStatus[];
  activeEmergency?: EmergencyMessage;
  onPause?: (reason?: string) => Promise<void>;
  onUnpause?: () => Promise<void>;
  onRetryMessage?: (chainName: string, messageId: string) => Promise<void>;
  isOwner?: boolean;
  testMode?: boolean;
}

const CHAIN_ICONS: Record<string, string> = {
  'Base': '🔵',
  'Ethereum': '⟠',
  'Katana': '⚔️',
};

export const EmergencyControls: React.FC<EmergencyControlsProps> = ({
  chainStatuses = [],
  activeEmergency,
  onPause,
  onUnpause,
  onRetryMessage,
  isOwner = false,
  testMode = false,
}) => {
  const [isPausing, setIsPausing] = useState(false);
  const [isUnpausing, setIsUnpausing] = useState(false);
  const [pauseReason, setPauseReason] = useState('');
  const [showReasonInput, setShowReasonInput] = useState(false);
  const [retryingChain, setRetryingChain] = useState<string | null>(null);
  const [testEmergencyActive, setTestEmergencyActive] = useState(false);

  const allChainsPaused = chainStatuses.length > 0 && chainStatuses.every(c => c.isPaused);
  const pauseInProgress = activeEmergency && activeEmergency.type === 'pause' && 
    activeEmergency.propagationStatus.some(s => s.status === 'dispatched');

  const handlePause = async () => {
    if (!onPause) return;
    
    if (!showReasonInput) {
      setShowReasonInput(true);
      return;
    }

    setIsPausing(true);
    try {
      await onPause(pauseReason || 'Emergency pause activated');
      setPauseReason('');
      setShowReasonInput(false);
    } catch (error) {
      console.error('Failed to pause system:', error);
    } finally {
      setIsPausing(false);
    }
  };

  const handleUnpause = async () => {
    if (!onUnpause) return;
    
    setIsUnpausing(true);
    try {
      await onUnpause();
    } catch (error) {
      console.error('Failed to unpause system:', error);
    } finally {
      setIsUnpausing(false);
    }
  };

  const handleRetry = async (chainName: string, messageId: string) => {
    if (!onRetryMessage) return;
    
    setRetryingChain(chainName);
    try {
      await onRetryMessage(chainName, messageId);
    } catch (error) {
      console.error('Failed to retry message:', error);
    } finally {
      setRetryingChain(null);
    }
  };

  const handleTestEmergency = () => {
    if (!testMode) return;
    setTestEmergencyActive(true);
    setTimeout(() => setTestEmergencyActive(false), 5000);
  };

  const getStatusIcon = (status: ChainPauseStatus['confirmationStatus']) => {
    switch (status) {
      case 'pending':
        return <Clock className="w-4 h-4 text-yellow-500" />;
      case 'confirming':
        return <Loader2 className="w-4 h-4 text-blue-500 animate-spin" />;
      case 'confirmed':
        return <CheckCircle className="w-4 h-4 text-green-500" />;
      case 'failed':
        return <XCircle className="w-4 h-4 text-red-500" />;
    }
  };

  const getStatusColor = (status: ChainPauseStatus['confirmationStatus']): 'warning' | 'info' | 'success' | 'danger' => {
    switch (status) {
      case 'pending':
        return 'warning';
      case 'confirming':
        return 'info';
      case 'confirmed':
        return 'success';
      case 'failed':
        return 'danger';
    }
  };

  return (
    <div className="space-y-6">
      {/* Emergency Status Banner */}
      {(allChainsPaused || pauseInProgress || testEmergencyActive) && (
        <Card className="p-4 border-2 border-red-300 bg-red-50">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <AlertTriangle className="w-6 h-6 text-red-600" />
              <div>
                <h3 className="font-semibold text-red-900">
                  {testEmergencyActive ? 'Test Emergency Active' : 
                   pauseInProgress ? 'Emergency Pause in Progress' : 
                   'System Paused'}
                </h3>
                <p className="text-sm text-red-700">
                  {activeEmergency?.reason || 'All operations have been temporarily halted'}
                </p>
              </div>
            </div>
            {allChainsPaused && isOwner && (
              <Button
                variant="primary"
                size="sm"
                onClick={handleUnpause}
                disabled={isUnpausing}
              >
                {isUnpausing ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Unpausing...
                  </>
                ) : (
                  <>
                    <PlayCircle className="w-4 h-4 mr-2" />
                    Resume Operations
                  </>
                )}
              </Button>
            )}
          </div>
        </Card>
      )}

      {/* Emergency Control Panel */}
      {isOwner && (
        <Card className="p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold flex items-center gap-2">
              <Shield className="w-5 h-5 text-gray-600" />
              Emergency Controls
            </h3>
            {testMode && (
              <Button
                variant="secondary"
                size="sm"
                onClick={handleTestEmergency}
              >
                Test Emergency
              </Button>
            )}
          </div>

          {showReasonInput && (
            <div className="mb-4 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Reason for Emergency Pause (Optional)
              </label>
              <input
                type="text"
                value={pauseReason}
                onChange={(e) => setPauseReason(e.target.value)}
                placeholder="e.g., Security vulnerability detected"
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-red-500"
              />
              <div className="flex gap-2 mt-3">
                <Button
                  variant="danger"
                  size="sm"
                  onClick={handlePause}
                  disabled={isPausing}
                >
                  {isPausing ? (
                    <>
                      <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                      Pausing...
                    </>
                  ) : (
                    'Confirm Pause'
                  )}
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    setShowReasonInput(false);
                    setPauseReason('');
                  }}
                >
                  Cancel
                </Button>
              </div>
            </div>
          )}

          {!showReasonInput && !allChainsPaused && (
            <Button
              variant="danger"
              onClick={handlePause}
              disabled={isPausing || pauseInProgress}
              className="w-full"
            >
              {isPausing || pauseInProgress ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  {pauseInProgress ? 'Pause in Progress...' : 'Pausing...'}
                </>
              ) : (
                <>
                  <PauseCircle className="w-4 h-4 mr-2" />
                  Emergency Pause All Chains
                </>
              )}
            </Button>
          )}

          {allChainsPaused && (
            <Button
              variant="success"
              onClick={handleUnpause}
              disabled={isUnpausing}
              className="w-full"
            >
              {isUnpausing ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Unpausing...
                </>
              ) : (
                <>
                  <PlayCircle className="w-4 h-4 mr-2" />
                  Resume All Operations
                </>
              )}
            </Button>
          )}
        </Card>
      )}

      {/* Chain Pause Status */}
      <Card className="p-6">
        <h4 className="font-semibold mb-4">Chain Pause Status</h4>
        <div className="space-y-3">
          {chainStatuses.map((chain) => (
            <div key={chain.chainId} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div className="flex items-center gap-3">
                <span className="text-xl">{CHAIN_ICONS[chain.chainName] || '🔗'}</span>
                <div>
                  <p className="font-medium">{chain.chainName}</p>
                  <p className="text-xs text-gray-500">Chain ID: {chain.chainId}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="flex items-center gap-2">
                  {getStatusIcon(chain.confirmationStatus)}
                  <Badge 
                    variant={chain.isPaused ? 'danger' : 'success'}
                    size="sm"
                  >
                    {chain.isPaused ? 'PAUSED' : 'ACTIVE'}
                  </Badge>
                </div>
                {chain.confirmationStatus === 'failed' && onRetryMessage && (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleRetry(chain.chainName, chain.messageId || '')}
                    disabled={retryingChain === chain.chainName}
                  >
                    {retryingChain === chain.chainName ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <RefreshCw className="w-4 h-4" />
                    )}
                  </Button>
                )}
              </div>
            </div>
          ))}
        </div>
      </Card>

      {/* Message Propagation Status */}
      {activeEmergency && (
        <Card className="p-6">
          <div className="mb-4">
            <h4 className="font-semibold flex items-center gap-2">
              <ArrowRight className="w-5 h-5 text-blue-500" />
              Hyperlane Message Propagation
            </h4>
            <p className="text-sm text-gray-600 mt-1">
              {activeEmergency.type === 'pause' ? 'Pausing' : 'Unpausing'} initiated by {activeEmergency.initiatedBy}
            </p>
            <p className="text-xs text-gray-500">
              {formatDistanceToNow(activeEmergency.initiatedAt, { addSuffix: true })}
            </p>
          </div>

          <div className="space-y-2">
            {activeEmergency.propagationStatus.map((status) => (
              <div key={`${status.chainName}-${status.messageId}`} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                <div className="flex items-center gap-2">
                  <span>{CHAIN_ICONS[status.chainName] || '🔗'}</span>
                  <span className="text-sm font-medium">{status.chainName}</span>
                </div>
                <div className="flex items-center gap-2">
                  {status.status === 'dispatched' && (
                    <Loader2 className="w-4 h-4 text-blue-500 animate-spin" />
                  )}
                  {status.status === 'delivered' && (
                    <CheckCircle className="w-4 h-4 text-green-500" />
                  )}
                  {status.status === 'failed' && (
                    <XCircle className="w-4 h-4 text-red-500" />
                  )}
                  <Badge 
                    variant={
                      status.status === 'delivered' ? 'success' : 
                      status.status === 'failed' ? 'danger' : 'info'
                    }
                    size="sm"
                  >
                    {status.status}
                  </Badge>
                  <span className="text-xs text-gray-500">
                    {formatDistanceToNow(status.timestamp, { addSuffix: true })}
                  </span>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
            <p className="text-sm text-blue-800">
              <AlertCircle className="w-4 h-4 inline mr-1" />
              Messages are being propagated across all chains via Hyperlane. 
              This process typically takes 30-60 seconds.
            </p>
          </div>
        </Card>
      )}
    </div>
  );
};

export default EmergencyControls;