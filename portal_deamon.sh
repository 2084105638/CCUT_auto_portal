#!/bin/bash

###############################
# 配置区域
###############################
TARGET_GATEWAY_PREFIX="100.125."   # 校园网网关前缀
PING_HOST="www.bilibili.com"       # 用于检测联网
RETRY_AFTER_ONLINE_SECONDS=3       # 联网后需要稳定多少秒再执行 Portal
CHECK_INTERVAL_NO_NETWORK=5        # 无网络时多久检查一次
CHECK_INTERVAL_NETWORK=10          # 有网络时多久检查一次
PORTAL_SCRIPT="./auto_portal.sh"  # 登录逻辑脚本

###############################
# 函数：获取默认网关
###############################
get_gateway() {
    route -n get default 2>/dev/null | grep 'gateway:' | awk '{print $2}'
}

###############################
# 函数：检测是否在校园网
###############################
in_school_network() {
    gw=$(get_gateway)
    [[ "$gw" == $TARGET_GATEWAY_PREFIX* ]]
    return $?  # 0 true, 1 false
}

###############################
# 函数：检测是否联网
###############################
is_online() {
    ping -c 1 -W 2000 $PING_HOST >/dev/null 2>&1
    return $?  # 0 online, 1 offline
}

###############################
# 主循环（常驻后台）
###############################

echo "[守护进程] Portal 监测启动..."

while true; do

    # 第一阶段：在线状态监测
    if is_online; then
        echo "[状态] 联网正常，$CHECK_INTERVAL_NETWORK 秒后再次检查..."
        sleep $CHECK_INTERVAL_NETWORK
        continue
    fi

    # 第二阶段：检测到断网
    echo "[状态] 检测到断网，开始等待网络恢复..."

    # 断网状态循环（睡眠等待，低 CPU）
    while ! is_online; do
        echo "[等待] 仍无网络，$CHECK_INTERVAL_NO_NETWORK 秒后再试..."
        sleep $CHECK_INTERVAL_NO_NETWORK
    done

    echo "[唤醒] 检测到网络恢复，等待 $RETRY_AFTER_ONLINE_SECONDS 秒稳定..."
    sleep $RETRY_AFTER_ONLINE_SECONDS

    # 第三阶段：网络恢复后检查是否校园网
    if in_school_network; then
        echo "[执行] 当前处于校园网，执行 Portal 登录脚本..."
        bash "$PORTAL_SCRIPT"
    else
        echo "[跳过] 当前不在校园网（网关不匹配），跳过登录。"
    fi

    echo "[循环] 进入新一轮检测..."
done
