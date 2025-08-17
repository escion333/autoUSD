/**
 * Database Service for Circle Wallet Mappings
 * Manages wallet-to-user relationships and transaction history
 */

import { PrismaClient } from '@prisma/client';
import crypto from 'crypto';

// For development, we'll use a simple in-memory store
// In production, replace with Prisma or your preferred ORM
class WalletDatabase {
  private walletMappings: Map<string, WalletMapping>;
  private transactions: Map<string, Transaction[]>;
  private sessions: Map<string, UserSession>;

  constructor() {
    this.walletMappings = new Map();
    this.transactions = new Map();
    this.sessions = new Map();
  }

  // Wallet Mapping Operations
  async createWalletMapping(mapping: WalletMapping): Promise<WalletMapping> {
    this.walletMappings.set(mapping.userId, mapping);
    return mapping;
  }

  async getWalletByUserId(userId: string): Promise<WalletMapping | null> {
    return this.walletMappings.get(userId) || null;
  }

  async getWalletByEmail(email: string): Promise<WalletMapping | null> {
    for (const mapping of this.walletMappings.values()) {
      if (mapping.email === email) {
        return mapping;
      }
    }
    return null;
  }

  async updateWalletMapping(userId: string, updates: Partial<WalletMapping>): Promise<WalletMapping | null> {
    const existing = this.walletMappings.get(userId);
    if (!existing) return null;

    const updated = { ...existing, ...updates, updatedAt: new Date() };
    this.walletMappings.set(userId, updated);
    return updated;
  }

  // Transaction History
  async recordTransaction(transaction: Transaction): Promise<Transaction> {
    const userTransactions = this.transactions.get(transaction.userId) || [];
    userTransactions.push(transaction);
    this.transactions.set(transaction.userId, userTransactions);
    return transaction;
  }

  async getTransactionHistory(userId: string, limit: number = 10): Promise<Transaction[]> {
    const userTransactions = this.transactions.get(userId) || [];
    return userTransactions.slice(-limit).reverse();
  }

  async getTransactionById(transactionId: string): Promise<Transaction | null> {
    for (const userTransactions of this.transactions.values()) {
      const transaction = userTransactions.find(tx => tx.id === transactionId);
      if (transaction) return transaction;
    }
    return null;
  }

  // Session Management
  async createSession(userId: string, email: string): Promise<string> {
    const sessionId = crypto.randomUUID();
    const session: UserSession = {
      sessionId,
      userId,
      email,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
    };
    this.sessions.set(sessionId, session);
    return sessionId;
  }

  async getSession(sessionId: string): Promise<UserSession | null> {
    const session = this.sessions.get(sessionId);
    if (!session) return null;

    // Check if session is expired
    if (session.expiresAt < new Date()) {
      this.sessions.delete(sessionId);
      return null;
    }

    return session;
  }

  async deleteSession(sessionId: string): Promise<void> {
    this.sessions.delete(sessionId);
  }

  // Stats and Analytics
  async getUserStats(userId: string): Promise<UserStats> {
    const transactions = this.transactions.get(userId) || [];
    const deposits = transactions.filter(tx => tx.type === 'deposit');
    const withdrawals = transactions.filter(tx => tx.type === 'withdrawal');

    // Use BigInt for precise financial calculations
    const totalDeposited = deposits.reduce((sum, tx) => {
      try {
        return sum + BigInt(tx.amount);
      } catch {
        // Fallback for invalid amounts
        return sum;
      }
    }, BigInt(0));
    
    const totalWithdrawn = withdrawals.reduce((sum, tx) => {
      try {
        return sum + BigInt(tx.amount);
      } catch {
        // Fallback for invalid amounts
        return sum;
      }
    }, BigInt(0));

    return {
      userId,
      totalDeposited: totalDeposited.toString(),
      totalWithdrawn: totalWithdrawn.toString(),
      transactionCount: transactions.length,
      lastActivity: transactions[transactions.length - 1]?.timestamp || null,
    };
  }

  // Cleanup expired sessions
  async cleanupExpiredSessions(): Promise<void> {
    const now = new Date();
    for (const [sessionId, session] of this.sessions.entries()) {
      if (session.expiresAt < now) {
        this.sessions.delete(sessionId);
      }
    }
  }
}

// Type Definitions
export interface WalletMapping {
  userId: string;
  email: string;
  walletId: string;
  walletAddress: string;
  blockchain: string;
  createdAt: Date;
  updatedAt?: Date;
  metadata?: Record<string, any>;
}

export interface Transaction {
  id: string;
  userId: string;
  walletId: string;
  type: 'deposit' | 'withdrawal' | 'transfer' | 'bridge';
  amount: string;
  tokenSymbol: string;
  fromAddress: string;
  toAddress: string;
  txHash?: string;
  status: 'pending' | 'completed' | 'failed';
  gasSponsored: boolean;
  gasCostUSD?: string;
  timestamp: Date;
  metadata?: Record<string, any>;
}

export interface UserSession {
  sessionId: string;
  userId: string;
  email: string;
  createdAt: Date;
  expiresAt: Date;
}

export interface UserStats {
  userId: string;
  totalDeposited: string;
  totalWithdrawn: string;
  transactionCount: number;
  lastActivity: Date | null;
}

// Production Database Schema (Prisma)
export const prismaSchema = `
model WalletMapping {
  id            String   @id @default(cuid())
  userId        String   @unique
  email         String   @unique
  walletId      String   @unique
  walletAddress String
  blockchain    String
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  metadata      Json?
  
  transactions  Transaction[]
  
  @@index([email])
  @@index([walletAddress])
}

model Transaction {
  id            String   @id @default(cuid())
  userId        String
  walletId      String
  type          String
  amount        String
  tokenSymbol   String
  fromAddress   String
  toAddress     String
  txHash        String?
  status        String
  gasSponsored  Boolean  @default(false)
  gasCostUSD    String?
  timestamp     DateTime @default(now())
  metadata      Json?
  
  wallet        WalletMapping @relation(fields: [walletId], references: [walletId])
  
  @@index([userId])
  @@index([walletId])
  @@index([txHash])
  @@index([timestamp])
}

model UserSession {
  id            String   @id @default(cuid())
  sessionId     String   @unique
  userId        String
  email         String
  createdAt     DateTime @default(now())
  expiresAt     DateTime
  
  @@index([sessionId])
  @@index([userId])
  @@index([expiresAt])
}
`;

// Export singleton instance
export const walletDB = new WalletDatabase();

// Export types
export type { WalletDatabase };