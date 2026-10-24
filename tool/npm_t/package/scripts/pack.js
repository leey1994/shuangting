#!/usr/bin/env node
/**
 * 本地打包脚本
 * 使用方式: node scripts/pack.js
 *
 * 发布流程:
 * 1. 构建所有平台二进制到 bin/{platform}/
 * 2. 运行 node scripts/pack.js
 * 3. 运行 npm publish
 */

const fs = require('fs');
const path = require('path');
const pkgRoot = path.join(__dirname, '..');

// 检查必要文件
const requiredFiles = [
  'package.json',
  'SKILL.md',
  'scripts/install.js',
  'scripts/run.js'
];

// 检查平台二进制
const platforms = [
  'darwin-arm64',
  'darwin-x64',
  'linux-arm64',
  'linux-x64',
  'win32-x64'
];

console.log('=== 检查必要文件 ===');
let hasError = false;

for (const file of requiredFiles) {
  const filePath = path.join(pkgRoot, file);
  if (fs.existsSync(filePath)) {
    console.log(`✅ ${file}`);
  } else {
    console.log(`❌ ${file} - 缺失`);
    hasError = true;
  }
}

console.log('\n=== 检查平台二进制 ===');
for (const platform of platforms) {
  const exeName = platform.startsWith('win32') ? 'kugou-cli.exe' : 'kugou-cli';
  const binPath = path.join(pkgRoot, 'bin', platform, exeName);
  if (fs.existsSync(binPath)) {
    const size = fs.statSync(binPath).size;
    console.log(`✅ ${platform}: ${exeName} (${(size / 1024 / 1024).toFixed(2)} MB)`);
  } else {
    console.log(`❌ ${platform}: ${exeName} - 缺失`);
    hasError = true;
  }
}

if (hasError) {
  console.log('\n❌ 打包检查失败，请确保所有文件都已构建');
  process.exit(1);
}

console.log('\n=== 构建完成 ===');
console.log('运行以下命令发布:');
console.log('  npm pack');
console.log('  npm publish --access public --scope=@kugouai');
