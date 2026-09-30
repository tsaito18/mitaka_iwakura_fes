#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/wineprefixes/mitaka}"
export WINEDEBUG=-all
export LANG=ja_JP.UTF-8
# Mitaka は1文字キー操作が主体で、IME (fcitx5/Mozc) がオンだとキーを横取りされるため XIM を使わない
export XMODIFIERS=@im=none

if [[ ! -d "$WINEPREFIX" ]]; then
  WINEARCH=win64 wineboot -i
  # GNOME の xwayland-native-scaling 環境では DPI 非対応アプリが実ピクセルで小さく描かれるため、
  # Wine 側で 200% (192 DPI) を宣言してスケーリングさせる
  wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d 192 /f >/dev/null
  wine reg add 'HKLM\System\CurrentControlSet\Hardware Profiles\Current\Software\Fonts' /v LogPixels /t REG_DWORD /d 192 /f >/dev/null
  # Wine には MS UI Gothic が無く、日本語 UI が豆腐になるため
  wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes' /v 'MS UI Gothic' /t REG_SZ /d 'Noto Sans CJK JP' /f >/dev/null
fi

# OpenGL 描画の文字は内蔵 FreeType が Japanese.lng の FONT 指定ファイルを直接読むため、JP が face 0 の Noto CJK TTC で代替する
noto_cjk=/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc
if [[ ! -f "$noto_cjk" ]]; then
  noto_cjk="$(fc-match -f '%{index} %{file}\n' 'Noto Sans CJK JP:style=Regular' | awk '$1 == 0 && /NotoSansCJK.*\.ttc$/ { print $2 }' || true)"
fi
if [[ -n "$noto_cjk" ]]; then
  fonts_dir="$WINEPREFIX/drive_c/windows/Fonts"
  mkdir -p "$fonts_dir"
  for name in meiryo.ttc MSGothic.ttc; do
    if [[ ! -f "$fonts_dir/$name" || -L "$fonts_dir/$name" ]]; then
      ln -sfn "$noto_cjk" "$fonts_dir/$name"
    fi
  done
else
  echo "mitaka.sh: Noto Sans CJK JP の TTC が見つからないため、OpenGL 描画の文字が表示されない可能性があります" >&2
fi

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/mitaka"
mkdir -p "$log_dir"

# Mitaka はデータファイルをカレントディレクトリ基準で読み込む
cd "$script_dir"
exec wine mitaka.exe "$@" 2>"$log_dir/wine.log"
