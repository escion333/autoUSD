/**
 * Automated setup script for Circle Developer Controlled Wallets
 * This script generates and registers the entity secret automatically
 */

import { config } from 'dotenv';
import { generateNewEntitySecret, registerEntitySecret } from '../src/lib/circle/developer-wallet';
import * as fs from 'fs';
import * as path from 'path';

// Load environment variables
config({ path: '.env.local' });

async function main() {
  console.log('🔵 Circle Developer Controlled Wallets - Automated Setup');
  console.log('======================================================\n');

  const apiKey = process.env.CIRCLE_API_KEY;
  
  if (!apiKey) {
    console.error('❌ CIRCLE_API_KEY not found in .env.local');
    console.log('Please add your Circle API key to .env.local first');
    process.exit(1);
  }

  console.log('✅ Found Circle API key\n');

  // Step 1: Generate Entity Secret
  console.log('🔐 Generating new Entity Secret...');
  const entitySecret = await generateNewEntitySecret();
  
  // Step 2: Save to .env.local
  const envPath = path.join(process.cwd(), '.env.local');
  const envContent = fs.readFileSync(envPath, 'utf-8');
  const updatedContent = envContent.replace(
    /^CIRCLE_ENTITY_SECRET=.*$/m,
    `CIRCLE_ENTITY_SECRET=${entitySecret}`
  );
  fs.writeFileSync(envPath, updatedContent);
  console.log('✅ Entity Secret saved to .env.local\n');

  // Step 3: Register with Circle API
  console.log('📤 Registering Entity Secret with Circle API...');
  try {
    await registerEntitySecret(apiKey, entitySecret);
    console.log('\n✅ Setup complete!');
    console.log('\n🎉 Successfully configured Circle Developer Controlled Wallets');
    console.log('   - Entity Secret generated and saved');
    console.log('   - Registered with Circle API');
    console.log('   - Ready to create wallets!\n');
    
    console.log('⚠️  Important reminders:');
    console.log('1. The Entity Secret has been saved to .env.local');
    console.log('2. Keep the recovery file safe if one was generated');
    console.log('3. Never commit the Entity Secret to version control');
    console.log('4. The app is now ready to create wallets for users');
  } catch (error: any) {
    console.error('\n❌ Failed to register Entity Secret:', error.message);
    console.log('\nThe Entity Secret has been generated and saved, but registration failed.');
    console.log('You may need to manually register it or check your API key permissions.');
  }
}

main().catch((error) => {
  console.error('Setup failed:', error);
  process.exit(1);
});