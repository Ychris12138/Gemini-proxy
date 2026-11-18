#!/bin/zsh -f
set -euo pipefail

fail() {
  print -ru2 -- "$1"
  exit 1
}

valid_port() {
  [[ "$1" =~ '^[0-9]{1,5}$' ]] && (( 10#$1 >= 1 && 10#$1 <= 65535 ))
}

check_oauth_route() {
  /usr/bin/curl -q -sS --connect-timeout 3 --max-time 8 \
    --proxy "$http_proxy_url" --noproxy '' -o /dev/null \
    'https://oauth2.googleapis.com/token' ||
    fail "无法通过 $http_proxy_url 连接 Google 登录服务，请检查本地 HTTP 代理。"
}

launcher_name="${0:t}"
case "$launcher_name" in
  agy-proxy|antigravity-proxy) ;;
  *) fail '请先运行 install.sh 安装启动命令。' ;;
esac

http_port="${AG_PROXY_HTTP_PORT:-10808}"
socks_port="${AG_PROXY_SOCKS_PORT:-}"
valid_port "$http_port" || fail 'AG_PROXY_HTTP_PORT 须为 1–65535 的端口号。'
http_proxy_url="http://127.0.0.1:$((10#$http_port))"
socks_proxy_url=''
if [[ -n "$socks_port" ]]; then
  valid_port "$socks_port" || fail 'AG_PROXY_SOCKS_PORT 须为 1–65535 的端口号。'
  socks_proxy_url="socks5://127.0.0.1:$((10#$socks_port))"
fi
local_bypass='localhost,127.0.0.1,::1'

if [[ "${1:-}" == '--proxy-check' ]]; then
  (( $# == 1 )) || fail '--proxy-check 请单独使用。'
  check_oauth_route
  print -r -- "已通过 $http_proxy_url 收到 Google OAuth 服务的 HTTPS 响应。"
  exit 0
fi

if [[ "$launcher_name" == 'agy-proxy' ]]; then
  agy_bin="${AGY_BIN:-${commands[agy]:-$HOME/.local/bin/agy}}"
  [[ -f "$agy_bin" && -x "$agy_bin" ]] ||
    fail '找不到 agy。请先安装官方 Antigravity CLI，或用 AGY_BIN 指定其路径。'
  export HTTP_PROXY="$http_proxy_url" HTTPS_PROXY="$http_proxy_url"
  export http_proxy="$http_proxy_url" https_proxy="$http_proxy_url"
  export ALL_PROXY="$socks_proxy_url" all_proxy="$socks_proxy_url"
  export NO_PROXY="$local_bypass" no_proxy="$local_bypass"
  exec "$agy_bin" "$@"
fi

if [[ "${1:-}" == '--help' && $# == 1 ]]; then
  print -r -- '用法：antigravity-proxy [--proxy-check]'
  print -r -- '环境变量：ANTIGRAVITY_APP、AG_PROXY_HTTP_PORT、AG_PROXY_SOCKS_PORT'
  exit 0
fi
(( $# == 0 )) || fail '用法：antigravity-proxy [--proxy-check]'
app_path="${ANTIGRAVITY_APP:-/Applications/Antigravity.app}"
[[ -d "$app_path" ]] || fail "找不到 Antigravity 应用：$app_path"
app_path="${app_path:A}"
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist" 2>/dev/null) ||
  fail "无法读取应用标识：$app_path"
[[ "$bundle_id" == 'com.google.antigravity' ]] || fail "请指定独立 Antigravity App：$app_path"

if /usr/bin/pgrep -u "$EUID" -x Antigravity >/dev/null; then
  fail 'Antigravity 仍在运行。请在应用内按 ⌘Q 退出，再运行此命令。'
else
  (( $? == 1 )) || fail '无法检查 Antigravity 进程，请在自己的 macOS 终端中运行此命令。'
fi

open_help=$(/usr/bin/open -h 2>&1 || true)
[[ "$open_help" == *--env* ]] || fail '当前 macOS 的 open 命令没有 --env 参数，无法使用此桌面启动方案。'
check_oauth_route

/usr/bin/open -a "$app_path" \
  --env "HTTP_PROXY=$http_proxy_url" \
  --env "HTTPS_PROXY=$http_proxy_url" \
  --env "http_proxy=$http_proxy_url" \
  --env "https_proxy=$http_proxy_url" \
  --env "ALL_PROXY=$socks_proxy_url" \
  --env "all_proxy=$socks_proxy_url" \
  --env "NO_PROXY=$local_bypass" \
  --env "no_proxy=$local_bypass"
