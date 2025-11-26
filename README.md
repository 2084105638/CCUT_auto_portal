## 介绍

`auto_portal.sh` 与 `portal_deamon.sh` 用于在 CCUT 校园网环境下自动检测联网状态并完成 Portal 登录。其中：
- `auto_portal.sh`：单次执行的登录脚本，负责检测网关、获取本机 IP 并向 Portal 发送登录请求。
- `portal_deamon.sh`：常驻守护脚本，持续监听网络状态，掉线后自动调用 `auto_portal.sh` 重新登录。

## 环境要求

- macOS（脚本使用了 `route -n get default`、`ifconfig en0` 等 macOS 命令）
- 已安装 `curl`、`ping`
- 能访问学校 Portal 地址 `http://111.26.29.113:7119`

## 配置步骤

1. 打开 `auto_portal.sh`，根据自身情况修改以下变量：
   - `TARGET_GATEWAY_PREFIX`：校园网网关前缀，例如 `100.125.`。
   - `PORTAL_URL`、`WLAN_AC_IP`、`SSID`、`PORTAL_LOGIN`：学校 Portal 的接口参数。
   - `USER_NAME`、`USER_PWD`：个人账号与密码（请注意安全，配合 `.gitignore` 忽略 `cookies.txt`）。
   - `LOG_FILE`、`PING_HOST`、`RETRY_TIMES` 等可按需调整。
2. 如需更换网卡或接口，修改 `get_local_ip` 中的网卡名称（默认 `en0`）。
3. 在 `portal_deamon.sh` 中确认以下变量：
   - `TARGET_GATEWAY_PREFIX`：需与 `auto_portal.sh` 保持一致。
   - `PING_HOST`、`RETRY_AFTER_ONLINE_SECONDS`、`CHECK_INTERVAL_NO_NETWORK`、`CHECK_INTERVAL_NETWORK`：控制检测频率。
   - `PORTAL_SCRIPT`：指向 `auto_portal.sh` 的路径（默认当前目录）。

## 使用方法

### 1. 单次登录（调试或手动执行）

```bash
chmod +x auto_portal.sh
./auto_portal.sh
```

执行后脚本会依次：
1. 检查默认网关是否匹配校园网。
2. 读取 `en0` 的 IPv4 地址。
3. 使用 `curl` 调 Portal 接口并写入 `cookies.txt`。
4. 多次 `ping` 指定主机确认联网，否则把失败信息追加到 `LOG_FILE`。

### 2. 守护模式自动重连

```bash
chmod +x portal_deamon.sh
./portal_deamon.sh
```

守护脚本逻辑：
1. 循环 `ping` `PING_HOST`，联网时每 `CHECK_INTERVAL_NETWORK` 秒检查一次。
2. 掉线后切换为 `CHECK_INTERVAL_NO_NETWORK` 间隔低频检测，直到网络恢复。
3. 网络恢复后等待 `RETRY_AFTER_ONLINE_SECONDS` 秒确认稳定，再判断是否处于校园网。
4. 若网关匹配，调用 `auto_portal.sh` 完成登录；否则跳过。

若需要后台运行，可自行配合 `launchd`、`nohup` 或第三方守护工具。

## 日志与排查

- `auto_portal.sh` 会在登录失败时把时间戳写入 `LOG_FILE`（默认 `~/portal_error.log`）。
- `portal_deamon.sh` 会在终端输出运行状态，便于实时观察。
- `cookies.txt` 会保存 Portal 交互产生的 Cookie，已在 `.gitignore` 中忽略，避免泄露到 Git。

## 注意事项

- 账号、密码、Portal 参数均属于敏感信息，务必限制脚本文件权限。
- `PING_HOST` 应选择稳定、延迟低的网站以减少误判。
- 若学校 Portal 参数变更，需要同步更新脚本中的相关字段。


