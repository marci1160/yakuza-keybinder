#!/bin/bash
# Brooklyn Keybinder - EXE unter Linux bauen (Wine + AutoHotkey 1.1.37)
#   AHK_DIR = entpacktes AutoHotkey_1.1.37.02.zip (mit Compiler/)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../src"
AHK_DIR="${AHK_DIR:?AHK_DIR setzen}"
w() { winepath -w "$1"; }
wine "$AHK_DIR/Compiler/Ahk2Exe.exe" /in "$(w "$SRC/Brooklyn.ahk")" /out "$(w "$HERE/BrooklynKeybinder.exe")" \
     /icon "$(w "$SRC/brooklyn.ico")" /bin "$(w "$AHK_DIR/Compiler/Unicode 32-bit.bin")"
# Paket fuers Repo
cd "$HERE"
rm -rf pkg && mkdir pkg
cp BrooklynKeybinder.exe pkg/
cp ../ANLEITUNG.txt pkg/
(cd pkg && zip -q -9 "../../../Brooklyn_Keybinder_v5.0.0.zip" BrooklynKeybinder.exe ANLEITUNG.txt)
rm -rf pkg
echo "Fertig: Brooklyn_Keybinder_v5.0.0.zip"
