"use client";

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
// import { Separator } from '@/components/ui/separator';
import { CheckCircle, Loader2, DollarSign, TrendingUp, Shield } from 'lucide-react';

interface DemoState {
  email: string;
  amount: string;
  step: 'email' | 'deposit' | 'processing' | 'success';
  wallet?: {
    address: string;
    sessionId: string;
  };
  txHash?: string;
  loading: boolean;
  error?: string;
}

export default function DemoPage() {
  const [state, setState] = useState<DemoState>({
    email: 'demo@autousd.com',
    amount: '50',
    step: 'email',
    loading: false,
  });

  const createWallet = async () => {
    setState(prev => ({ ...prev, loading: true, error: undefined }));
    
    try {
      const response = await fetch('/api/test-connection', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: state.email,
          userId: `demo-${Date.now()}`,
        }),
      });

      const data = await response.json();
      
      if (data.status === 'success') {
        setState(prev => ({
          ...prev,
          wallet: {
            address: data.walletCreation.wallet.address,
            sessionId: data.walletCreation.sessionId,
          },
          step: 'deposit',
          loading: false,
        }));
      } else {
        throw new Error(data.error || 'Failed to create wallet');
      }
    } catch (error) {
      setState(prev => ({
        ...prev,
        error: error instanceof Error ? error.message : 'Unknown error',
        loading: false,
      }));
    }
  };

  const simulateDeposit = async () => {
    setState(prev => ({ ...prev, loading: true, step: 'processing' }));
    
    // Simulate deposit process
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    setState(prev => ({
      ...prev,
      step: 'success',
      txHash: '0x' + Math.random().toString(16).substr(2, 40),
      loading: false,
    }));
  };

  const resetDemo = () => {
    setState({
      email: 'demo@autousd.com',
      amount: '50',
      step: 'email',
      loading: false,
    });
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-8">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            autoUSD Demo
          </h1>
          <p className="text-lg text-gray-600 max-w-2xl mx-auto">
            Experience seamless cross-chain USDC yield optimization with email-only authentication
          </p>
        </div>

        {/* Demo Flow */}
        <div className="grid lg:grid-cols-2 gap-8">
          {/* Left Panel - Demo Steps */}
          <div>
            <Card className="mb-6">
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <DollarSign className="h-5 w-5" />
                  Live Demo Flow
                </CardTitle>
                <CardDescription>
                  Follow along as we demonstrate the complete user journey
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {/* Step 1: Email Authentication */}
                <div className={`p-4 rounded-lg border ${state.step === 'email' ? 'border-blue-500 bg-blue-50' : 'border-gray-200'}`}>
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="font-semibold">1. Email Authentication</h3>
                    {state.wallet && <CheckCircle className="h-5 w-5 text-green-500" />}
                  </div>
                  {state.step === 'email' && (
                    <div className="space-y-3">
                      <Input
                        type="email"
                        placeholder="Enter your email"
                        value={state.email}
                        onChange={(e) => setState(prev => ({ ...prev, email: e.target.value }))}
                      />
                      <Button 
                        onClick={createWallet} 
                        disabled={state.loading || !state.email}
                        className="w-full"
                      >
                        {state.loading ? (
                          <>
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                            Creating Wallet...
                          </>
                        ) : (
                          'Create Circle Wallet'
                        )}
                      </Button>
                    </div>
                  )}
                  {state.wallet && (
                    <div className="mt-2">
                      <Badge variant="secondary" className="text-xs">
                        Wallet: {state.wallet.address.slice(0, 8)}...{state.wallet.address.slice(-6)}
                      </Badge>
                    </div>
                  )}
                </div>

                {/* Step 2: USDC Deposit */}
                <div className={`p-4 rounded-lg border ${state.step === 'deposit' ? 'border-blue-500 bg-blue-50' : 'border-gray-200'}`}>
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="font-semibold">2. USDC Deposit</h3>
                    {state.step === 'success' && <CheckCircle className="h-5 w-5 text-green-500" />}
                  </div>
                  {state.step === 'deposit' && (
                    <div className="space-y-3">
                      <Input
                        type="number"
                        placeholder="Amount in USDC"
                        value={state.amount}
                        onChange={(e) => setState(prev => ({ ...prev, amount: e.target.value }))}
                      />
                      <Button 
                        onClick={simulateDeposit} 
                        disabled={state.loading || !state.amount}
                        className="w-full"
                      >
                        {state.loading ? (
                          <>
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                            Processing...
                          </>
                        ) : (
                          'Deposit & Bridge to Katana'
                        )}
                      </Button>
                    </div>
                  )}
                </div>

                {/* Step 3: Processing */}
                <div className={`p-4 rounded-lg border ${state.step === 'processing' ? 'border-yellow-500 bg-yellow-50' : 'border-gray-200'}`}>
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="font-semibold">3. Cross-chain Processing</h3>
                    {state.step === 'processing' && <Loader2 className="h-5 w-5 animate-spin text-yellow-500" />}
                    {state.step === 'success' && <CheckCircle className="h-5 w-5 text-green-500" />}
                  </div>
                  {state.step === 'processing' && (
                    <div className="space-y-2">
                      <div className="text-sm text-gray-600">
                        • Executing gasless transaction via Circle Paymaster<br/>
                        • Bridging USDC via CCTP to Ethereum<br/>
                        • Relaying to Katana via AggLayer<br/>
                        • Creating SushiSwap V3 LP position
                      </div>
                    </div>
                  )}
                </div>

                {/* Step 4: Success */}
                {state.step === 'success' && (
                  <div className="p-4 rounded-lg border border-green-500 bg-green-50">
                    <div className="flex items-center justify-between mb-2">
                      <h3 className="font-semibold">4. Success!</h3>
                      <CheckCircle className="h-5 w-5 text-green-500" />
                    </div>
                    <div className="space-y-2">
                      <p className="text-sm text-green-700">
                        Your ${state.amount} USDC is now earning optimized yields on Katana!
                      </p>
                      {state.txHash && (
                        <Badge variant="outline" className="text-xs">
                          TX: {state.txHash.slice(0, 10)}...
                        </Badge>
                      )}
                      <Button onClick={resetDemo} variant="outline" size="sm" className="w-full mt-2">
                        Run Demo Again
                      </Button>
                    </div>
                  </div>
                )}

                {state.error && (
                  <div className="p-4 rounded-lg border border-red-500 bg-red-50">
                    <p className="text-red-700 text-sm">{state.error}</p>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>

          {/* Right Panel - Features & Status */}
          <div className="space-y-6">
            {/* Key Features */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <TrendingUp className="h-5 w-5" />
                  Key Features
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-start gap-3">
                  <Shield className="h-5 w-5 text-green-500 mt-0.5" />
                  <div>
                    <h4 className="font-semibold">No Seed Phrases</h4>
                    <p className="text-sm text-gray-600">Circle Developer Controlled Wallets with email authentication</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <DollarSign className="h-5 w-5 text-green-500 mt-0.5" />
                  <div>
                    <h4 className="font-semibold">Gasless Transactions</h4>
                    <p className="text-sm text-gray-600">Platform pays all gas fees via Circle Paymaster</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <TrendingUp className="h-5 w-5 text-green-500 mt-0.5" />
                  <div>
                    <h4 className="font-semibold">Cross-chain Yield</h4>
                    <p className="text-sm text-gray-600">Automated bridging to highest-yield opportunities</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* System Status */}
            <Card>
              <CardHeader>
                <CardTitle>System Status</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex justify-between">
                  <span>Frontend</span>
                  <Badge variant="secondary">Running</Badge>
                </div>
                <div className="flex justify-between">
                  <span>Backend API</span>
                  <Badge variant="secondary">Connected</Badge>
                </div>
                <div className="flex justify-between">
                  <span>Circle Wallets</span>
                  <Badge variant="secondary">Active</Badge>
                </div>
                <div className="flex justify-between">
                  <span>Smart Contracts</span>
                  <Badge variant="secondary">Deployed</Badge>
                </div>
                <div className="border-t border-gray-200 my-3" />
                <div className="text-sm text-gray-600">
                  <p><strong>MotherVault:</strong> 0x7113...8fe5</p>
                  <p><strong>Network:</strong> Base Sepolia</p>
                  <p><strong>Bridge:</strong> CCTP + AggLayer</p>
                </div>
              </CardContent>
            </Card>

            {/* Architecture */}
            <Card>
              <CardHeader>
                <CardTitle>Architecture Flow</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-sm space-y-2">
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
                    <span>Base Sepolia (MotherVault)</span>
                  </div>
                  <div className="ml-2 text-gray-400">↓ CCTP Bridge</div>
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                    <span>Ethereum Sepolia (Passthrough)</span>
                  </div>
                  <div className="ml-2 text-gray-400">↓ AggLayer Bridge</div>
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 bg-purple-500 rounded-full"></div>
                    <span>Katana Tatara (Yield Generation)</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
}