const fs = require('fs');
const path = require('path');
const os = require('os');

const platform = process.platform;
const arch = process.arch;
const binDir = path.join(__dirname, '..', 'bin');
const pkgRoot = path.join(__dirname, '..');

// 平台映射
const platformMap = {
  'darwin': { dir: `darwin-${arch}`, exe: 'kugou-cli' },
  'linux': { dir: `linux-${arch}`, exe: 'kugou-cli' },
  'win32': { dir: `win32-x64`, exe: 'kugou-cli.exe' }
};

const config = platformMap[platform];
if (!config) {
  console.error(`Unsupported platform: ${platform}`);
  process.exit(1);
}

// 安装二进制
const srcBin = path.join(binDir, config.dir, config.exe);
const destBin = path.join(binDir, config.exe);

if (!fs.existsSync(srcBin)) {
  console.error(`Binary not found for ${platform}-${arch}: ${srcBin}`);
  console.error('Please report this issue: https://github.com/kg-ai/kugou-cli/issues');
  process.exit(1);
}

fs.copyFileSync(srcBin, destBin);
fs.chmodSync(destBin, 0o755);
console.log(`Installed ${config.exe} for ${platform}-${arch}`);

// 安装 SKILL.md 到各平台的 skills 目录
const skillSrc = path.join(pkgRoot, 'SKILL.md');
const skillDirs = [
  path.join(os.homedir(), '.claude', 'skills', 'kugou-skill'),
  path.join(os.homedir(), '.mavis', 'skills', 'kugou-skill'),
  path.join(os.homedir(), '.hermes', 'skills', 'kugou-skill'),
  path.join(os.homedir(), '.openclaw', 'skills', 'kugou-skill'),
  path.join(os.homedir(), '.codex', 'skills', 'kugou-skill'),
  path.join(os.homedir(), '.workbuddy', 'skills', 'kugou-skill'),
  path.join(os.homedir(), '.workbuddy', 'skills', 'kugou-skill__skillhub'),
];

if (fs.existsSync(skillSrc)) {
  const referencesSrc = path.join(pkgRoot, 'references');

  // workbuddy 平台:kugou-skill 与 kugou-skill__skillhub 二选一
  // 若 ~/.workbuddy/skills/kugou-skill__skillhub 已存在,只装到那里,跳过 kugou-skill
  // 反之只装到 kugou-skill,__skillhub 是 opt-in 不自动创建
  const workbuddyAltDir = path.join(os.homedir(), '.workbuddy', 'skills', 'kugou-skill__skillhub');
  const workbuddyUseAlt = fs.existsSync(workbuddyAltDir);

  for (const skillDir of skillDirs) {
    // 只在 skills 目录存在时才复制，不创建目录
    const parentDir = path.dirname(skillDir);
    if (fs.existsSync(parentDir)) {
      const baseName = path.basename(skillDir);

      // workbuddy 互斥:__skillhub 存在时跳过 kugou-skill,只装 __skillhub
      const isWorkbuddyPrimary = baseName === 'kugou-skill' && skillDir === path.join(os.homedir(), '.workbuddy', 'skills', 'kugou-skill');
      if (isWorkbuddyPrimary && workbuddyUseAlt) {
        console.log(`Skipping ${skillDir}: ${workbuddyAltDir} exists, installing only to ${workbuddyAltDir}`);
        continue;
      }

      // __skillhub 子目录是 opt-in:仅在已存在时同步,绝不自动创建
      if (baseName === 'kugou-skill__skillhub' && !fs.existsSync(skillDir)) {
        continue;
      }
      try {
        if (!fs.existsSync(skillDir)) {
          fs.mkdirSync(skillDir, { recursive: true });
        }
        fs.copyFileSync(skillSrc, path.join(skillDir, 'SKILL.md'));
        console.log(`Installed SKILL.md to ${skillDir}`);

        // 拷贝 references 子文档
        if (fs.existsSync(referencesSrc)) {
          const referencesDest = path.join(skillDir, 'references');
          if (!fs.existsSync(referencesDest)) {
            fs.mkdirSync(referencesDest, { recursive: true });
          }
          const refFiles = fs.readdirSync(referencesSrc);
          for (const refFile of refFiles) {
            const srcFile = path.join(referencesSrc, refFile);
            const destFile = path.join(referencesDest, refFile);
            if (fs.statSync(srcFile).isFile()) {
              fs.copyFileSync(srcFile, destFile);
            }
          }
          console.log(`Installed references to ${referencesDest}`);
        }
      } catch (err) {
        console.warn(`Warning: Failed to install to ${skillDir}: ${err.message}`);
      }
    }
  }
}
