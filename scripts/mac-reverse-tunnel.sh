#!/bin/bash
# =============================================================================
# Mac 反向 SSH 隧道脚本
# 作用：在 Mac 上建立一个到服务器的反向 SSH 隧道，
#       让服务器可以通过 localhost:2222 访问 Mac 的 SSH（端口 22）
# 
# 这是解决「服务器无法直接访问 Mac 内网 IP」的关键脚本。
# 需要在 Mac 上运行，并建议设为开机自启。
# =============================================================================

SERVER_USER="zhangyx"
SERVER_IP="114.212.48.225"
TUNNEL_PORT="2222"    # 服务器上的转发端口（可以自定义）

echo "============================================"
echo " 反向 SSH 隧道 管理脚本"
echo "============================================"
echo ""
echo "服务器: ${SERVER_USER}@${SERVER_IP}"
echo "隧道:   服务器 localhost:${TUNNEL_PORT} → Mac localhost:22"
echo ""

ACTION="${1:-start}"

case "$ACTION" in
  start)
    echo "正在启动反向 SSH 隧道..."
    
    # 检查是否已有 autossh 在运行
    if pgrep -f "autossh.*${TUNNEL_PORT}:localhost:22.*${SERVER_IP}" > /dev/null; then
        echo "  隧道已在运行中。"
        pgrep -af "autossh.*${TUNNEL_PORT}" | head -3
        exit 0
    fi
    
    # 使用 autossh 维持隧道（自动重连）
    # -M 0: 禁用 autossh 监控端口，使用 SSH 自身的 keepalive
    # -N: 不执行远程命令
    # -R: 反向隧道
    # -o ServerAliveInterval=60: 每60秒发心跳
    # -o ServerAliveCountMax=3: 3次心跳失败后断开
    # -o ExitOnForwardFailure=yes: 转发失败则退出
    autossh -M 0 \
        -o "ServerAliveInterval=60" \
        -o "ServerAliveCountMax=3" \
        -o "ExitOnForwardFailure=yes" \
        -o "StrictHostKeyChecking=accept-new" \
        -N \
        -R "${TUNNEL_PORT}:localhost:22" \
        "${SERVER_USER}@${SERVER_IP}" &
    
    sleep 2
    
    if pgrep -f "autossh.*${TUNNEL_PORT}:localhost:22" > /dev/null; then
        echo "  ✓ 隧道启动成功！"
        echo ""
        echo "现在服务器可以通过以下方式访问 Mac："
        echo "  ssh -p ${TUNNEL_PORT} zhangyuxuan@localhost"
        echo ""
        echo "服务器 Git remote URL："
        echo "  ssh://zhangyuxuan@localhost:${TUNNEL_PORT}/Users/zhangyuxuan/git_mirror/NCAR_CM1_3D_TC.git"
    else
        echo "  ✗ 隧道启动失败，请检查 SSH 连接。"
        echo ""
        echo "先测试基本连接："
        echo "  ssh ${SERVER_USER}@${SERVER_IP} 'echo OK'"
    fi
    ;;

  stop)
    echo "正在停止反向 SSH 隧道..."
    pkill -f "autossh.*${TUNNEL_PORT}:localhost:22.*${SERVER_IP}" 2>/dev/null
    pkill -f "ssh.*${TUNNEL_PORT}:localhost:22.*${SERVER_IP}" 2>/dev/null
    sleep 1
    if pgrep -f "${TUNNEL_PORT}:localhost:22.*${SERVER_IP}" > /dev/null; then
        echo "  ✗ 停止失败，还有进程在运行。"
        pgrep -af "${TUNNEL_PORT}" | head -5
    else
        echo "  ✓ 隧道已停止。"
    fi
    ;;

  status)
    echo "检查隧道状态..."
    if pgrep -f "autossh.*${TUNNEL_PORT}:localhost:22" > /dev/null; then
        echo "  ✓ 隧道运行中："
        pgrep -af "autossh.*${TUNNEL_PORT}:localhost:22" | head -3
    else
        echo "  ✗ 隧道未运行。"
    fi
    ;;

  test)
    echo "测试服务器端的隧道连接..."
    echo ""
    
    # 先检查服务器上端口是否在监听
    ssh "${SERVER_USER}@${SERVER_IP}" "ss -tln | grep ${TUNNEL_PORT} || echo '  ⚠ 端口 ${TUNNEL_PORT} 未监听，隧道可能未建立'"
    echo ""
    
    # 测试通过隧道 SSH 回 Mac
    echo "测试通过隧道连接 Mac..."
    ssh "${SERVER_USER}@${SERVER_IP}" \
        "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -p ${TUNNEL_PORT} zhangyuxuan@localhost 'echo \"隧道连通！Mac 主机名: \$(hostname)\"' 2>&1"
    ;;

  *)
    echo "用法: $0 {start|stop|status|test}"
    echo ""
    echo "  start   - 启动反向 SSH 隧道（后台运行，断线自动重连）"
    echo "  stop    - 停止隧道"
    echo "  status  - 查看隧道运行状态"
    echo "  test    - 测试隧道是否连通"
    exit 1
    ;;
esac
