/**
 * autoUSD Backend Server
 * Main entry point for backend services
 */

import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';
import circleWalletRoutes from '../api/circle/wallets';
import { validateCircleConfig } from '../services/circle/config';
import { walletDB } from '../services/circle/database';

// Load environment variables
dotenv.config();

// Debug: Check if environment variables are loaded
console.log('Environment check:', {
  hasApiKey: !!process.env.CIRCLE_API_KEY,
  hasEntitySecret: !!process.env.CIRCLE_ENTITY_SECRET,
  hasWalletSetId: !!process.env.CIRCLE_WALLET_SET_ID,
  apiKeyPrefix: process.env.CIRCLE_API_KEY?.substring(0, 20) + '...',
});

// Create Express app
const app: Application = express();
const PORT = process.env.PORT || 3001;

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true,
}));

// Body parsing middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
});
app.use('/api', limiter);

// Health check endpoint
app.get('/health', (_req: Request, res: Response) => {
  const configValid = validateCircleConfig();
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    services: {
      circle: configValid ? 'configured' : 'not configured',
      database: 'in-memory',
    },
  });
});

// API Routes
app.use('/api/circle/wallets', circleWalletRoutes);

// CCTP Bridge status endpoint
app.get('/api/bridge/status/:txHash', async (req: Request, res: Response) => {
  try {
    const { txHash } = req.params;
    
    // This would integrate with Circle's CCTP attestation service
    // For now, returning mock status
    res.json({
      txHash,
      status: 'pending',
      sourceChain: 'base-sepolia',
      destinationChain: 'ethereum-sepolia',
      amount: '0',
      message: 'Bridge status checking not yet implemented',
    });
  } catch (error) {
    res.status(500).json({
      error: 'Failed to get bridge status',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// Fern webhook endpoint (placeholder)
app.post('/api/fern/webhook', async (req: Request, res: Response) => {
  try {
    const { event, data } = req.body;
    
    console.log('Received Fern webhook:', event);
    
    // Handle different Fern events
    switch (event) {
      case 'purchase.completed':
        // Trigger auto-deposit to Mother Vault
        console.log('Purchase completed:', data);
        // TODO: Implement auto-deposit logic
        break;
      
      case 'kyc.approved':
        // Create wallet for approved user
        console.log('KYC approved:', data);
        // TODO: Create wallet for user
        break;
      
      default:
        console.log('Unhandled Fern event:', event);
    }
    
    res.json({ received: true });
  } catch (error) {
    console.error('Fern webhook error:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

// Error handling middleware
app.use((err: Error, _req: Request, res: Response, _next: any) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
  });
});

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: 'Not found',
    message: `Cannot ${req.method} ${req.url}`,
  });
});

// Cleanup expired sessions periodically
setInterval(async () => {
  await walletDB.cleanupExpiredSessions();
}, 60 * 60 * 1000); // Every hour

// Start server
app.listen(PORT, () => {
  console.log(`🚀 autoUSD Backend Server running on port ${PORT}`);
  console.log(`📍 Health check: http://localhost:${PORT}/health`);
  
  // Check Circle configuration
  if (validateCircleConfig()) {
    console.log('✅ Circle configuration is valid');
  } else {
    console.log('⚠️  Circle configuration is missing. Please set environment variables:');
    console.log('   - CIRCLE_API_KEY');
    console.log('   - CIRCLE_ENTITY_SECRET');
    console.log('   - CIRCLE_WALLET_SET_ID');
    console.log('   - CIRCLE_PAYMASTER_API_KEY');
  }
  
  console.log('\n📚 Available endpoints:');
  console.log('   POST /api/circle/wallets/create - Create wallet for user');
  console.log('   GET  /api/circle/wallets/balance - Get wallet balance');
  console.log('   POST /api/circle/wallets/deposit - Execute gasless deposit');
  console.log('   GET  /api/circle/wallets/transactions - Get transaction history');
  console.log('   GET  /api/circle/wallets/stats - Get user statistics');
  console.log('   GET  /api/bridge/status/:txHash - Get CCTP bridge status');
  console.log('   POST /api/fern/webhook - Fern webhook handler');
});

export default app;