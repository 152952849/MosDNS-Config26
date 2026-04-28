#!/bin/sh

# --- 配置区 ---
# 获取IP的API地址
API_URL="https://ip.164746.xyz/ipTop.html"
# MosDNS 配置文件路径
CONFIG_FILE="/etc/mosdns/config_custom.yaml"
# 配置项的关键行标识
TARGET_KEYWORD="- exec: black_hole"
# 日志文件（可选）
LOG_FILE="/var/log/update_cf_ip.log"
# --- 配置结束 ---

# 记录日志函数
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_info "开始更新 Cloudflare IP 列表..."

# 1. 从 API 获取 IP 列表，并清理格式
#    - 使用 curl -s 静默获取
#    - 使用 grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' 提取IP地址
#    - 使用 tr '\n' ' ' 将多行输出合并为单行，IP之间用空格分隔
NEW_IPS=$(curl -s "$API_URL" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | tr '\n' ' ')
# 去除末尾可能多余的空格
NEW_IPS=$(echo "$NEW_IPS" | sed 's/[[:space:]]*$//')

# 2. 检查是否成功获取到 IP
if [ -z "$NEW_IPS" ]; then
    log_info "错误：未能从 $API_URL 获取到任何 IP 地址"
    exit 1
fi

log_info "成功获取 IP 地址: $NEW_IPS"

# 3. 构建新的完整配置行
#    原行：'- exec: black_hole 172.64.148.196 172.64.52.131 ... # best_cloudflare_ipv4'
#    新行：'- exec: black_hole IP1 IP2 IP3 ... # best_cloudflare_ipv4'
NEW_LINE="      - exec: black_hole $NEW_IPS # best_cloudflare_ipv4"

# 4. 使用 sed 替换配置文件中的目标行
#    - -i.bak: 直接修改文件，并创建备份 .bak
#    - s|^.*TARGET_KEYWORD.*$|$NEW_LINE|: 找到包含关键字的整行并替换
if sed -i.bak "s|^.*$TARGET_KEYWORD.*$|$NEW_LINE|" "$CONFIG_FILE"; then
    log_info "配置文件 $CONFIG_FILE 更新成功"
else
    log_info "错误：配置文件更新失败"
    exit 1
fi

# 5. 重启 MosDNS 服务使配置生效
#    OpenWrt 标准服务管理命令
if /etc/init.d/mosdns restart; then
    log_info "MosDNS 服务重启成功"
else
    log_info "警告：MosDNS 服务重启可能失败，请手动检查服务状态"
    exit 1
fi

log_info "更新流程结束"
exit 0