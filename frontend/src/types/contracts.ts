import { Address, Hex } from 'viem';
import { getEnvConfig } from '@/lib/config/env';

export interface ChildVault {
  domainId: number;
  vaultAddress: Address;
  lastReportTime: bigint;
  deployedAmount: bigint;
  reportedAPY: bigint;
  isActive: boolean;
}

export interface StrategicDeployParams {
  targetChainId: number;
  amount: bigint;
  minAPYDifferential: bigint;
}

export interface IMotherVault {
  // View functions
  USDC(): Promise<Address>;
  depositCap(): Promise<bigint>;
  totalAssets(): Promise<bigint>;
  totalSupply(): Promise<bigint>;
  totalDeployedAssets(): Promise<bigint>;
  balanceOf(account: Address): Promise<bigint>;
  getChildVault(domainId: number): Promise<ChildVault>;
  getAllChildVaults(): Promise<{ domainIds: number[]; vaults: ChildVault[] }>;
  lastRebalanceTime(): Promise<bigint>;
  managementFeeBps(): Promise<bigint>;
  rebalanceCooldown(): Promise<bigint>;
  minAPYDifferential(): Promise<bigint>;
  feeSink(): Promise<Address>;
  isPaused(): Promise<boolean>;
  previewDeposit(assets: bigint): Promise<bigint>;
  previewWithdraw(assets: bigint): Promise<bigint>;
  maxDeposit(receiver: Address): Promise<bigint>;
  maxWithdraw(owner: Address): Promise<bigint>;

  // Write functions
  deposit(assets: bigint, receiver: Address): Promise<Hex>;
  withdraw(assets: bigint, receiver: Address, owner: Address): Promise<Hex>;
  addChildVault(domainId: number, vaultAddress: Address): Promise<Hex>;
  removeChildVault(domainId: number): Promise<Hex>;
  strategicDeploy(params: StrategicDeployParams): Promise<Hex>;
  emergencyPause(): Promise<Hex>;
  emergencyUnpause(): Promise<Hex>;
  emergencyWithdrawAll(): Promise<Hex>;
  setDepositCap(newCap: bigint): Promise<Hex>;
  setManagementFee(feeBps: bigint): Promise<Hex>;
  setRebalanceCooldown(cooldownPeriod: bigint): Promise<Hex>;
  setMinAPYDifferential(minDifferentialBps: bigint): Promise<Hex>;
  collectManagementFees(): Promise<bigint>;
}

export interface ChainConfig {
  domainId: number;
  name: string;
  rpcUrl: string;
  chainId: number;
  motherVaultAddress?: Address;
  childVaultAddress?: Address;
  usdcAddress: Address;
  cctpMessenger?: Address;
  hyperlaneMailbox?: Address;
  explorerUrl: string;
}

// Lazy-load chain configs to avoid initialization errors
export const getChainConfigs = (): Record<string, ChainConfig> => {
  try {
    const env = getEnvConfig();
    return {
      base: {
        domainId: 0,
        name: 'Base',
        rpcUrl: env.baseRpcUrl,
        chainId: 84532, // Base Sepolia
        usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        explorerUrl: 'https://sepolia.basescan.org',
      },
      katana: {
        domainId: 1,
        name: 'Katana',
        rpcUrl: env.katanaRpcUrl,
        chainId: 12345, // Example chainId
        usdcAddress: '0x0000000000000000000000000000000000000000', // To be configured
        explorerUrl: '',
      },
      zircuit: {
        domainId: 2,
        name: 'Zircuit',
        rpcUrl: env.zircuitRpcUrl,
        chainId: 48899, // Zircuit testnet
        usdcAddress: '0x0000000000000000000000000000000000000000', // To be configured
        explorerUrl: 'https://explorer.testnet.zircuit.com',
      },
    };
  } catch (error) {
    console.warn('Failed to load chain configs:', error);
    // Return empty config in development to prevent crashes
    if (process.env.NODE_ENV === 'development') {
      return {};
    }
    throw error;
  }
};

export interface UserPosition {
  shares: bigint;
  assets: bigint;
  pendingWithdrawals: bigint;
  claimableAssets: bigint;
  totalEarningsRaw: bigint; // Raw earnings in wei
  // UI-specific fields (derived from on-chain data)
  balance: number; // Current balance in USDC
  earnings24h: number; // Earnings in last 24 hours
  deposited?: number; // Total amount deposited
  totalEarnings?: number; // Total earnings in USDC
  firstDepositDate?: Date; // Date of first deposit
}

export interface ChainAllocation {
  chainId: string;
  domainId: number;
  name: string;
  percentage: number;
  deployedAmount: number;
  apy: number;
}

export interface VaultStats {
  totalValueLocked: bigint;
  totalUsers: number;
  averageAPY: number;
  dailyVolume: bigint;
  weeklyVolume: bigint;
  managementFeesCollected: bigint;
  // UI-specific fields
  currentAPY: number; // Current blended APY
  lastRebalanceTime?: number; // Unix timestamp
  chainAllocations: ChainAllocation[]; // Per-chain breakdown
}

export interface TransactionStatus {
  hash: Hex;
  status: 'pending' | 'success' | 'failed'; // Changed 'confirmed' to 'success' to match UI
  confirmations: number;
  timestamp: number;
  type: 'deposit' | 'withdraw' | 'rebalance';
  amount: bigint;
  chain: string;
  from?: Address; // Added for filtering
  to?: Address; // Added for filtering
}