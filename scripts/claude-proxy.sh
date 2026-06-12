#!/bin/bash
# claude-proxy — 通过 proxychains-ng + SOCKS5 隧道连接 DeepSeek
export PROXYCHAINS_CONF_FILE=/data1/home/zhangyx/tools/etc/proxychains.conf
export LD_PRELOAD=/data1/home/zhangyx/tools/lib/libproxychains4.so
exec /data1/home/zhangyx/tools/bin/claude "$@"
