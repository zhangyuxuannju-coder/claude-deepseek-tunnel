# Claude Code + DeepSeek 无外网服务器部署方案

> 通过 Mac 中转机 + SSH 反向隧道，让无外网的 Rocky Linux 服务器使用 Claude Code 连接 DeepSeek API。

## 架构

```
┌──────────────────┐                    ┌──────────────────┐                    ┌───────────┐
│  Linux 服务器     │  SSH 反向隧道       │  Mac 中转机       │                    │  DeepSeek  │
│  (无外网)         │ ←─────────────────→ │  (全天候开启)     │ ────────────────→ │  API      │
│                  │  :2222 → Git推送    │                  │  :9443 → :443     │           │
│  Claude Code     │  :9443 → API隧道    │  autossh         │                    │           │
│  ↓ :9444 HTTP    │                    │  LaunchAgent     │                    │           │
│  Python TLS转发   │                    │  开机自启         │                    │           │
└──────────────────┘                    └──────────────────┘                    └───────────┘
                                              │
                                              ↓ Git Push (post-receive hook)
                                         ┌───────────┐
                                         │  GitHub   │
                                         └───────────┘
```

## 目录结构

```
claude-deepseek-tunnel/
├── README.md                          # 本文档
├── scripts/
│   ├── setup-mac.sh                   # Mac 端一键配置（bare仓库 + 隧道 + LaunchAgent）
│   ├── setup-server.sh                # 服务器端一键配置（Git初始化 + remote + .gitignore）
│   ├── mac-reverse-tunnel.sh          # 反向隧道管理（start/stop/status/test）
│   ├── fwd.py                         # 服务器端 TLS 转发器（:9444 → :9443 → DeepSeek）
│   ├── claude-proxy.sh                # 服务器端 Claude Code 启动包装脚本
│   ├── anthropic-to-openai-proxy.py   # API 格式翻译代理（备用，DeepSeek 有 /anthropic 端点后不需要）
│   └── .gitignore.atmo                # 大气科学项目 .gitignore 模板
├── configs/
│   ├── com.zhangyuxuan.reverse-ssh-tunnel.plist  # Mac 隧道 LaunchAgent
│   └── com.zhangyuxuan.socks-proxy.plist         # Mac SOCKS 代理 LaunchAgent（备用）
└── docs/
    └── git-workflow-guide.md          # Git 中转工作流详细指南
```

## 快速开始

### 前置条件

- Mac 开启「远程登录」（系统设置 → 通用 → 共享）
- Mac 的 SSH 公钥已添加到 GitHub（https://github.com/settings/keys）
- 服务器能通过 SSH 访问（本方案中服务器 IP: `114.212.48.225`）

### 第 1 步：Mac 端配置

```bash
cd scripts
bash setup-mac.sh
```

会自动完成：
- 生成 SSH 密钥（如没有）
- 创建 `~/git_mirror/NCAR_CM1_3D_TC.git` bare 仓库
- 配置 GitHub remote + post-receive 钩子（自动推送）
- 建立反向 SSH 隧道（:2222 给 Git，:9443 给 DeepSeek API）

### 第 2 步：服务器端配置

```bash
# Mac 上传脚本到服务器
scp setup-server.sh zhangyx@114.212.48.225:~/

# SSH 到服务器执行
ssh zhangyx@114.212.48.225
bash ~/setup-server.sh
```

### 第 3 步：安装 Claude Code + cc-switch（一次性）

服务器无外网，需要在 Mac 上下载后传输：

```bash
# === 在 Mac 上 ===
export PATH="/tmp/node-mac/bin:$PATH"

# 下载 Node.js Linux 版
curl -fsSL -o node-linux-x64.tar.gz \
  "https://nodejs.org/dist/v22.14.0/node-v22.14.0-linux-x64.tar.gz"

# 下载 Claude Code 及其 Linux 二进制
npm pack @anthropic-ai/claude-code
npm pack @anthropic-ai/claude-code-linux-x64

# 下载 cc-switch
npm pack @hobeeliu/cc-switch-linux-x64

# 传输到服务器
scp node-linux-x64.tar.gz anthropic-ai-claude-code-*.tgz \
  hobeeliu-cc-switch-linux-x64-*.tgz zhangyx@114.212.48.225:/tmp/

# === 在服务器上 ===
# 安装 Node.js
cd /data1/home/zhangyx && mkdir -p tools && cd tools
tar xzf /tmp/node-linux-x64.tar.gz --strip-components=1
echo 'export PATH="/data1/home/zhangyx/tools/bin:$PATH"' >> ~/.bashrc
export PATH="/data1/home/zhangyx/tools/bin:$PATH"

# 安装 Claude Code（二进制直接复制）
cd /tmp && mkdir claude-install && cd claude-install
tar xzf /tmp/anthropic-ai-claude-code-linux-x64-*.tgz -C pkg --strip-components=1
cp pkg/claude /data1/home/zhangyx/tools/bin/
chmod +x /data1/home/zhangyx/tools/bin/claude

# 安装 cc-switch
mkdir -p /tmp/cc-switch && cd /tmp/cc-switch
tar xzf /tmp/hobeeliu-cc-switch-linux-x64-*.tgz
cp package/cc-switch /data1/home/zhangyx/tools/bin/
chmod +x /data1/home/zhangyx/tools/bin/cc-switch
```

### 第 4 步：配置 cc-switch + DeepSeek

```bash
# 创建 deepseek-pro 配置（复杂任务）
cc-switch new deepseek-pro -i
#   ANTHROPIC_AUTH_TOKEN: sk-你的DeepSeek密钥
#   ANTHROPIC_BASE_URL: https://api.deepseek.com/anthropic
#   确认: y

# 设置模型
cc-switch edit deepseek-pro --field 'env.ANTHROPIC_MODEL' --nano
#   输入: "deepseek-v4-pro"

# 创建 deepseek-flash 配置（简单任务）
cc-switch new deepseek-flash -i
#   同上步骤，模型设为: "deepseek-v4-flash"

# 添加额外配置（直接用 Python）
python3 -c "
import json
with open('/data1/home/zhangyx/.claude/settings.json') as f:
    c = json.load(f)
c['env']['ANTHROPIC_DEFAULT_OPUS_MODEL'] = 'deepseek-v4-pro'
c['env']['ANTHROPIC_DEFAULT_SONNET_MODEL'] = 'deepseek-v4-pro'
c['env']['ANTHROPIC_DEFAULT_HAIKU_MODEL'] = 'deepseek-v4-flash'
c['env']['CLAUDE_CODE_SUBAGENT_MODEL'] = 'deepseek-v4-flash'
c['env']['CLAUDE_CODE_EFFORT_LEVEL'] = 'max'
with open('/data1/home/zhangyx/.claude/settings.json', 'w') as f:
    json.dump(c, f, indent=2)
"
```

### 第 5 步：启动 TLS 转发器 + Claude Code

```bash
# 启动转发器
cp scripts/fwd.py /tmp/
pkill -f fwd.py 2>/dev/null
nohup python3 /tmp/fwd.py > /dev/null 2>&1 &

# 启动 Claude Code
cp scripts/claude-proxy.sh /data1/home/zhangyx/tools/bin/claude-proxy
chmod +x /data1/home/zhangyx/tools/bin/claude-proxy
cd ~/project/TC_dynamic
claude-proxy
```

## 日常使用

```bash
# SSH 到服务器
ssh zhangyx@114.212.48.225
cd /data1/home/zhangyx/project/TC_dynamic

# 选择模型
cc-switch use deepseek-pro     # 复杂任务
cc-switch use deepseek-flash   # 简单任务

# 启动 Claude Code
claude-proxy

# 开发完提交代码
git add .
git commit -m "功能描述"
git push mac main              # 自动同步到 GitHub
```

## 核心链路说明

```
Claude Code (Go 二进制)
  → HTTP http://localhost:9444/anthropic/v1/messages
    → fwd.py (Python TLS 转发器, 添加 Host: api.deepseek.com)
      → HTTPS localhost:9443 (SSH 反向隧道)
        → Mac autossh → api.deepseek.com:443 (/anthropic 端点)
          → DeepSeek API (Anthropic 兼容格式)
```

## 故障排查

| 症状 | 检查 |
|------|------|
| `claude-proxy` 无响应 | `ss -tln \| grep 9444` 确认转发器运行 |
| TLS 转发器 502 | `curl -sk -H 'Host: api.deepseek.com' https://localhost:9443/` 确认隧道通 |
| Git push 失败 | `ss -tln \| grep 2222` 确认 Git 隧道 |
| 隧道断开 | Mac 上 `bash scripts/mac-reverse-tunnel.sh status` |

## 持久化

| 组件 | 重启后 |
|------|:---:|
| Mac 隧道 (2222 + 9443) | ✅ LaunchAgent 自启 |
| 服务器 fwd.py | ✅ bashrc 自启 |
| Claude Code 配置 | ✅ 磁盘文件 |
| Git bare 仓库 | ✅ 磁盘文件 |

## 环境信息

| 角色 | 系统 | 用户 | IP |
|------|------|------|----|
| 服务器 | Rocky Linux 8.10 | zhangyx | 114.212.48.225 |
| Mac 中转 | macOS | zhangyuxuan | 192.168.3.8 |
| GitHub | - | zhangyuxuannju-coder | github.com |
| DeepSeek | - | - | api.deepseek.com |
