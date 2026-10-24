# Kugou CLI

酷狗音乐 API CLI 工具，用于搜索、推荐、收藏、统计、榜单等功能。

## 安装

### npm 安装（推荐）

```bash
npm install -g @kg-ai/kugou-skill
```

安装后使用 `kugou-cli` 命令。npm 安装时会自动安装 SKILL.md 到各平台的 skills 目录。

## 前置条件

使用前需要扫码登录（极简流程）：

```bash
# Step 1: 获取二维码图片
kugou-cli auth login

# Step 2: 循环检查登录状态（单次查询不内部轮询，agent 外层循环直到 logged_in=true）
kugou-cli auth status

> 必须将 Step 1 输出中 `qrcode_img_url` 渲染给用户扫码（用 `![酷狗登录二维码](<qrcode_img_url>)`）。token 会自动持久化存储。
> `auth status` 是单次查询，调用方需在外层循环（2-3 秒间隔）直到 `logged_in=true`；不要等"内部已轮询"——根本不会自动轮询。

## 命令

### 认证

```bash
# 获取二维码图片
kugou-cli auth login

# 检查登录状态（单次查询，不内部轮询；agent 需外层循环 2-3s 间隔）
kugou-cli auth status

# 登出
kugou-cli auth logout
```

### 音乐

```bash
# 搜索歌曲
kugou-cli music search "周杰伦"
kugou-cli music search "周杰伦" --page 1 --size 20

# 猜你喜欢
kugou-cli music recommend guess
kugou-cli music recommend guess --num 10

# 相似推荐（需要指定歌曲）
kugou-cli music recommend similar --song "晴天"
kugou-cli music recommend similar -s "晴天" -n 5

# 我的收藏（上游固定返回最近 10 首，不支持分页）
kugou-cli music favorites

# 最近播放（上游固定返回最近 10 条，不支持分页）
kugou-cli music recent

# 听歌统计
kugou-cli music stats

# 酷狗榜单
kugou-cli music charts 6666    # 飙升榜
kugou-cli music charts 8888    # TOP500榜
kugou-cli music charts 52144  # 抖音热歌酷狗榜
kugou-cli music charts 90379  # 星耀星光榜
kugou-cli music charts 85432  # 百万收藏榜
kugou-cli music charts 74534  # 新歌榜

# 创建歌单
# ⚠️ 默认走客户端路径：kugou-cli control playlist create（见下方"控制"节）
# 客户端不可用时才回退到云端：
kugou-cli music create-playlist "我的空歌单"
kugou-cli music create-playlist "我的批量歌单" --songs "32068120,233125060"

# 搜索歌单
kugou-cli music search-playlist "周杰伦"
kugou-cli music search-playlist "跑步" --filter 1

# 歌单推荐
kugou-cli music recommend-playlist
kugou-cli music recommend-playlist --module-id 6

# 歌单内歌曲列表
kugou-cli music playlist-songs "collection_3_938985631_304_0"

# 调整音乐偏好（用户明确表达"少推点/别再推/多推点"时调用）
# 减少推荐某位歌手
kugou-cli music submit-preference --dimension singer --degree reduce --name "周杰伦" --weight-ratio 0.5
# 屏蔽某类曲风
kugou-cli music submit-preference --dimension genre --degree forbid --weight-ratio 1.5
# 增加某语种
kugou-cli music submit-preference --dimension language --degree add --name "粤语" --weight-ratio 1.8
```

### 安装 SKILL.md

```bash
# 安装到所有平台
kugou-cli install --all

# 安装到指定平台
kugou-cli install --claude
kugou-cli install --mavis
kugou-cli install --hermes --openclaw --codex
```

### 控制 PC/Mac 酷狗客户端

通过本机 HTTP 服务控制本地酷狗桌面客户端（播放、暂停、收藏、创建歌单等）。仅支持 macOS 和 Windows，Linux 不支持。

**前置条件**：需先完成 CLI 登录（`kugou-cli auth login`）且酷狗客户端在后台运行。

**子命令列表**：

| 子命令 | 说明 |
|--------|------|
| `start` | 触发 URL-scheme 握手，预热通道 |
| `status` | 获取客户端状态 |
| `current` | 获取当前播放曲目 |
| `play` | 播放指定歌曲 |
| `play-playlist` | 播放整个歌单（按 global_collection_id） |
| `player` | 控制播放（播放/暂停/切歌等） |
| `seek` | 跳转或快进/快退播放位置 |
| `volume` | 调节音量或静音 |
| `continue-play` | 拉取"另一设备续播"列表并开始播放 |
| `favorite song` | 收藏/取消收藏歌曲 |
| `favorite songlist` | 收藏/取消收藏歌单 |
| `playlist create` | 在客户端创建新歌单 |
| `open` | 在客户端内打开页面（搜索/歌手/专辑等） |

**示例**：

```bash
# 预热握手（首次使用前建议执行）
kugou-cli control start

# 播放歌曲
kugou-cli control play --mixsongid 32100650 --song-name "晴天" --singer-name "周杰伦"

# 播放整个歌单
kugou-cli control play-playlist --global-id "collection_3_938985631_304_0"

# 收藏歌曲
kugou-cli control favorite song --mixsongid 32100650

# 创建歌单
kugou-cli control playlist create --name "精选" --mixsongids "32100650,32068120"

# 在客户端内打开搜索页面
kugou-cli control open --target-type search --keyword "周杰伦"
```

完整命令文档见 `references/control.md`。

### 全局

```bash
kugou-cli --version
kugou-cli --help

# 检查更新
kugou-cli update --check

# 更新（仅 npm 安装支持）
kugou-cli update --force
```

## 输出格式

所有命令输出 JSON 格式，方便其他程序调用：

```json
{
  "errcode": 0,
  "data": {
    "list": [
      {
        "song_name": "晴天",
        "mix_song_id": "32100650",
        "artist_name": "周杰伦",
        "play_link": "https://www.kugou.com/mixsong/agent_gateway/xxx.html"
      }
    ],
    "total": 480,
    "page": 1,
    "size": 20
  },
  "status": 1
}
```

## 错误处理

错误信息输出到 stderr，程序 exit code 为 1：

```bash
kugou-cli music search "xxx" 2>&1
echo $?  # 非 0 表示出错
```
