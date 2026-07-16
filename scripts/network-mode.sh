#!/bin/bash
# =============================================================================
# network-mode.sh — Mac 网络模式切换（家/学校）
# 用法: bash network-mode.sh [home|school|status]
# =============================================================================

MODE="${1:-status}"
TUNNEL_LOG="/tmp/reverse-ssh-tunnel.log"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.zhangyuxuan.reverse-ssh-tunnel.plist"

get_vpn_ip() {
    ifconfig utun6 2>/dev/null | grep "inet " | awk '{print $2}' | head -1
}

get_local_ip() {
    ifconfig en1 2>/dev/null | grep "inet " | awk '{print $2}' | head -1
}

check_tunnel() {
    if pgrep -f "autossh.*2222" > /dev/null; then
        echo "  ✅ 隧道运行中"
        ssh -o ConnectTimeout=3 zhangyx@114.212.48.225 "ss -tln | grep -E '2222|9443'" 2>/dev/null | while read line; do
            echo "     服务器端口: $line"
        done
    else
        echo "  ❌ 隧道未运行"
    fi
}

check_vpn() {
    local vpn_ip=$(get_vpn_ip)
    if [ -n "$vpn_ip" ]; then
        echo "  ✅ EasyConnect 已连接 (VPN IP: $vpn_ip)"
    else
        echo "  ❌ EasyConnect 未连接"
    fi
}

case "$MODE" in
    status)
        echo "===== 网络状态 ====="
        echo ""
        echo "本地IP:   $(get_local_ip)"
        echo "VPN IP:   $(get_vpn_ip  || echo '无')"
        echo "默认网关: $(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')"
        echo ""
        echo "--- 隧道 ---"
        check_tunnel
        echo ""
        echo "--- VPN ---"
        check_vpn
        echo ""
        echo "--- 关键服务 ---"
        ssh -o ConnectTimeout=3 zhangyx@114.212.48.225 "echo '  ✅ 服务器可达'" 2>/dev/null || echo "  ❌ 服务器不可达"
        echo ""
        echo "当前模式: 隧道为反向连接，Mac IP 变化不影响使用"
        echo "git push:  服务器 → localhost:2222 → Mac（正常）"
        echo "Claude Code:服务器 → localhost:9444 → localhost:9443 → Mac → DeepSeek（正常）"
        ;;

    home)
        echo "===== 切换到「在家」模式 ====="
        echo ""
        echo "反向隧道不依赖 Mac IP，通常无需额外操作。"
        echo ""
        
        # 检查 VPN
        local vpn_ip=$(get_vpn_ip)
        if [ -z "$vpn_ip" ]; then
            echo "⚠️  EasyConnect 未连接，如需要访问校内资源请先连接 VPN。"
        else
            echo "✅ EasyConnect 已连接 ($vpn_ip)"
        fi
        echo ""
        
        # 确保隧道运行
        if ! pgrep -f "autossh.*2222" > /dev/null; then
            echo "隧道未运行，正在启动..."
            launchctl load "$LAUNCHD_PLIST" 2>/dev/null
            sleep 2
        fi
        check_tunnel
        echo ""
        echo "✅ 在家模式配置完成。"
        echo "   Git:      服务器 git push mac main（通过隧道自动到达 Mac）"
        echo "   Claude:   服务器 claude-proxy（通过隧道访问 DeepSeek）"
        echo "   校内资源: 通过 VPN 访问"
        ;;

    school)
        echo "===== 切换到「在校」模式 ====="
        echo ""
        echo "校园网环境下 Mac 有校内 IP，无需 VPN。"
        echo ""
        
        # 确保隧道运行
        if ! pgrep -f "autossh.*2222" > /dev/null; then
            echo "隧道未运行，正在启动..."
            launchctl load "$LAUNCHD_PLIST" 2>/dev/null
            sleep 2
        fi
        check_tunnel
        echo ""
        echo "✅ 在校模式配置完成。"
        ;;

    restart)
        echo "===== 重启隧道 ====="
        launchctl unload "$LAUNCHD_PLIST" 2>/dev/null
        pkill -f autossh 2>/dev/null
        sleep 2
        launchctl load "$LAUNCHD_PLIST" 2>/dev/null
        sleep 3
        check_tunnel
        ;;

    *)
        echo "用法: bash network-mode.sh [home|school|status|restart]"
        echo ""
        echo "  home    - 切换到家模式（配合 EasyConnect VPN）"
        echo "  school  - 切换到在校模式"
        echo "  status  - 查看当前网络状态"
        echo "  restart - 重启 SSH 隧道"
        echo ""
        echo "注意：因为使用反向 SSH 隧道，换网络通常无需任何操作。"
        echo "      本脚本主要用于状态检查和手动管理。"
        ;;
esac
