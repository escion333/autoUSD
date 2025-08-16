/**
 * Setup script for Circle Developer Controlled Wallets
 * Run this once to generate and register your entity secret
 * 
 * Usage: npx tsx scripts/setup-circle.ts
 */

import { config } from 'dotenv';
import { generateNewEntitySecret, registerEntitySecret } from '../src/lib/circle/developer-wallet';
import * as readline from 'readline';

// Load environment variables
config({ path: '.env.local' });

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const question = (query: string): Promise<string> => {
  return new Promise((resolve) => {
    rl.question(query, resolve);
  });
};

async function main() {
  console.log('🔵 Circle Developer Controlled Wallets Setup');
  console.log('============================================\n');

  const apiKey = process.env.CIRCLE_API_KEY;
  
  if (!apiKey) {
    console.error('❌ CIRCLE_API_KEY not found in .env.local');
    console.log('Please add your Circle API key to .env.local first');
    process.exit(1);
  }

  console.log('✅ Found Circle API key\n');

  const choice = await question(
    'What would you like to do?\n' +
    '1. Generate a new Entity Secret\n' +
    '2. Register an existing Entity Secret\n' +
    '3. Both (generate and register)\n' +
    'Enter choice (1/2/3): '
  );

  let entitySecret = process.env.CIRCLE_ENTITY_SECRET || '';

  switch (choice.trim()) {
    case '1':
      // Generate only
      entitySecret = await generateNewEntitySecret();
      console.log('\n📝 Add this to your .env.local:');
      console.log(`CIRCLE_ENTITY_SECRET=${entitySecret}\n`);
      break;

    case '2':
      // Register existing
      if (!entitySecret) {
        entitySecret = await question('Enter your Entity Secret: ');
      }
      
      if (!entitySecret) {
        console.error('❌ Entity Secret is required');
        process.exit(1);
      }

      console.log('\n📤 Registering Entity Secret with Circle...');
      await registerEntitySecret(apiKey, entitySecret);
      break;

    case '3':
      // Generate and register
      console.log('\n🔐 Generating new Entity Secret...');
      entitySecret = await generateNewEntitySecret();
      
      console.log('\n📝 Add this to your .env.local:');
      console.log(`CIRCLE_ENTITY_SECRET=${entitySecret}\n`);
      
      const proceed = await question('Ready to register? (y/n): ');
      if (proceed.toLowerCase() === 'y') {
        console.log('\n📤 Registering Entity Secret with Circle...');
        await registerEntitySecret(apiKey, entitySecret);
      }
      break;

    default:
      console.log('Invalid choice');
      process.exit(1);
  }

  console.log('\n✅ Setup complete!');
  console.log('\n⚠️  Important reminders:');
  console.log('1. Store your Entity Secret securely (like a private key)');
  console.log('2. Save the recovery file if one was generated');
  console.log('3. Never commit the Entity Secret to version control');
  console.log('4. Add CIRCLE_ENTITY_SECRET to your .env.local file');

  rl.close();
}

main().catch((error) => {
  console.error('Setup failed:', error);
  process.exit(1);
});