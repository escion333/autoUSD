'use client';

import { useState } from 'react';
import { W3SSdk } from '@circle-fin/w3s-pw-web-sdk';

export default function VerifyOTPPage() {
  const [challengeId, setChallengeId] = useState('');
  const [otp, setOtp] = useState('');
  const [output, setOutput] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const addOutput = (message: string, isError = false) => {
    setOutput(prev => [...prev, `${isError ? '❌' : '✅'} ${message}`]);
  };

  const verifyOTP = async () => {
    if (!challengeId || !otp) {
      addOutput('Please enter both Challenge ID and OTP', true);
      return;
    }

    setIsLoading(true);
    setOutput([]);

    try {
      // Initialize SDK
      const sdk = new W3SSdk();
      await sdk.setAppSettings({ appId: '6ebcb0d4b03219ba9c3a7b9fd5c911a7' });
      addOutput('SDK initialized');

      // Verify OTP
      addOutput(`Verifying OTP for challenge: ${challengeId}`);
      const result = await (sdk as any).verifyOtp(challengeId, otp);
      
      addOutput('OTP Verified Successfully!');
      addOutput(`Result: ${JSON.stringify(result, null, 2)}`);
      
      // Check what's in the result
      if (result) {
        addOutput('=== Result Analysis ===');
        addOutput(`Has userToken: ${!!result.userToken}`);
        addOutput(`Has wallets: ${!!result.wallets}`);
        addOutput(`Has pinStatus: ${!!result.pinStatus}`);
        addOutput(`Has encryptionKey: ${!!result.encryptionKey}`);
        
        if (result.userToken) {
          addOutput(`User Token: ${result.userToken.substring(0, 20)}...`);
        }
        
        if (result.wallets) {
          addOutput(`Wallets: ${JSON.stringify(result.wallets)}`);
        }
      }
      
      // Store for further testing
      (window as any).verifyResult = result;
      (window as any).userToken = result?.userToken;
      
    } catch (error: any) {
      addOutput(`Verification failed: ${error?.message || error}`, true);
      console.error('Full error:', error);
    }

    setIsLoading(false);
  };

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold mb-8">Circle OTP Verification Test</h1>
        
        <div className="bg-white rounded-lg shadow p-6 mb-6">
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Challenge ID</label>
              <input
                type="text"
                value={challengeId}
                onChange={(e) => setChallengeId(e.target.value)}
                className="w-full px-3 py-2 border rounded-lg"
                placeholder="Enter challenge ID from email test"
              />
            </div>
            
            <div>
              <label className="block text-sm font-medium mb-2">OTP Code</label>
              <input
                type="text"
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                className="w-full px-3 py-2 border rounded-lg text-center text-2xl tracking-widest"
                placeholder="000000"
                maxLength={6}
              />
            </div>
            
            <button
              onClick={verifyOTP}
              disabled={isLoading}
              className="w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
            >
              {isLoading ? 'Verifying...' : 'Verify OTP'}
            </button>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-semibold mb-4">Output:</h2>
          <div className="font-mono text-sm space-y-1 max-h-96 overflow-y-auto">
            {output.map((line, i) => (
              <div 
                key={i} 
                className={line.startsWith('❌') ? 'text-red-600' : line.startsWith('✅') ? 'text-green-600' : 'text-gray-700'}
              >
                {line}
              </div>
            ))}
          </div>
        </div>

        <div className="mt-6 p-4 bg-blue-50 rounded-lg">
          <h3 className="font-semibold mb-2">How to use:</h3>
          <ol className="text-sm space-y-1">
            <li>1. First run the email test at /test-circle</li>
            <li>2. Copy the Challenge ID from the output</li>
            <li>3. Check your email for the 6-digit OTP</li>
            <li>4. Enter both here and click Verify</li>
          </ol>
        </div>
      </div>
    </div>
  );
}