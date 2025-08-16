#!/usr/bin/env node

/**
 * Script to automatically fix all low-contrast text colors in the codebase
 * Run with: node scripts/fix-text-colors.js
 */

const fs = require('fs');
const path = require('path');

// Color replacements map - from light to dark
const colorReplacements = {
  // Text colors - ensure minimum contrast
  'text-gray-400': 'text-gray-700',  // Never use gray-400 for text
  'text-gray-500': 'text-gray-700',  // Minimum gray-700 on white
  'text-gray-600': 'text-gray-700',  // Standardize to gray-700
  
  // Hover states should also be darker
  'hover:text-gray-500': 'hover:text-gray-800',
  'hover:text-gray-600': 'hover:text-gray-800',
  'hover:text-gray-700': 'hover:text-gray-900',
  
  // Placeholder text
  'placeholder-gray-400': 'placeholder-gray-600',
  'placeholder-gray-500': 'placeholder-gray-600',
  
  // Border colors can stay lighter, but text must be dark
  // Don't replace border colors
};

// Files and directories to process
const componentsDir = path.join(__dirname, '..', 'src', 'components');
const hooksDir = path.join(__dirname, '..', 'src', 'hooks');
const appDir = path.join(__dirname, '..', 'src', 'app');
const libDir = path.join(__dirname, '..', 'src', 'lib');

// File extensions to process
const extensions = ['.tsx', '.ts', '.jsx', '.js'];

let totalReplacements = 0;
let filesModified = 0;

function processFile(filePath) {
  if (!extensions.some(ext => filePath.endsWith(ext))) {
    return;
  }
  
  let content = fs.readFileSync(filePath, 'utf8');
  let originalContent = content;
  let fileReplacements = 0;
  
  // Apply replacements
  for (const [oldColor, newColor] of Object.entries(colorReplacements)) {
    const regex = new RegExp(`\\b${oldColor}\\b`, 'g');
    const matches = content.match(regex);
    if (matches) {
      content = content.replace(regex, newColor);
      fileReplacements += matches.length;
      console.log(`  ${filePath}: Replaced ${matches.length} instances of "${oldColor}" with "${newColor}"`);
    }
  }
  
  // Special case: Fix any className strings with multiple spaces
  content = content.replace(/className=["']([^"']+)["']/g, (match, classes) => {
    return `className="${classes.replace(/\s+/g, ' ').trim()}"`;
  });
  
  if (content !== originalContent) {
    fs.writeFileSync(filePath, content, 'utf8');
    totalReplacements += fileReplacements;
    filesModified++;
    console.log(`✅ Modified: ${filePath} (${fileReplacements} replacements)`);
  }
}

function processDirectory(dirPath) {
  if (!fs.existsSync(dirPath)) {
    console.log(`⚠️  Directory not found: ${dirPath}`);
    return;
  }
  
  const items = fs.readdirSync(dirPath);
  
  for (const item of items) {
    const itemPath = path.join(dirPath, item);
    const stat = fs.statSync(itemPath);
    
    if (stat.isDirectory() && !item.startsWith('.') && item !== 'node_modules') {
      processDirectory(itemPath);
    } else if (stat.isFile()) {
      processFile(itemPath);
    }
  }
}

console.log('🎨 Fixing text color contrast issues...\n');
console.log('Processing directories:');
console.log('  - Components:', componentsDir);
console.log('  - Hooks:', hooksDir);
console.log('  - App:', appDir);
console.log('  - Lib:', libDir);
console.log('\n');

// Process all directories
[componentsDir, hooksDir, appDir, libDir].forEach(dir => {
  processDirectory(dir);
});

console.log('\n' + '='.repeat(60));
console.log(`✨ Color fix complete!`);
console.log(`📊 Statistics:`);
console.log(`   - Files modified: ${filesModified}`);
console.log(`   - Total replacements: ${totalReplacements}`);
console.log('='.repeat(60));

if (filesModified > 0) {
  console.log('\n💡 Next steps:');
  console.log('   1. Review the changes');
  console.log('   2. Test the application');
  console.log('   3. Commit the fixes');
}