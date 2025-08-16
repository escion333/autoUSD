'use client';

import { useState, useEffect } from 'react';
import { W3SSdk } from '@circle-fin/w3s-pw-web-sdk';

export default function TestCirclePage() {
  const [email, setEmail] = useState('');
  const [output, setOutput] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [sdk, setSdk] = useState<W3SSdk | null>(null);

  useEffect(() => {
    // Initialize SDK on mount
    const initSDK = async () => {
      try {
        const sdkInstance = new W3SSdk();
        setSdk(sdkInstance);
        setOutput(['SDK instance created']);
        
        // Log available methods
        console.log('SDK instance:', sdkInstance);
        console.log('SDK prototype:', Object.getPrototypeOf(sdkInstance));
      } catch (error: any) {
        setOutput([`Failed to create SDK: ${error?.message || error}`]);
      }
    };
    initSDK();
  }, []);

  const addOutput = (message: string, isError = false) => {
    setOutput(prev => [...prev, `${isError ? '❌' : '✅'} ${message}`]);
  };

  const testCircleSDK = async () => {
    if (!email) {
      addOutput('Please enter an email', true);
      return;
    }

    if (!sdk) {
      addOutput('SDK not initialized', true);
      return;
    }

    setIsLoading(true);
    setOutput(['Testing Circle SDK...']);

    // Test with APP ID
    try {
      addOutput('Setting APP ID: 6ebcb0d4b03219ba9c3a7b9fd5c911a7');
      await sdk.setAppSettings({ appId: '6ebcb0d4b03219ba9c3a7b9fd5c911a7' });
      addOutput('App settings configured');
      
      // Log what methods are available
      const methods = Object.getOwnPropertyNames(Object.getPrototypeOf(sdk));
      console.log('Available SDK methods:', methods);
      addOutput(`SDK has ${methods.length} methods available`);
      
      // Try different authentication methods based on SDK version
      let challengeId: string | undefined;
      
      // Method 1: Try performLogin method (the correct one!)
      try {
        addOutput('Attempting sdk.performLogin({ email })...');
        const loginResult = await (sdk as any).performLogin({ email });
        challengeId = loginResult?.challengeId || loginResult;
        addOutput(`Success with performLogin! Result: ${JSON.stringify(loginResult)}`);
        addOutput(`Challenge ID: ${challengeId}`);
      } catch (e1: any) {
        addOutput(`performLogin failed: ${e1?.message || e1}`, true);
        
        // Method 2: Try authenticate
        try {
          addOutput('Attempting sdk.authenticate(email)...');
          challengeId = await (sdk as any).execute((sdk as any).authenticate({ email })) as string;
          addOutput(`Success! Challenge ID: ${challengeId}`);
        } catch (e2: any) {
          addOutput(`authenticate failed: ${e2?.message || e2}`, true);
          
          // Method 3: Try emailAuth
          try {
            addOutput('Attempting sdk.emailAuth(email)...');
            challengeId = await (sdk as any).execute((sdk as any).emailAuth(email)) as string;
            addOutput(`Success! Challenge ID: ${challengeId}`);
          } catch (e3: any) {
            addOutput(`emailAuth failed: ${e3?.message || e3}`, true);
            
            // Method 4: Try without execute wrapper
            try {
              addOutput('Attempting direct SDK call...');
              // Check if there\'s a method to initiate email authentication
              if (typeof (sdk as any).initializeUserWithEmail === 'function') {
                challengeId = await (sdk as any).initializeUserWithEmail(email);
                addOutput(`Success with initializeUserWithEmail! Challenge ID: ${challengeId}`);
              } else if (typeof (sdk as any).verifyUser === 'function') {
                challengeId = await (sdk as any).verifyUser('email', email);
                addOutput(`Success with verifyUser! Challenge ID: ${challengeId}`);
              } else {
                // List all methods for debugging
                const allMethods = methods.filter(m => !m.startsWith('_') && typeof (sdk as any)[m] === 'function');
                addOutput(`Available public methods: ${allMethods.join(', ')}`, true);
              }
            } catch (e4: any) {
              addOutput(`Direct call failed: ${e4?.message || e4}`, true);
            }
          }
        }
      }
      
      if (challengeId) {
        addOutput('CHECK YOUR EMAIL for OTP!');
        (window as any).testChallengeId = challengeId;
        (window as any).testSDK = sdk;
      }
      
    } catch (error: any) {
      addOutput(`SDK error: ${error?.message || error}`, true);
      console.error('Full error:', error);
    }

    setIsLoading(false);
  };

  const inspectSDK = () => {
    if (!sdk) {
      addOutput('SDK not initialized', true);
      return;
    }
    
    // Get all properties and methods
    const proto = Object.getPrototypeOf(sdk);
    const methods = Object.getOwnPropertyNames(proto).filter(name => 
      typeof (sdk as any)[name] === 'function' && !name.startsWith('_')
    );
    
    addOutput('=== SDK Inspection ===');
    addOutput(`Constructor: ${sdk.constructor.name}`);
    addOutput(`Methods: ${methods.join(', ')}`);
    
    // Check for specific expected methods
    const expectedMethods = ['execute', 'setAppSettings', 'login', 'authenticate', 'verifyChallenge'];
    expectedMethods.forEach(method => {
      const exists = typeof (sdk as any)[method] === 'function';
      addOutput(`Has ${method}(): ${exists ? 'YES' : 'NO'}`, !exists);
    });
    
    // Log to console for detailed inspection
    console.log('Full SDK object:', sdk);
    console.log('SDK prototype:', proto);
  };

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold mb-8">Circle SDK Test Page</h1>
        
        <div className="bg-white rounded-lg shadow p-6 mb-6">
          <div className="mb-4">
            <label className="block text-sm font-medium mb-2">Email Address</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-3 py-2 border rounded-lg"
              placeholder="your-email@example.com"
            />
          </div>
          
          <div className="flex gap-4">
            <button
              onClick={testCircleSDK}
              disabled={isLoading}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
            >
              {isLoading ? 'Testing...' : 'Test Circle SDK'}
            </button>
            
            <button
              onClick={inspectSDK}
              className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
            >
              Inspect SDK
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

        <div className="mt-6 p-4 bg-yellow-50 rounded-lg">
          <h3 className="font-semibold mb-2">Instructions:</h3>
          <ol className="text-sm space-y-1">
            <li>1. Click "Inspect SDK" first to see available methods</li>
            <li>2. Enter your email and click "Test Circle SDK"</li>
            <li>3. Check browser console for detailed logs</li>
            <li>4. Check output for which authentication method works</li>
          </ol>
        </div>
      </div>
    </div>
  );
}