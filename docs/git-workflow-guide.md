# Git 中转工作流 完整指南

## 架构概览

```
┌──────────────────┐     git push via SSH     ┌──────────────────┐     git push      ┌───────────┐
│  Linux 服务器     │ ───────────────────────→ │  Mac 中转机       │ ───────────────→ │  GitHub   │
│  114.212.48.225  │                          │  192.168.3.8     │                  │           │
│                  │                          │  (全天候开启)     │                  │           │
│  数值模拟        │                          │                  │                  │           │
│  AI Agent        │                          │  bare 仓库       │                  │ 代码备份  │
│  DeepSeek API    │                          │  post-receive    │                  │ 版本历史  │
└──────────────────┘                          │  → 自动推GitHub  │                  └───────────┘
        ↑                                     └──────────────────┘                       ↑
        │ SSH 开发                                    │                                 │
        │                                             │ SSH                             │ git clone
        │                                             ↓                                 │
┌──────────────────┐                          ┌──────────────────┐              ┌──────────────────┐
│  Win 个人电脑     │                          │  Mac 本机         │              │  Win 个人电脑      │
│                  │                          │  (可选直接修改)   │              │  (查看代码)       │
└──────────────────┘                          └──────────────────┘              └──────────────────┘
```

## 硬件信息

| 角色 | 系统 | 用户 | IP | 作用 |
|------|------|------|----|------ |
| 服务器 | Rocky Linux 8.10 | zhangyx | 114.212.48.225 | 数值模拟、AI Agent |
| Mac 中转 | macOS | zhangyuxuan | 192.168.3.8 | Git 中转、推送到 GitHub |
| Win | Windows | - | - | SSH 开发 / 查看代码 |
| GitHub | - | zhangyuxuannju-coder | github.com | 代码远程备份 |

## 前置条件

- [ ] Mac 开启「远程登录」（系统设置 → 通用 → 共享 → 远程登录）
- [ ] 服务器能 SSH 到 Mac（同网段或使用 Tailscale）
- [ ] Mac 的 SSH 公钥已添加到 GitHub

---

## 一、Mac 端配置（本机）

### 1.1 运行一键脚本

```bash
cd ~/Desktop/zotero
chmod +x setup-mac.sh
bash setup-mac.sh
```

脚本会：
1. 生成 SSH 密钥（如果没有）→ 需要添加到 GitHub
2. 创建 `~/git_mirror/NCAR_CM1_3D_TC.git` bare 仓库
3. 配置 GitHub remote
4. 创建 post-receive 钩子（自动推送）

### 1.2 手动添加 SSH 公钥到 GitHub

如果脚本生成了新 SSH 密钥，复制公钥：

```bash
cat ~/.ssh/id_ed25519.pub
```

然后到 https://github.com/settings/keys → New SSH Key → 粘贴。

### 1.3 手动开启远程登录

如果还没开启：
- 系统设置 → 通用 → 共享 → 打开「远程登录」
- 允许访问：选择「所有用户」或指定你的用户

### 1.4 验证 SSH 可用

在服务器上测试能否 SSH 到 Mac：

```bash
# 先在本机测试
ssh zhangyuxuan@192.168.3.8 "echo OK"
```

---

## 二、服务器端配置

### 2.1 传输脚本到服务器

```bash
# 在 Mac 上执行
scp ~/Desktop/zotero/setup-server.sh zhangyx@114.212.48.225:~/
```

### 2.2 SSH 到服务器运行

```bash
ssh zhangyx@114.212.48.225
cd ~
chmod +x setup-server.sh
bash setup-server.sh
```

### 2.3 配置 SSH 免密登录（服务器 → Mac）

```bash
# 在服务器上生成 SSH 密钥（如果没有）
ssh-keygen -t ed25519 -C "server-to-mac" -N "" -f ~/.ssh/id_ed25519

# 复制公钥
cat ~/.ssh/id_ed25519.pub
```

然后**在 Mac 上**将此公钥添加到信任列表：

```bash
# 在 Mac 上执行
echo "粘贴服务器公钥到这里" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

或者从服务器直接：

```bash
# 在服务器上执行（会提示输入 Mac 的密码）
ssh-copy-id zhangyuxuan@192.168.3.8
```

---

## 三、建立 Mac ↔ 服务器连通（反向 SSH 隧道）

> 由于服务器无法直接访问 Mac 的内网 IP（192.168.3.8），我们使用 **反向 SSH 隧道**：Mac 主动连接服务器，在服务器上开放一个端口转发回 Mac。

### 3.1 在 Mac 上启动反向隧道

```bash
cd ~/Desktop/zotero
bash mac-reverse-tunnel.sh start
```

检查状态：
```bash
bash mac-reverse-tunnel.sh status
```

### 3.2 配置服务器 SSH 免密到 Mac

服务器通过隧道连接到 Mac 时，需要免密认证。

**方式一（推荐）：从服务器直接注入公钥**
```bash
# 先在 Mac 上确认隧道已启动
bash mac-reverse-tunnel.sh start

# SSH 到服务器
ssh zhangyx@114.212.48.225

# 在服务器上生成密钥（如果没有）
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519

# 通过隧道把公钥复制到 Mac（会提示输入 Mac 密码）
ssh-copy-id -p 2222 zhangyuxuan@localhost
```

**方式二：手动添加**
```bash
# 在服务器上查看公钥
ssh zhangyx@114.212.48.225 "cat ~/.ssh/id_ed25519.pub"

# 在 Mac 上手动追加到 authorized_keys
echo "粘贴服务器的公钥" >> ~/.ssh/authorized_keys
```

### 3.3 测试隧道连通性

```bash
# 在 Mac 上运行
bash mac-reverse-tunnel.sh test
```

### 3.4 设置隧道开机自启（重要！）

```bash
# 将 LaunchAgent 复制到系统目录
cp ~/Desktop/zotero/com.zhangyuxuan.reverse-ssh-tunnel.plist ~/Library/LaunchAgents/

# 加载（立即生效）
launchctl load ~/Library/LaunchAgents/com.zhangyuxuan.reverse-ssh-tunnel.plist

# 验证
launchctl list | grep reverse-ssh
```

之后 Mac 每次开机都会自动建立反向隧道。

> **备选方案：Tailscale**
> 如果隧道方案不适用，可在两台机器上都安装 Tailscale（免费），获得 100.x.x.x 的虚拟 IP。然后将 `setup-server.sh` 中的 `CONNECT_MODE` 改为 `direct`，`MAC_HOST` 改为 Tailscale IP。

---

## 四、日常操作

### 核心原则：所有代码修改在服务器上进行

### 4.1 一天的开始

```bash
# 从 Win 或 Mac SSH 到服务器
ssh zhangyx@114.212.48.225
cd /data1/home/zhangyx/project/TC_dynamic

# 拉取最新代码（如果 Mac 上有其他人的推送）
git pull mac main
```

### 4.2 开发 + 提交 + 推送

```bash
cd /data1/home/zhangyx/project/TC_dynamic

# 1. 使用 AI Agent 编写代码（例如 Aider）
aider --model deepseek/deepseek-chat
# 或者手动编辑

# 2. 本地提交
git add .
git commit -m "描述修改内容"

# 3. 推送到 Mac 中转站
git push mac main

# Mac 的 post-receive 钩子会自动推送到 GitHub
```

### 4.3 验证 GitHub 同步

```bash
# 在服务器上查看推送日志
ssh zhangyuxuan@192.168.3.8 "cat /tmp/git-mirror-push.log"
```

或者直接打开 https://github.com/zhangyuxuannju-coder/NCAR_CM1_3D_TC 查看。

### 4.4 Win 电脑上查看代码

```bash
# 直接从 GitHub 克隆（只读查看）
git clone https://github.com/zhangyuxuannju-coder/NCAR_CM1_3D_TC.git

# 或者 SSH 到服务器开发
ssh zhangyx@114.212.48.225
```

> ⚠️ 注意：不要在 Win 本地修改后直接 push 到 GitHub，这会导致与服务器的冲突。

---

## 五、在服务器上安装 AI Agent (Aider)

```bash
# SSH 到服务器后执行
pip install aider-chat -i https://pypi.tuna.tsinghua.edu.cn/simple

# 配置 DeepSeek API
export OPENAI_API_BASE=https://api.deepseek.com/v1
export OPENAI_API_KEY=你的DeepSeek密钥

# 建议写入 ~/.bashrc 使环境变量永久生效
cat >> ~/.bashrc << 'EOF'
export OPENAI_API_BASE=https://api.deepseek.com/v1
export OPENAI_API_KEY=你的DeepSeek密钥
EOF

# 在项目目录中启动 Aider
cd /data1/home/zhangyx/project/TC_dynamic
aider --model deepseek/deepseek-chat
```

---

## 六、数据文件保护

`.gitignore` 已自动配置排除：
- `.nc`, `.grib`, `.grib2`, `.grb` — 大气科学数据
- `.hdf`, `.hdf5`, `.h5` — HDF 格式数据
- `.dat`, `.bin` — 二进制数据
- `__pycache__/`, `.pyc` — Python 缓存
- `*.o`, `*.mod`, `*.exe` — 编译产物

这些文件不会进入 Git，也不会被推送到 GitHub。

---

## 七、故障排查

### GitHub 推送失败

```bash
# 查看 Mac 推送日志
ssh zhangyuxuan@192.168.3.8 "cat /tmp/git-mirror-push.log"

# 手动测试 Mac → GitHub
ssh zhangyuxuan@192.168.3.8 "cd ~/git_mirror/NCAR_CM1_3D_TC.git && git push github --all"
```

### 服务器无法推送到 Mac

```bash
# 1. 测试 SSH 连接
ssh zhangyuxuan@192.168.3.8 "echo OK"

# 2. 检查 Mac 远程登录
# Mac: 系统设置 → 通用 → 共享 → 远程登录

# 3. 检查 Mac IP 是否变化
# Mac: ifconfig | grep "inet "
```

### Git 冲突

如果你不小心在 Mac 本地也修改了代码并推送了：

```bash
# 在服务器上先拉取再推送
git pull mac main --rebase
git push mac main
```

---

## 八、备份建议

- **Mac bare 仓库**：`~/git_mirror/NCAR_CM1_3D_TC.git`，可用 Time Machine 备份
- **GitHub**：代码的最终存放地，是主要备份
- **服务器代码**：数值模拟结果（.nc 等）用 rsync 或其他方式单独备份

---

## 九、一键重新配置

如果 Mac IP 变了或环境出问题，只需重新运行：

```bash
# Mac 端（基本上不需要重跑，除非 bare 仓库被删）
bash ~/Desktop/zotero/setup-mac.sh

# 服务器端（修改 setup-server.sh 中的 MAC_IP 后重跑）
bash setup-server.sh
```
