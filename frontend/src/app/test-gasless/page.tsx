'use client';

import { GaslessTests } from '@/components/test/GaslessTests';
import Link from 'next/link';

export default function TestGaslessPage() {
  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center">
            <Link href="/" className="text-2xl font-bold text-gray-900 hover:text-gray-700">
              autoUSD
            </Link>
            <div className="flex items-center gap-4">
              <Link 
                href="/" 
                className="px-4 py-2 text-gray-600 hover:text-gray-800 transition-colors"
              >
                ← Back to Dashboard
              </Link>
            </div>
          </div>
        </div>
      </header>

      <main className="py-8">
        <div className="container mx-auto px-4">
          <div className="text-center mb-8">
            <h1 className="text-3xl font-bold text-gray-900 mb-4">
              Gasless Transaction Testing
            </h1>
            <p className="text-lg text-gray-600 max-w-2xl mx-auto">
              Test the complete gasless experience using Circle Developer Controlled Wallets. 
              Verify that users can deposit, withdraw, and approve USDC without holding ETH.
            </p>
          </div>
          
          <GaslessTests />
        </div>
      </main>
    </div>
  );
}