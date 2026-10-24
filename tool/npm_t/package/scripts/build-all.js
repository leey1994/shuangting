#!/usr/bin/env node
/**
 * 构建所有平台二进制
 * 使用方式: node scripts/build-all.js
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const platforms = [
  { os: 'darwin', arch: 'arm64', name: 'darwin-arm64', exe: 'kugou-cli' },
  { os: 'darwin', arch: 'amd64', name: 'darwin-x64', exe: 'kugou-cli' },
  { os: 'linux', arch: 'arm64', name: 'linux-arm64', exe: 'kugou-cli' },
  { os: 'linux', arch: 'amd64', name: 'linux-x64', exe: 'kugou-cli' },
  { os: 'windows', arch: 'amd64', name: 'win32-x64', exe: 'kugou-cli.exe' },
];

const binDir = path.join(__dirname, '..', 'bin');

console.log('=== Building all platforms ===\n');

// 清理平台目录
for (const p of platforms) {
  const dir = path.join(binDir, p.name);
  if (fs.existsSync(dir)) {
    fs.rmSync(dir, { recursive: true });
  }
}

// 构建每个平台
for (const p of platforms) {
  const outDir = path.join(binDir, p.name);
  fs.mkdirSync(outDir, { recursive: true });

  const outFile = path.join(outDir, p.exe);
  console.log(`Building ${p.name}...`);

  try {
    execSync(`go build -ldflags="-s -w" -o "${outFile}" .`, {
      env: { ...process.env, GOOS: p.os, GOARCH: p.arch, CGO_ENABLED: '0' },
      stdio: 'inherit',
    });
    console.log(`✅ Built: ${p.name}\n`);
  } catch (err) {
    console.error(`❌ Failed: ${p.name}\n`);
    process.exit(1);
  }
}

console.log('=== All platforms built successfully! ===');
console.log('\nRun: node scripts/pack.js');
