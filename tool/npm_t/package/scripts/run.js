#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');

// 获取当前平台对应的二进制路径
const platform = process.platform; // darwin, linux, win32

const binName = platform === 'win32' ? 'kugou-cli.exe' : 'kugou-cli';
// scripts/ 的父目录就是项目根目录，bin/ 在根目录下
// 使用简单名称，install.js 会复制对应平台的二进制到这里
const rootDir = path.join(__dirname, '..');
const binPath = path.join(rootDir, 'bin', binName);

const child = spawn(binPath, process.argv.slice(2), {
  stdio: 'inherit',
  shell: platform === 'win32'
});

child.on('exit', (code) => {
  process.exit(code);
});
