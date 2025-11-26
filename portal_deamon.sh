#!/bin/bash

###############################
# 配置区域
###############################
TARGET_GATEWAY_PREFIX="100.125."     # 校园网网关前缀
CHECK_INTERVAL_NO_NETWORK=5          # 断网检查间隔
CHECK_INTERVAL_NETWORK=10            # 联网常规检查间隔
PORTAL_SCRIPT="./auto_portal.sh"     # 登录脚本

PING_TARGET="223.5.5.5"              # 避免被 DNS/VPN 误导（阿里DNS）
WIFI_IFACE="en0"                     # WiFi 网卡

###############################
# 获取默认网关
###############################
get_gateway() {
    route -n get default 2>/dev/null | awk '/gateway/ {print $2}'
}

###############################
# 获取 en0 的本机 IP
###############################
get_local_ip() {
    ifconfig $WIFI_IFACE | awk '/inet /{print $2}'
}

###############################
# 是否处于校园网（根据网关前缀）
###############################
in_school_network() {
    gw=$(get_gateway)
    [[ "$gw" == $TARGET_GATEWAY_PREFIX* ]]
}

###############################
# 真实外网检测（强制绕过 VPN）
###############################
is_online() {
    local_ip=$(get_local_ip)
    [[ -z "$local_ip" ]] && return 1

    ping -S "$local_ip" -c 1 -W 2000 "$PING_TARGET" >/dev/null 2>&1
}

###############################
# 主循环
###############################
echo "[守护进程] Portal 后台检测启动..."

while true; do

    ##############################
    # 情况 1：外网畅通
    ##############################
    if is_online; then
        echo "[状态] 正常上网，$CHECK_INTERVAL_NETWORK 秒后检查..."
        sleep $CHECK_INTERVAL_NETWORK
        continue
    fi

    ##############################
    # 外网不通 → 检查是否校园网未登录
    ##############################
    echo "[警告] 外网不通，检测网关..."

    if in_school_network; then
        echo "[判断] 在校园网，但外网不通 → 很可能是未登录 Portal"
        echo "[执行] 调用 Portal 登录脚本..."
        bash "$PORTAL_SCRIPT"
        sleep 3
        continue
    fi

    ##############################
    # 情况 2：网关不是校园网 → 真正断网
    ##############################
    echo "[状态] 不在校园网，进入断网等待模式..."

    while ! is_online; do

        # 进入校园网但没外网 → 自动登录
        if in_school_network; then
            echo "[唤醒] 已进入校园网但外网仍不通 → 登录 Portal"
            bash "$PORTAL_SCRIPT"
            sleep 3
            break
        fi

        echo "[等待] 断网中，$CHECK_INTERVAL_NO_NETWORK 秒后重试..."
        sleep $CHECK_INTERVAL_NO_NETWORK
    done

    echo "[状态] 网络恢复，继续守护..."
done