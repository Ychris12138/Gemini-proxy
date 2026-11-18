#!/bin/zsh -f
set -euo pipefail

source_file="${0:A:h}/launcher.zsh"
bin_dir="$HOME/.local/bin"
case "$#" in
  0) ;;
  2)
    if [[ "$1" != '--bin-dir' || -z "$2" ]]; then
      print -u2 '用法：./install.sh [--bin-dir 目录]'
      exit 2
    fi
    bin_dir="$2"
    ;;
  *) print -u2 '用法：./install.sh [--bin-dir 目录]'; exit 2 ;;
esac
bin_dir="${bin_dir:a}"
launchers=(agy-proxy antigravity-proxy)

for name in "${launchers[@]}"; do
  target="$bin_dir/$name"
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -L "$target" || ! -f "$target" || ! -x "$target" ]] ||
        ! /usr/bin/cmp -s "$source_file" "$target"; then
      print -ru2 -- "已存在 $target。请先备份旧文件，或为本包指定其他安装目录。"
      exit 1
    fi
  fi
done

/bin/mkdir -p "$bin_dir"
stage_file=$(/usr/bin/mktemp "$bin_dir/.antigravity-proxy.XXXXXXXX")
trap '/bin/rm -f "$stage_file"' EXIT
/usr/bin/install -m 755 "$source_file" "$stage_file"

for name in "${launchers[@]}"; do
  target="$bin_dir/$name"
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    /bin/cp -p -n "$stage_file" "$target"
  fi
  [[ ! -L "$target" && -f "$target" && -x "$target" ]] &&
    /usr/bin/cmp -s "$source_file" "$target" ||
    { print -ru2 -- "无法验证安装结果：$target"; exit 1; }
  print -r -- "已安装 $target"
done
