#!/bin/bash
set -eu

# CF-Server-Monitor 本地安装脚本
# 使用原版探针内置的 install 命令进行安装，确保 100% 兼容所有官方参数

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_FILE="$SCRIPT_DIR/cf-probe-linux-amd64"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    printf '%s\n' "$*"
}

die() {
    printf "${RED}[ERROR]${NC} %s\n" "$*" >&2
    exit 1
}

success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$*"
}

# 检查二进制文件是否存在
if [ ! -f "$BINARY_FILE" ]; then
    die "Binary file not found: $BINARY_FILE"
fi

# 检查是否为 root
if [ "$(id -u)" -ne 0 ]; then
    die "This script must be run as root"
fi

# 如果没有传递任何参数，则尝试读取 config.json
INSTALL_ARGS=("$@")
if [ ${#INSTALL_ARGS[@]} -eq 0 ]; then
    if [ -f "$SCRIPT_DIR/config.json" ]; then
        log "No arguments provided, reading parameters from config.json..."
        # 使用 python 解析 config.json 并生成参数数组
        PARSED_ARGS=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        cfg = json.load(f)
    print(" ".join([f"-{k}={v}" for k, v in cfg.items() if not k.startswith(("_", "/"))]))
except Exception as e:
    sys.exit(1)
' "$SCRIPT_DIR/config.json")
        
        if [ $? -ne 0 ]; then
            die "Failed to parse config.json. Ensure python3 is installed and config is valid."
        fi
        
        # 将解析出来的字符串拆分为数组
        read -r -a INSTALL_ARGS <<< "$PARSED_ARGS"
    else
        die "No arguments provided and config.json not found."
    fi
fi

INSTALL_DIR="/usr/local/bin"
mkdir -p "$INSTALL_DIR"

# 停止并卸载旧服务（不管它当前是不是 running 状态）
log "Cleaning up existing cf-probe service if any..."
systemctl stop cf-probe 2>/dev/null || true
if [ -f "$INSTALL_DIR/cf-probe" ]; then
    "$INSTALL_DIR/cf-probe" uninstall 2>/dev/null || true
fi

# 复制二进制文件
log "Installing cf-probe binary..."
cp "$BINARY_FILE" "$INSTALL_DIR/cf-probe"
chmod +x "$INSTALL_DIR/cf-probe"

# 执行官方原版的 install 流程
log "Running official cf-probe install..."
"$INSTALL_DIR/cf-probe" install "${INSTALL_ARGS[@]}"

# 确保服务启动
systemctl daemon-reload 2>/dev/null || true
systemctl enable cf-probe 2>/dev/null || true
systemctl start cf-probe 2>/dev/null || true

log ""
log "================================================================================"
success "Installation completed!"
log "================================================================================"
