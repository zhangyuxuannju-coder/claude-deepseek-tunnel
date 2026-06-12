#!/bin/bash
# =============================================================================
# Mac 中转机 一键配置脚本
# 作用：创建 Git bare 仓库 + post-receive 钩子，自动推送到 GitHub
# 用法：bash setup-mac.sh
# =============================================================================

set -e

# ---------- 配置变量（按需修改） ----------
GITHUB_USER="zhangyuxuannju-coder"
GITHUB_REPO="NCAR_CM1_3D_TC"
GITHUB_URL="git@github.com:${GITHUB_USER}/${GITHUB_REPO}.git"

# Mac 上的 bare 仓库根目录
BARE_ROOT="$HOME/git_mirror"
BARE_REPO="${BARE_ROOT}/${GITHUB_REPO}.git"

# 用于 post-receive 推送的 GitHub remote 名
GITHUB_REMOTE_NAME="github"

echo "============================================"
echo " Mac Git 中转站 配置脚本"
echo "============================================"
echo ""
echo "Bare 仓库路径: ${BARE_REPO}"
echo "GitHub 目标:   ${GITHUB_URL}"
echo ""

# ---------- 1. 检查 SSH 密钥 ----------
if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ]; then
    echo "[1/5] 未找到 SSH 密钥，正在生成新的 Ed25519 密钥..."
    ssh-keygen -t ed25519 -C "zhangyuxuan-mac-git-mirror" -f "$HOME/.ssh/id_ed25519" -N ""
    echo ""
    echo "⚠️  请将以下公钥添加到 GitHub → Settings → SSH and GPG keys："
    echo "================================================================="
    cat "$HOME/.ssh/id_ed25519.pub"
    echo "================================================================="
    echo ""
    read -p "添加完成后按回车继续..." </dev/tty
else
    echo "[1/5] SSH 密钥已存在，跳过生成。"
fi

# ---------- 2. 测试 GitHub 连接 ----------
echo ""
echo "[2/5] 测试 GitHub SSH 连接..."
if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "  ✓ GitHub SSH 连接成功！"
else
    echo "  ⚠️  GitHub SSH 连接失败。请确认："
    echo "     1. SSH 公钥已添加到 https://github.com/settings/keys"
    echo "     2. 网络可以访问 github.com"
    echo "  （继续执行，但推送可能失败）"
fi

# ---------- 3. 创建 bare 仓库 ----------
echo ""
echo "[3/5] 创建 bare 仓库..."
mkdir -p "$BARE_ROOT"
if [ -d "$BARE_REPO" ]; then
    echo "  Bare 仓库已存在，跳过创建。"
else
    git init --bare "$BARE_REPO"
    echo "  ✓ Bare 仓库已创建：${BARE_REPO}"
fi

# ---------- 4. 配置 GitHub remote（在 bare 仓库中） ----------
echo ""
echo "[4/5] 配置 GitHub remote（在 bare 仓库内）..."
cd "$BARE_REPO"
if git remote | grep -q "^${GITHUB_REMOTE_NAME}$"; then
    current_url=$(git remote get-url "$GITHUB_REMOTE_NAME")
    if [ "$current_url" != "$GITHUB_URL" ]; then
        git remote set-url "$GITHUB_REMOTE_NAME" "$GITHUB_URL"
        echo "  ✓ 已更新 ${GITHUB_REMOTE_NAME} remote URL"
    else
        echo "  ${GITHUB_REMOTE_NAME} remote 已配置，跳过。"
    fi
else
    git remote add "$GITHUB_REMOTE_NAME" "$GITHUB_URL"
    echo "  ✓ 已添加 ${GITHUB_REMOTE_NAME} remote → ${GITHUB_URL}"
fi

# ---------- 5. 创建 post-receive 钩子 ----------
echo ""
echo "[5/5] 创建 post-receive 钩子（自动推送到 GitHub）..."

HOOK_FILE="${BARE_REPO}/hooks/post-receive"

cat > "$HOOK_FILE" << 'HOOK_EOF'
#!/bin/bash
# =============================================================================
# post-receive 钩子：当服务器 git push 到 Mac bare 仓库后，
# 自动将代码推送到 GitHub
# =============================================================================

# GitHub remote 名称（和 setup 脚本中保持一致）
GITHUB_REMOTE="github"

# 日志文件
LOG_FILE="/tmp/git-mirror-push.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] post-receive 触发，开始推送到 GitHub..." >> "$LOG_FILE"

# 进入 bare 仓库目录
cd "$GIT_DIR"

# 推送到 GitHub（推送所有分支和标签）
git push "$GITHUB_REMOTE" --all  >> "$LOG_FILE" 2>&1
git push "$GITHUB_REMOTE" --tags >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ 推送成功" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ 推送失败，请检查日志" >> "$LOG_FILE"
fi
HOOK_EOF

chmod +x "$HOOK_FILE"
echo "  ✓ post-receive 钩子已创建：${HOOK_FILE}"

# ---------- 完成 ----------
echo ""
echo "============================================"
echo " ✅ Mac 中转站配置完成！"
echo "============================================"
echo ""
echo "下一步："
echo "  1. 确保 Mac '远程登录'已开启（系统设置 → 通用 → 共享 → 远程登录）"
echo "  2. 在服务器上运行：bash setup-server.sh"
echo ""
echo "Mac 信息："
echo "  用户名: $(whoami)"
echo "  IP地址: $(ifconfig 2>/dev/null | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"
echo "  Bare仓库: ${BARE_REPO}"
echo "  推送日志: /tmp/git-mirror-push.log"
echo ""
