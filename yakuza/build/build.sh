#!/bin/bash
# Yakuza Keybinder - EXE unter Linux bauen (Wine + AutoHotkey 1.1.37)
#   AHK_DIR = entpacktes AutoHotkey_1.1.37.02.zip (mit Compiler/)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../src"
VER="$(grep -m1 'Ahk2Exe-SetVersion' "$SRC/YakuzaKeybinder.ahk" | awk '{print $2}' | tr -d '\r')"
AHK_DIR="${AHK_DIR:?AHK_DIR setzen}"
w() { winepath -w "$1"; }
rm -f "$HERE/YakuzaKeybinder.exe"
wine "$AHK_DIR/Compiler/Ahk2Exe.exe" /in "$(w "$SRC/YakuzaKeybinder.ahk")" /out "$(w "$HERE/YakuzaKeybinder.exe")" \
     /icon "$(w "$SRC/yakuza.ico")" /bin "$(w "$AHK_DIR/Compiler/Unicode 32-bit.bin")"
test -f "$HERE/YakuzaKeybinder.exe"
# Paket fuers Repo - Aufbau wie bisher: YakuzaKeybinder.exe + ANLEITUNG.txt
# ganz oben in der ZIP (das erwartet das automatische Update ab v2.0.0)
cd "$HERE"
rm -rf pkg && mkdir pkg
cp YakuzaKeybinder.exe pkg/
cp ../ANLEITUNG.txt pkg/
rm -f "../../Yakuza_Keybinder_v$VER.zip"
(cd pkg && zip -q -9 "../../../Yakuza_Keybinder_v$VER.zip" YakuzaKeybinder.exe ANLEITUNG.txt)
rm -rf pkg
echo "Fertig: Yakuza_Keybinder_v$VER.zip"
