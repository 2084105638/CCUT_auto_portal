#!/bin/bash

########################
# 配置区（请按需修改）
########################
TARGET_GATEWAY_PREFIX="100.125."         # 校园网网关前缀
LOG_FILE="/Users/apple/portal_error.log"

PORTAL_URL="http://111.26.29.113:7119/portalLogin.wlan"
WLAN_AC_IP="211.137.223.239"
SSID="edu"
PORTAL_LOGIN="251b7f8865814ab7b7afce8f"

USER_NAME="XXXX" # 请将XXXX替换为你的账号
USER_PWD="XXXX" # 请将XXXX替换为你的密码

RETRY_TIMES=5 # 重试次数
PING_HOST="www.bilibili.com" # 测试网络连通性的主机

########################
# 获取默认网关
########################
function get_gateway() {
    gw=$(route -n get default 2>/dev/null | grep 'gateway:' | awk '{print $2}')
    echo "$gw"
}

########################
# 检查是否处于校园网（判断网关前缀）
########################
function in_school_network() {
    gw=$(get_gateway)

    if [[ $gw == $TARGET_GATEWAY_PREFIX* ]]; then
        return 0
    else
        return 1
    fi
}

########################
# 获取 en0 的 IPv4 地址
########################
function get_local_ip() {
    ip=$(ifconfig en0 | grep "inet " | awk '{print $2}')
    echo "$ip"
}

########################
# 发送 Portal 登录请求
########################
function send_portal_request() {
    local ip="$1"
    timestamp=$(date +%s%3N)

    curl -i -L -c cookies.txt -b cookies.txt \
      -A "Mozilla/5.0 (Macintosh; Intel Mac OS X)" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -H "Referer: http://111.26.29.113:7119/" \
      --data "wlanAcName=&wlanAcIp=$WLAN_AC_IP&wlanUserIp=$ip&ssid=$SSID&portalLogin=$PORTAL_LOGIN&passType=1&userName=$USER_NAME&userPwd=$USER_PWD&saveUser=on" \
    "$PORTAL_URL?$timestamp" >/dev/null 2>&1
}

########################
# Ping 检测网络
########################
function check_network() {
    for ((i = 1; i <= RETRY_TIMES; i++)); do
        echo "检测网络中 (第 $i/$RETRY_TIMES 次): ping $PING_HOST..."

        if ping -c 1 -W 2000 $PING_HOST >/dev/null 2>&1; then
            echo "网络正常！"
            return 0
        fi

        sleep 3
    done

    echo "网络检测失败！"
    return 1
}

########################
# 主流程
########################
echo "检查是否处于校园网..."

if ! in_school_network; then
    echo "当前网关没有匹配校园网 ($TARGET_GATEWAY_PREFIX*)，脚本退出"
    exit 1
fi

echo "已检测到校园网网关，继续执行..."

LOCAL_IP=$(get_local_ip)
if [ -z "$LOCAL_IP" ]; then
    echo "无法获取 en0 IPv4，退出"
    exit 1
fi

echo "本机 IP: $LOCAL_IP"

echo "发送 Portal 登录请求..."
send_portal_request "$LOCAL_IP"

echo "检测网络连通性..."
if ! check_network; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - portal 登录失败或网络仍不可用" >> "$LOG_FILE"
    echo "已写入日志：$LOG_FILE"
    exit 1
fi

echo "登录成功，网络可用！"
exit 0
