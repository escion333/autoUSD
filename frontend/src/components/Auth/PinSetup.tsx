'use client';

import { useState } from 'react';
import { getCircleSDK } from '@/lib/circle/config';

interface PinSetupProps {
  userToken: string;
  onComplete: () => void;
  onError: (error: string) => void;
}

export function PinSetup({ userToken, onComplete, onError }: PinSetupProps) {
  const [pin, setPin] = useState('');
  const [confirmPin, setConfirmPin] = useState('');
  const [step, setStep] = useState<'enter' | 'confirm'>('enter');
  const [isLoading, setIsLoading] = useState(false);

  const handlePinSubmit = async () => {
    if (step === 'enter') {
      if (pin.length !== 6) {
        onError('PIN must be 6 digits');
        return;
      }
      setStep('confirm');
      return;
    }

    if (pin !== confirmPin) {
      onError('PINs do not match');
      setConfirmPin('');
      setStep('enter');
      setPin('');
      return;
    }

    setIsLoading(true);
    try {
      const sdk = getCircleSDK();
      
      // Set up PIN for the user using execute method
      try {
        await (sdk as any).execute({
          method: 'POST',
          path: '/pin',
          userToken,
          body: { pin }
        });
      } catch (sdkError: any) {
        console.error('PIN setup error:', sdkError);
        throw new Error(sdkError?.message || 'Failed to set up PIN');
      }

      onComplete();
    } catch (error: any) {
      onError(error?.message || 'Failed to set up PIN');
      setPin('');
      setConfirmPin('');
      setStep('enter');
    } finally {
      setIsLoading(false);
    }
  };

  const handlePinChange = (value: string) => {
    // Only allow digits and max 6 characters
    const filtered = value.replace(/\D/g, '').slice(0, 6);
    if (step === 'enter') {
      setPin(filtered);
    } else {
      setConfirmPin(filtered);
    }
  };

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold mb-2">
          {step === 'enter' ? 'Create Your PIN' : 'Confirm Your PIN'}
        </h3>
        <p className="text-sm text-gray-600 mb-4">
          {step === 'enter' 
            ? 'Create a 6-digit PIN to secure your wallet transactions'
            : 'Re-enter your PIN to confirm'}
        </p>
      </div>

      <div className="relative">
        <input
          type="password"
          inputMode="numeric"
          pattern="[0-9]*"
          maxLength={6}
          value={step === 'enter' ? pin : confirmPin}
          onChange={(e) => handlePinChange(e.target.value)}
          className="w-full px-4 py-3 text-center text-2xl tracking-[0.5em] border-2 border-gray-300 rounded-lg focus:outline-none focus:border-blue-500"
          placeholder="••••••"
          disabled={isLoading}
          autoComplete="off"
        />
        
        {/* Visual PIN indicators */}
        <div className="flex justify-center mt-2 space-x-2">
          {[...Array(6)].map((_, i) => (
            <div
              key={i}
              className={`w-2 h-2 rounded-full transition-colors ${
                (step === 'enter' ? pin : confirmPin).length > i
                  ? 'bg-blue-500'
                  : 'bg-gray-300'
              }`}
            />
          ))}
        </div>
      </div>

      <button
        onClick={handlePinSubmit}
        disabled={
          isLoading || 
          (step === 'enter' ? pin.length !== 6 : confirmPin.length !== 6)
        }
        className="w-full px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
      >
        {isLoading ? (
          <span className="flex items-center justify-center">
            <svg className="animate-spin h-5 w-5 mr-2" viewBox="0 0 24 24">
              <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
                fill="none"
              />
              <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
              />
            </svg>
            Setting up PIN...
          </span>
        ) : (
          step === 'enter' ? 'Continue' : 'Set PIN'
        )}
      </button>

      {step === 'confirm' && (
        <button
          onClick={() => {
            setStep('enter');
            setConfirmPin('');
          }}
          className="w-full text-sm text-gray-600 hover:text-gray-800"
        >
          ← Back to enter PIN
        </button>
      )}
    </div>
  );
}