/**
 * Circle Wallet API Endpoints
 * Handles wallet creation, balance checks, and transactions
 */

import { Request, Response, Router } from 'express';
import { circleWalletServiceV2 } from '../../services/circle/walletServiceV2';
import { circlePaymasterService } from '../../services/circle/paymasterService';
import { walletDB } from '../../services/circle/database';
import { validateCircleConfig } from '../../services/circle/config';
import crypto from 'crypto';

const router = Router();

// Middleware to validate Circle configuration
router.use((_req, res, next) => {
  if (!validateCircleConfig()) {
    return res.status(500).json({
      error: 'Circle configuration not properly set',
      message: 'Please configure Circle API keys in environment variables',
    });
  }
  next();
  return;
});

/**
 * POST /api/circle/wallets/create
 * Create a new wallet for a user
 */
router.post('/create', async (req: Request, res: Response): Promise<Response> => {
  try {
    const { email, userId } = req.body;

    if (!email || !userId) {
      return res.status(400).json({
        error: 'Missing required fields',
        message: 'Email and userId are required',
      });
    }

    // Check if user already has a wallet
    const existingWallet = await walletDB.getWalletByEmail(email);
    if (existingWallet) {
      return res.status(200).json({
        message: 'Wallet already exists',
        wallet: existingWallet,
      });
    }

    // Create new Circle wallet
    const wallet = await circleWalletServiceV2.createWallet(userId);

    // Store wallet mapping
    await walletDB.createWalletMapping({
      userId,
      email,
      walletId: wallet.id,
      walletAddress: wallet.address,
      blockchain: wallet.blockchain,
      createdAt: new Date(),
    });

    // Create user session
    const sessionId = await walletDB.createSession(userId, email);

    return res.status(201).json({
      message: 'Wallet created successfully',
      wallet: {
        address: wallet.address,
        blockchain: wallet.blockchain,
        state: wallet.state,
      },
      sessionId,
    });
  } catch (error) {
    console.error('Error creating wallet:', error);
    return res.status(500).json({
      error: 'Failed to create wallet',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

/**
 * GET /api/circle/wallets/balance
 * Get wallet balance for a user
 */
router.get('/balance', async (req: Request, res: Response): Promise<Response> => {
  try {
    const { email, sessionId } = req.query;

    if (!email && !sessionId) {
      return res.status(400).json({
        error: 'Missing required parameters',
        message: 'Email or sessionId is required',
      });
    }

    // Get wallet mapping
    let walletMapping;
    if (sessionId) {
      const session = await walletDB.getSession(sessionId as string);
      if (!session) {
        return res.status(401).json({
          error: 'Invalid or expired session',
        });
      }
      walletMapping = await walletDB.getWalletByUserId(session.userId);
    } else {
      walletMapping = await walletDB.getWalletByEmail(email as string);
    }

    if (!walletMapping) {
      return res.status(404).json({
        error: 'Wallet not found',
        message: 'No wallet associated with this user',
      });
    }

    // Get balance from Circle
    const balances = await circleWalletServiceV2.getWalletBalance(walletMapping.walletId);

    return res.json({
      wallet: {
        address: walletMapping.walletAddress,
        blockchain: walletMapping.blockchain,
      },
      balances: balances.map((b: any) => ({
        token: b.token.symbol,
        amount: b.amount,
        amountUSD: b.amountUSD,
      })),
    });
  } catch (error) {
    console.error('Error getting wallet balance:', error);
    return res.status(500).json({
      error: 'Failed to get wallet balance',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

/**
 * POST /api/circle/wallets/deposit
 * Execute a gasless deposit to Mother Vault
 */
router.post('/deposit', async (req: Request, res: Response): Promise<Response> => {
  try {
    const { email, amount, sessionId } = req.body;

    if ((!email && !sessionId) || !amount) {
      return res.status(400).json({
        error: 'Missing required fields',
        message: 'Email/sessionId and amount are required',
      });
    }

    // Validate amount
    const amountBigInt = BigInt(amount);
    if (amountBigInt <= 0n) {
      return res.status(400).json({
        error: 'Invalid amount',
        message: 'Amount must be greater than 0',
      });
    }
    
    // Check maximum deposit limit (100 USDC for safety)
    const maxDeposit = BigInt(100 * 10 ** 6); // 100 USDC with 6 decimals
    if (amountBigInt > maxDeposit) {
      return res.status(400).json({
        error: 'Amount exceeds limit',
        message: 'Maximum deposit is 100 USDC during beta',
      });
    }

    // Get wallet mapping
    let walletMapping;
    if (sessionId) {
      const session = await walletDB.getSession(sessionId);
      if (!session) {
        return res.status(401).json({
          error: 'Invalid or expired session',
        });
      }
      walletMapping = await walletDB.getWalletByUserId(session.userId);
    } else {
      walletMapping = await walletDB.getWalletByEmail(email);
    }

    if (!walletMapping) {
      return res.status(404).json({
        error: 'Wallet not found',
        message: 'No wallet associated with this user',
      });
    }

    // Check eligibility for gas sponsorship
    const isEligible = await circlePaymasterService.checkEligibility(
      walletMapping.walletAddress,
      'deposit'
    );

    if (!isEligible) {
      return res.status(403).json({
        error: 'Not eligible for gas sponsorship',
        message: 'Daily limit reached or operation not supported',
      });
    }

    // Get Mother Vault address from environment
    const motherVaultAddress = process.env.MOTHER_VAULT_ADDRESS;
    if (!motherVaultAddress) {
      return res.status(500).json({
        error: 'Mother Vault not configured',
        message: 'Please deploy Mother Vault first',
      });
    }

    // Build sponsored transaction
    const sponsoredTx = await circlePaymasterService.buildSponsoredDeposit(
      walletMapping.walletAddress,
      motherVaultAddress,
      amount
    );

    // Execute deposit
    const result = await circleWalletServiceV2.executeGaslessDeposit(
      walletMapping.userId,
      amount,
      motherVaultAddress
    );

    // Record transaction
    await walletDB.recordTransaction({
      id: crypto.randomUUID(),
      userId: walletMapping.userId,
      walletId: walletMapping.walletId,
      type: 'deposit',
      amount,
      tokenSymbol: 'USDC',
      fromAddress: walletMapping.walletAddress,
      toAddress: motherVaultAddress,
      txHash: result.transactionId,
      status: 'pending',
      gasSponsored: true,
      gasCostUSD: await circlePaymasterService.estimateGasCostUSD(sponsoredTx.gasEstimate),
      timestamp: new Date(),
    });

    return res.json({
      message: 'Deposit initiated successfully',
      transaction: {
        id: result.transactionId,
        status: result.status,
        amount,
        gasSponsored: true,
        estimatedGasCostUSD: await circlePaymasterService.estimateGasCostUSD(sponsoredTx.gasEstimate),
      },
    });
  } catch (error) {
    console.error('Error executing deposit:', error);
    return res.status(500).json({
      error: 'Failed to execute deposit',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

/**
 * GET /api/circle/wallets/transactions
 * Get transaction history for a user
 */
router.get('/transactions', async (req: Request, res: Response): Promise<Response> => {
  try {
    const { email, sessionId, limit = '10' } = req.query;

    if (!email && !sessionId) {
      return res.status(400).json({
        error: 'Missing required parameters',
        message: 'Email or sessionId is required',
      });
    }

    // Get wallet mapping
    let walletMapping;
    if (sessionId) {
      const session = await walletDB.getSession(sessionId as string);
      if (!session) {
        return res.status(401).json({
          error: 'Invalid or expired session',
        });
      }
      walletMapping = await walletDB.getWalletByUserId(session.userId);
    } else {
      walletMapping = await walletDB.getWalletByEmail(email as string);
    }

    if (!walletMapping) {
      return res.status(404).json({
        error: 'Wallet not found',
        message: 'No wallet associated with this user',
      });
    }

    // Get transaction history
    const transactions = await walletDB.getTransactionHistory(
      walletMapping.userId,
      parseInt(limit as string)
    );

    return res.json({
      wallet: {
        address: walletMapping.walletAddress,
        blockchain: walletMapping.blockchain,
      },
      transactions: transactions.map(tx => ({
        id: tx.id,
        type: tx.type,
        amount: tx.amount,
        token: tx.tokenSymbol,
        status: tx.status,
        gasSponsored: tx.gasSponsored,
        gasCostUSD: tx.gasCostUSD,
        timestamp: tx.timestamp,
        txHash: tx.txHash,
      })),
    });
  } catch (error) {
    console.error('Error getting transactions:', error);
    return res.status(500).json({
      error: 'Failed to get transactions',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

/**
 * GET /api/circle/wallets/stats
 * Get user statistics
 */
router.get('/stats', async (req: Request, res: Response): Promise<Response> => {
  try {
    const { email, sessionId } = req.query;

    if (!email && !sessionId) {
      return res.status(400).json({
        error: 'Missing required parameters',
        message: 'Email or sessionId is required',
      });
    }

    // Get wallet mapping
    let walletMapping;
    if (sessionId) {
      const session = await walletDB.getSession(sessionId as string);
      if (!session) {
        return res.status(401).json({
          error: 'Invalid or expired session',
        });
      }
      walletMapping = await walletDB.getWalletByUserId(session.userId);
    } else {
      walletMapping = await walletDB.getWalletByEmail(email as string);
    }

    if (!walletMapping) {
      return res.status(404).json({
        error: 'Wallet not found',
        message: 'No wallet associated with this user',
      });
    }

    // Get user stats
    const stats = await walletDB.getUserStats(walletMapping.userId);

    // Get gas usage stats
    const gasStats = await circlePaymasterService.getGasUsageStats(walletMapping.walletAddress);

    return res.json({
      wallet: {
        address: walletMapping.walletAddress,
        blockchain: walletMapping.blockchain,
      },
      stats: {
        totalDeposited: stats.totalDeposited,
        totalWithdrawn: stats.totalWithdrawn,
        transactionCount: stats.transactionCount,
        lastActivity: stats.lastActivity,
        gasSponsored: gasStats.totalSponsored,
        gasTransactions: gasStats.totalTransactions,
      },
    });
  } catch (error) {
    console.error('Error getting stats:', error);
    return res.status(500).json({
      error: 'Failed to get stats',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

export default router;