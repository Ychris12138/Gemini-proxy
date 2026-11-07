#!/bin/bash
# Create a separately signed local copy. Never patch the original Gemini app.
set -euo pipefail

kit_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
source_app='/Applications/Gemini.app'
output_app="$HOME/Applications/Gemini no-TUN.app"
socks_port=10808
http_port=10808
skip_network_check=0
confirmed=0

usage() {
  cat <<'USAGE'
Usage: ./create-proxy-copy.sh [options]
  --source PATH       Original, Google-signed Gemini.app
  --output PATH       New app bundle; must not already exist
  --socks-port PORT   Local unauthenticated SOCKS5 port (default 10808)
  --http-port PORT    Local unauthenticated HTTP CONNECT port (default 10808)
  --skip-network-check  Skip online proxy checks (for offline testing only)
  --yes               Confirm the security notice without an interactive prompt
  --help              Show this help

Run the generated copy from its original output path; do not move it.
USAGE
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source|--output|--socks-port|--http-port)
      [ "$#" -ge 2 ] || fail "Missing value for $1"
      case "$1" in
        --source) source_app=$2 ;;
        --output) output_app=$2 ;;
        --socks-port) socks_port=$2 ;;
        --http-port) http_port=$2 ;;
      esac
      shift 2 ;;
    --skip-network-check) skip_network_check=1; shift ;;
    --yes) confirmed=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

[ "$(uname -s)" = Darwin ] || fail 'This tool only supports macOS.'
for port in "$socks_port" "$http_port"; do
  case "$port" in ''|*[!0-9]*) fail 'Proxy ports must be integers from 1 to 65535.' ;; esac
  [ "${#port}" -le 5 ] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || fail 'Proxy ports must be integers from 1 to 65535.'
done
[ -d "$source_app" ] || fail 'Original Gemini.app was not found.'
[ -f "$source_app/Contents/Info.plist" ] || fail 'The source is not a valid app bundle.'
[ ! -e "$output_app" ] && [ ! -L "$output_app" ] || fail 'The output already exists; choose another path.'
[ -x /usr/bin/python3 ] || fail 'Python 3 is required; install Apple Command Line Tools.'
/usr/bin/xcrun --find clang++ >/dev/null 2>&1 || fail 'Apple Command Line Tools / clang++ are required.'

# Resolve parent components before creating anything, and reject nested copies.
/usr/bin/python3 - "$source_app" "$output_app" <<'PY'
import pathlib, sys
src, dest = (pathlib.Path(x).expanduser().resolve() for x in sys.argv[1:])
if dest.suffix.lower() != '.app' or src == dest or src in dest.parents or dest in src.parents:
    sys.exit('Error: output must be a separate new .app, outside the source app.')
if ':' in str(dest) or '\n' in str(dest):
    sys.exit('Error: the output path cannot contain a colon or newline.')
PY

bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source_app/Contents/Info.plist")
[ "$bundle_id" = 'com.google.GeminiMacOS' ] || fail 'Source bundle identifier is not the expected Gemini app.'
echo 'Checking the original Google signature (this can take a moment)...'
codesign --verify --deep --strict "$source_app" || fail 'Source signature verification failed.'
signature_info=$(codesign -dv --verbose=4 "$source_app" 2>&1) || fail 'Cannot read source signature.'
printf '%s\n' "$signature_info" | /usr/bin/grep -q '^TeamIdentifier=EQHXZ8M8AV$' || fail 'Source is not signed by the expected Google team.'
/usr/sbin/spctl --assess --type execute "$source_app" || fail 'macOS did not accept the source app.'

if [ "$skip_network_check" -eq 0 ]; then
  echo 'Testing the local SOCKS5 and HTTP CONNECT proxy against Google...'
  socks_status=$(/usr/bin/curl -q --noproxy '' --socks5-hostname "127.0.0.1:$socks_port" --silent --output /dev/null --connect-timeout 5 --max-time 15 --write-out '%{http_code}' 'https://www.gstatic.com/generate_204' || true)
  http_status=$(/usr/bin/curl -q --noproxy '' --proxy "http://127.0.0.1:$http_port" --silent --output /dev/null --connect-timeout 5 --max-time 15 --write-out '%{http_code}' 'https://www.gstatic.com/generate_204' || true)
  [ "$socks_status" = 204 ] || fail "SOCKS5 check failed (HTTP status: $socks_status). Check --socks-port."
  [ "$http_status" = 204 ] || fail "HTTP CONNECT check failed (HTTP status: $http_status). Check --http-port."
else
  echo 'Warning: network checks skipped; the proxy ports have not been verified.'
fi

cat <<'NOTICE'

This creates a separate locally signed copy. It permits DYLD injection and
disables library validation for that copy, so the copy loses Google's original
code-signing integrity guarantee. The injected code can access app data.
It may require a separate login and may stop working after updates. It does
not guarantee that every connection uses the proxy. The original is unchanged.
NOTICE
if [ "$confirmed" -ne 1 ]; then
  [ -t 0 ] || fail 'Run interactively to acknowledge the notice, or use --yes after reviewing it.'
  printf 'Type YES to create the copy: '
  IFS= read -r reply
  [ "$reply" = YES ] || fail 'Cancelled; no copy was created.'
fi

build_dir=$(mktemp -d "${TMPDIR:-/tmp}/gemini-no-tun-build.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
echo 'Compiling the local proxy library...'
/usr/bin/xcrun clang++ -std=c++17 -O2 -dynamiclib -I "$kit_dir/include" \
  "$kit_dir/src/main_mac.cpp" "$kit_dir/src/hooks/HooksMac.cpp" \
  -o "$build_dir/libgemini_proxy_lab.dylib"

mkdir -p -- "$(dirname -- "$output_app")"
output_parent=$(CDPATH= cd -- "$(dirname -- "$output_app")" && pwd -P)
output_app="$output_parent/$(basename -- "$output_app")"
# mkdir is an atomic no-overwrite claim. A failed later step leaves this partial
# output for the user to inspect and remove; it never removes an existing app.
mkdir -- "$output_app" || fail 'Cannot reserve output path.'
echo 'Copying the original app into the new bundle...'
/usr/bin/ditto "$source_app" "$output_app"
payload="$output_app/Contents/Resources/GeminiNoTun"
mkdir -p -- "$payload"
cp "$build_dir/libgemini_proxy_lab.dylib" "$payload/libgemini_proxy_lab.dylib"

/usr/bin/python3 - "$output_app" "$socks_port" "$http_port" <<'PY'
import json, pathlib, plistlib, sys
app = pathlib.Path(sys.argv[1])
socks_port, http_port = map(int, sys.argv[2:])
payload = app / 'Contents/Resources/GeminiNoTun'
config = {
    'proxy': {'type': 'socks5', 'host': '127.0.0.1', 'port': socks_port},
    'fake_ip': {'enabled': False},
    'target_processes': ['Gemini'], 'child_injection': False,
    'ui': {'load_notify': 'none'}, 'updates': {'enabled': False},
    'diagnostics': {'agent_ip_probe': False}, 'log_level': 'error',
}
(payload / 'config.json').write_text(json.dumps(config, indent=2) + '\n', encoding='utf-8')
path = app / 'Contents/Info.plist'
with path.open('rb') as stream:
    info = plistlib.load(stream)
info['CFBundleIdentifier'] = 'dev.gemini-notun.local-proxy'
info['CFBundleName'] = 'Gemini no-TUN'
info['CFBundleDisplayName'] = 'Gemini no-TUN'
for key in ('CFBundleURLTypes', 'CFBundleDocumentTypes', 'UTExportedTypeDeclarations'):
    info.pop(key, None)
proxy = 'http://127.0.0.1:' + str(http_port)
info['LSEnvironment'] = {
    'DYLD_INSERT_LIBRARIES': str(payload / 'libgemini_proxy_lab.dylib'),
    'HTTP_PROXY': proxy, 'HTTPS_PROXY': proxy,
    'http_proxy': proxy, 'https_proxy': proxy,
    'NO_PROXY': 'localhost,127.0.0.1,::1',
    'no_proxy': 'localhost,127.0.0.1,::1',
}
with path.open('wb') as stream:
    plistlib.dump(info, stream, sort_keys=False)
PY

echo 'Signing and checking the separate copy...'
codesign --force --timestamp=none --options runtime --entitlements "$kit_dir/entitlements.plist" --sign - "$output_app"
codesign --verify --deep --strict "$output_app" || fail 'Copy signature verification failed; do not run it.'
printf '\nCreated: %s\n' "$output_app"
echo 'Keep the local proxy running, then open this copy from this exact path.'
echo 'If the original app is updated, create and test a fresh copy in a new location.'
