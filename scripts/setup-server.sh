#!/bin/bash
# =============================================================================
# Linux 服务器 一键配置脚本
# 在服务器上运行（Rocky Linux 8.10, zhangyx@114.212.48.225）
# 作用：初始化 Git 仓库 + 配置 remote 指向 Mac 中转站
# 用法：bash setup-server.sh
# =============================================================================

set -e

# ---------- 配置变量（按需修改） ----------
# Mac 中转机的 SSH 信息
MAC_USER="zhangyuxuan"

# 连接模式选择：
#   "tunnel"  - 使用反向 SSH 隧道（Mac 主动连服务器，推荐内网不通时使用）
#   "direct"  - 直连（需要服务器能访问 Mac 的 IP）
CONNECT_MODE="tunnel"

if [ "$CONNECT_MODE" = "tunnel" ]; then
    # 隧道模式：Mac 运行了 mac-reverse-tunnel.sh 后，
    # 服务器通过 localhost:2222 即可访问 Mac
    MAC_HOST="localhost"
    MAC_PORT="2222"
else
    # 直连模式：需要服务器能 ping 通 Mac
    MAC_HOST="192.168.3.8"
    MAC_PORT="22"
fi

# Mac 上 bare 仓库的绝对路径
MAC_BARE_PATH="/Users/${MAC_USER}/git_mirror/NCAR_CM1_3D_TC.git"

# 构造 Git remote URL
if [ "$MAC_PORT" = "22" ]; then
    MAC_REMOTE_URL="ssh://${MAC_USER}@${MAC_HOST}${MAC_BARE_PATH}"
else
    MAC_REMOTE_URL="ssh://${MAC_USER}@${MAC_HOST}:${MAC_PORT}${MAC_BARE_PATH}"
fi

# 服务器上的项目路径
PROJECT_DIR="/data1/home/zhangyx/project/TC_dynamic"

# remote 名称（和 Mac 端对应）
MAC_REMOTE_NAME="mac"

echo "============================================"
echo " 服务器 Git Remote 配置脚本"
echo "============================================"
echo ""
echo "连接模式:     ${CONNECT_MODE}"
echo "项目路径:     ${PROJECT_DIR}"
echo "Mac 中转仓库: ${MAC_REMOTE_URL}"
echo ""

# ---------- 1. 检查是否可以连接 Mac ----------
echo "[1/4] 测试与 Mac 的 SSH 连接..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
    -p "${MAC_PORT}" "${MAC_USER}@${MAC_HOST}" "echo 'SSH OK'" 2>/dev/null; then
    echo "  ✓ 可以连接到 Mac！"
else
    echo "  ⚠️  无法连接到 ${MAC_USER}@${MAC_HOST}:${MAC_PORT}"
    echo ""
    if [ "$CONNECT_MODE" = "tunnel" ]; then
        echo "  排查步骤："
        echo "  1. 确认 Mac 上已运行 mac-reverse-tunnel.sh start"
        echo "  2. 在 Mac 上运行 mac-reverse-tunnel.sh test 测试隧道"
        echo "  3. 在服务器上检查端口：ss -tln | grep ${MAC_PORT}"
    else
        echo "  可能的原因："
        echo "  1. Mac 的'远程登录'未开启"
        echo "  2. 不在同一网段 → 建议使用 tunnel 模式"
        echo "  3. 防火墙阻止"
    fi
    echo ""
    read -p "  是否继续配置？（SSH 不通但可后续修复）[Y/n]: " cont
    if [ "$cont" = "n" ] || [ "$cont" = "N" ]; then
        exit 1
    fi
fi

# ---------- 2. 确保项目目录存在并初始化 Git ----------
echo ""
echo "[2/4] 初始化 Git 仓库..."
if [ ! -d "$PROJECT_DIR" ]; then
    echo "  错误：项目目录 ${PROJECT_DIR} 不存在！"
    echo "  请确认项目代码已经放在该目录下。"
    exit 1
fi

cd "$PROJECT_DIR"

# 确保 Git 用户信息已配置（否则 commit 会失败）
if ! git config --global user.name > /dev/null 2>&1; then
    echo "  ⚠️  未配置 Git 用户名，正在设置..."
    git config --global user.name "zhangyuxuannju-coder"
    git config --global user.email "zhangyuxuannju-coder@users.noreply.github.com"
    echo "  ✓ 已设置 Git 用户信息"
fi

if [ -d ".git" ]; then
    echo "  .git 已存在，跳过 git init。"
else
    git init
    echo "  ✓ Git 仓库已初始化。"
fi

# 检查是否有 .gitignore
if [ ! -f ".gitignore" ]; then
    echo ""
    echo "  ⚠️  未找到 .gitignore 文件，正在创建默认的 .gitignore..."
    cat > .gitignore << 'IGNORE_EOF'
# =============================================================================
# .gitignore — NCAR CM1 热带气旋 3D 模拟项目
# 严格排除大型数据文件，只跟踪源代码、配置和脚本
# =============================================================================

# ---- CM1 模型输出（超大文件，绝不提交） ----
cm1out_*
*.cm1out

# ---- NetCDF 数据文件 ----
*.nc
*.nc4
*.nc3
*.cdf

# ---- GRIB 气象数据 ----
*.grib
*.grib2
*.grb
*.grb2
*.gb2

# ---- HDF 数据 ----
*.hdf
*.hdf5
*.h5
*.he5

# ---- 二进制输出/中间文件 ----
*.bin
*.dat
*.raw
*.sav

# ---- Fortran 编译产物 ----
*.o
*.mod
*.exe
*.out
*.a
*.so
*.so.*
*.dylib
*.d

# ---- CM1 可执行文件 ----
cm1
cm1.exe
cm1.gpu

# ---- 模型输入/重启文件（通常很大） ----
restart_*
*.rst
*.RST

# ---- Python ----
__pycache__/
*.py[cod]
*.pyo
*.egg-info/
dist/
.pytest_cache/
.ipynb_checkpoints/

# ---- 日志和诊断输出 ----
*.log
*.LOG
slurm-*.out
*.o[0-9]*
*.e[0-9]*

# ---- 输出目录 ----
output/
out/
logs/
runs/
diag/
diagnostics/
data/
DATA/
figures/
plots/
tmp/
temp/

# ---- 备份文件 ----
*~
*.bak
*.backup
*.orig
*.swp

# ---- 压缩包 ----
*.tar
*.tar.gz
*.tar.bz2
*.tgz
*.zip
*.7z

# ---- 系统文件 ----
.DS_Store
Thumbs.db
Desktop.ini

# ---- IDE ----
.vscode/
.idea/

# ---- 环境变量 ----
.env
.env.local
IGNORE_EOF
    echo "  ✓ 已创建 .gitignore（排除了 .nc .grib 等数据文件）。"
fi

# 如果有未跟踪的文件，做首次提交
if git status --porcelain | grep -q '^?'; then
    echo ""
    echo "  检测到未跟踪的文件。是否现在做首次提交？"
    read -p "  [Y/n]: " do_commit
    if [ "$do_commit" != "n" ] && [ "$do_commit" != "N" ]; then
        git add .
        git commit -m "Initial commit: NCAR CM1 3D TC project"
        echo "  ✓ 首次提交完成。"
    fi
else
    echo "  所有文件已跟踪，跳过首次提交。"
fi

# ---------- 3. 配置 remote 指向 Mac ----------
echo ""
echo "[3/4] 配置 Git remote → Mac 中转站..."

if git remote | grep -q "^${MAC_REMOTE_NAME}$"; then
    current_url=$(git remote get-url "$MAC_REMOTE_NAME" 2>/dev/null)
    if [ "$current_url" != "$MAC_REMOTE_URL" ]; then
        git remote set-url "$MAC_REMOTE_NAME" "$MAC_REMOTE_URL"
        echo "  ✓ 已更新 ${MAC_REMOTE_NAME} remote URL"
        echo "    ${MAC_REMOTE_URL}"
    else
        echo "  ${MAC_REMOTE_NAME} remote 已正确配置，跳过。"
        echo "    ${MAC_REMOTE_URL}"
    fi
else
    git remote add "$MAC_REMOTE_NAME" "$MAC_REMOTE_URL"
    echo "  ✓ 已添加 ${MAC_REMOTE_NAME} remote"
    echo "    ${MAC_REMOTE_URL}"
fi

# ---------- 4. 验证配置 ----------
echo ""
echo "[4/4] 验证配置..."

echo ""
echo "  Git remote 列表："
git remote -v

echo ""
echo "  当前 Git 状态："
git status --short

# ---------- 完成 ----------
echo ""
echo "============================================"
echo " ✅ 服务器 Git 配置完成！"
echo "============================================"
echo ""
echo "日常使用流程："
echo ""
echo "  # 修改代码后："
echo "  git add ."
echo "  git commit -m \"描述你的修改\""
echo "  git push mac main        # 推送到 Mac 中转站"
echo ""
echo "  # Mac 会自动将代码转发到 GitHub"
echo "  # 查看 Mac 推送日志：ssh ${MAC_USER}@${MAC_IP} 'cat /tmp/git-mirror-push.log'"
echo ""
echo "  # 如果 Mac 连接不通，检查："
echo "  # 1. Mac 远程登录是否开启"
echo "  # 2. 是否在同一网络/已配置 Tailscale"
echo "  # 3. 防火墙是否放行 SSH 端口"
echo ""
