'use client';

import React, { useState, useEffect } from 'react';
import { Card } from '../ui/Card';
import { Badge } from '../ui/Badge';
import { Stat } from '../ui/Stat';
import { formatDistanceToNow } from 'date-fns';
import { 
  Activity, 
  CheckCircle, 
  AlertCircle, 
  RefreshCw, 
  TrendingUp,
  TrendingDown,
  Zap,
  Shield,
  Link,
  Loader2
} from 'lucide-react';

export interface ChainStatus {
  chainId: number;
  name: string;
  type: 'mother' | 'child';
  isConnected: boolean;
  lastSync: number;
  blockNumber: number;
  health: 'healthy' | 'degraded' | 'offline';
  metrics?: {
    tvl: string;
    apy: number;
    utilizationRate: number;
  };
}

export interface RebalancingStatus {
  isActive: boolean;
  progress: number;
  stage: 'idle' | 'calculating' | 'executing' | 'confirming' | 'complete';
  estimatedTime?: number;
  fromChain?: string;
  toChain?: string;
  amount?: string;
  reason?: string;
}

export interface VaultAPY {
  chainName: string;
  currentAPY: number;
  previousAPY: number;
  lastUpdated: number;
  trend: 'up' | 'down' | 'stable';
}

interface CrossChainStatusProps {
  chains?: ChainStatus[];
  rebalancingStatus?: RebalancingStatus;
  vaultAPYs?: VaultAPY[];
  onRefresh?: () => void;
  autoRefresh?: boolean;
  refreshInterval?: number;
}

const getHealthColor = (health: ChainStatus['health']): 'positive' | 'warning' | 'error' => {
  switch (health) {
    case 'healthy':
      return 'positive';
    case 'degraded':
      return 'warning';
    case 'offline':
      return 'error';
  }
};

const getHealthIcon = (health: ChainStatus['health']) => {
  switch (health) {
    case 'healthy':
      return <CheckCircle className="w-4 h-4 text-green-500" />;
    case 'degraded':
      return <AlertCircle className="w-4 h-4 text-yellow-500" />;
    case 'offline':
      return <AlertCircle className="w-4 h-4 text-red-500" />;
  }
};

const CHAIN_ICONS: Record<string, string> = {
  'Base': '🔵',
  'Ethereum': '⟠',
  'Katana': '⚔️',
};

export const CrossChainStatus: React.FC<CrossChainStatusProps> = ({
  chains = [],
  rebalancingStatus,
  vaultAPYs = [],
  onRefresh,
  autoRefresh = true,
  refreshInterval = 15000,
}) => {
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [lastRefresh, setLastRefresh] = useState<Date>(new Date());

  const handleRefresh = async () => {
    setIsRefreshing(true);
    setLastRefresh(new Date());
    
    if (onRefresh) {
      try {
        await onRefresh();
      } catch (error) {
        console.error('Failed to refresh chain status:', error);
      } finally {
        setIsRefreshing(false);
      }
    } else {
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    if (!autoRefresh || !onRefresh) return;

    const interval = setInterval(() => {
      handleRefresh();
    }, refreshInterval);

    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoRefresh, refreshInterval, onRefresh]);

  const getRebalancingStageColor = (stage: RebalancingStatus['stage']): 'neutral' | 'primary' | 'warning' | 'positive' => {
    switch (stage) {
      case 'idle':
        return 'neutral';
      case 'calculating':
        return 'primary';
      case 'executing':
      case 'confirming':
        return 'warning';
      case 'complete':
        return 'positive';
      default:
        return 'neutral';
    }
  };

  const formatAPY = (apy: number) => {
    return `${apy.toFixed(2)}%`;
  };

  const getAPYTrendIcon = (trend: VaultAPY['trend']) => {
    switch (trend) {
      case 'up':
        return <TrendingUp className="w-4 h-4 text-green-500" />;
      case 'down':
        return <TrendingDown className="w-4 h-4 text-red-500" />;
      default:
        return <Activity className="w-4 h-4 text-gray-500" />;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold">Cross-Chain Status</h3>
        <div className="flex items-center gap-3">
          <span className="text-sm text-gray-500">
            Last sync: {formatDistanceToNow(lastRefresh, { addSuffix: true })}
          </span>
          <button
            onClick={handleRefresh}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
            disabled={isRefreshing}
          >
            <RefreshCw className={`w-4 h-4 ${isRefreshing ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Chain Status Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {chains.map((chain) => (
          <Card key={chain.chainId} className="p-4">
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-center gap-2">
                <span className="text-xl">{CHAIN_ICONS[chain.name] || '🔗'}</span>
                <div>
                  <h4 className="font-medium">{chain.name}</h4>
                  <p className="text-xs text-gray-500">Chain ID: {chain.chainId}</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {getHealthIcon(chain.health)}
                <Badge variant={getHealthColor(chain.health)} size="sm">
                  {chain.health}
                </Badge>
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-500">Connection:</span>
                <div className="flex items-center gap-1">
                  {chain.isConnected ? (
                    <>
                      <Link className="w-3 h-3 text-green-500" />
                      <span className="text-green-600 font-medium">Connected</span>
                    </>
                  ) : (
                    <>
                      <AlertCircle className="w-3 h-3 text-red-500" />
                      <span className="text-red-600 font-medium">Disconnected</span>
                    </>
                  )}
                </div>
              </div>

              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-500">Block:</span>
                <span className="font-mono text-xs">{chain.blockNumber.toLocaleString()}</span>
              </div>

              {chain.metrics && (
                <>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-500">TVL:</span>
                    <span className="font-medium">{chain.metrics.tvl}</span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-500">APY:</span>
                    <span className="font-medium text-green-600">{formatAPY(chain.metrics.apy)}</span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-500">Utilization:</span>
                    <div className="flex items-center gap-2">
                      <div className="w-20 bg-gray-200 rounded-full h-2">
                        <div 
                          className="bg-blue-500 h-2 rounded-full"
                          style={{ width: `${chain.metrics.utilizationRate}%` }}
                        />
                      </div>
                      <span className="text-xs font-medium">{chain.metrics.utilizationRate}%</span>
                    </div>
                  </div>
                </>
              )}

              <div className="pt-2 border-t border-gray-100">
                <p className="text-xs text-gray-500">
                  Last sync: {formatDistanceToNow(chain.lastSync, { addSuffix: true })}
                </p>
              </div>
            </div>
          </Card>
        ))}
      </div>

      {/* APY Comparison */}
      {vaultAPYs.length > 0 && (
        <Card className="p-6">
          <div className="flex items-center justify-between mb-4">
            <h4 className="font-semibold flex items-center gap-2">
              <TrendingUp className="w-5 h-5 text-blue-500" />
              Vault APY Comparison
            </h4>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {vaultAPYs.map((vault) => (
              <div key={vault.chainName} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex items-center gap-3">
                  <span className="text-lg">{CHAIN_ICONS[vault.chainName] || '🔗'}</span>
                  <div>
                    <p className="font-medium">{vault.chainName}</p>
                    <p className="text-xs text-gray-500">
                      Updated {formatDistanceToNow(vault.lastUpdated, { addSuffix: true })}
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <div className="flex items-center gap-1">
                    <span className="text-lg font-bold text-green-600">{formatAPY(vault.currentAPY)}</span>
                    {getAPYTrendIcon(vault.trend)}
                  </div>
                  <p className="text-xs text-gray-500">
                    was {formatAPY(vault.previousAPY)}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Rebalancing Status */}
      {rebalancingStatus && rebalancingStatus.isActive && (
        <Card className="p-6 border-2 border-blue-200 bg-blue-50">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <Zap className="w-6 h-6 text-blue-600" />
              <div>
                <h4 className="font-semibold text-blue-900">Rebalancing in Progress</h4>
                <p className="text-sm text-blue-700">{rebalancingStatus.reason || 'Optimizing yield distribution'}</p>
              </div>
            </div>
            <Badge variant={getRebalancingStageColor(rebalancingStatus.stage)} size="md">
              {rebalancingStatus.stage.toUpperCase()}
            </Badge>
          </div>

          {rebalancingStatus.fromChain && rebalancingStatus.toChain && (
            <div className="flex items-center justify-center gap-4 my-4 p-4 bg-white rounded-lg">
              <div className="text-center">
                <span className="text-2xl">{CHAIN_ICONS[rebalancingStatus.fromChain] || '🔗'}</span>
                <p className="text-sm font-medium mt-1">{rebalancingStatus.fromChain}</p>
              </div>
              <div className="flex flex-col items-center">
                <RefreshCw className="w-6 h-6 text-blue-600 animate-spin" />
                <p className="text-xs text-gray-600 mt-1">{rebalancingStatus.amount || 'Calculating...'}</p>
              </div>
              <div className="text-center">
                <span className="text-2xl">{CHAIN_ICONS[rebalancingStatus.toChain] || '🔗'}</span>
                <p className="text-sm font-medium mt-1">{rebalancingStatus.toChain}</p>
              </div>
            </div>
          )}

          <div className="space-y-2">
            <div className="flex items-center justify-between text-sm">
              <span className="text-blue-700">Progress:</span>
              <span className="font-medium text-blue-900">{rebalancingStatus.progress}%</span>
            </div>
            <div className="w-full bg-blue-200 rounded-full h-2">
              <div 
                className="bg-blue-600 h-2 rounded-full transition-all duration-500"
                style={{ width: `${rebalancingStatus.progress}%` }}
              />
            </div>
            {rebalancingStatus.estimatedTime && (
              <p className="text-xs text-blue-700 text-center mt-2">
                Estimated completion: {rebalancingStatus.estimatedTime} seconds
              </p>
            )}
          </div>
        </Card>
      )}

      {/* Health Monitoring Summary */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Stat
          label="Total Chains"
          value={chains.length.toString()}
          icon={<Link className="w-5 h-5" />}
        />
        <Stat
          label="Healthy Chains"
          value={chains.filter(c => c.health === 'healthy').length.toString()}
          icon={<Shield className="w-5 h-5" />}
          trend={chains.length > 0 && chains.every(c => c.health === 'healthy') ? 'up' : 'down'}
        />
        <Stat
          label="Average APY"
          value={formatAPY(
            vaultAPYs.reduce((acc, v) => acc + v.currentAPY, 0) / (vaultAPYs.length || 1)
          )}
          icon={<TrendingUp className="w-5 h-5" />}
          trend="up"
        />
      </div>
    </div>
  );
};

export default CrossChainStatus;