#!/bin/sh
# build.sh - DMVCMD mit NASM (nur 8086) uebersetzen und zusammen mit DC.BAT
# in ein 360-KB-DMV-Sektorabbild schreiben.
#
#   sh build.sh [BASIS.IMG] [AUSGABE.IMG]
#
# Der 8086-Riegel ist Pflicht: ohne "-p cpu8086.inc" nimmt NASM stillschweigend
# 386-Befehle an (mov eax,..; push imm16; shl ax,imm), die der 8088 der DMV
# nicht kennt. Der Pre-Include laesst NASM alles oberhalb des 8086 schon beim
# Uebersetzen ablehnen.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
BASE="${1:-$HERE/base360.img}"
OUT="${2:-$HERE/../images/dmvcmd.img}"

echo "== NASM uebersetzen (nur 8086) =="
nasm -f bin -p "$HERE/cpu8086.inc" -w+all -o "$HERE/dmvcmd.com" "$HERE/dmvcmd.asm"
echo "   -> dmvcmd.com $(wc -c < "$HERE/dmvcmd.com") Bytes"

echo "== ins Abbild schreiben (DMVCMD.COM + DC.BAT) =="
mkdir -p "$(dirname "$OUT")"
python3 "$HERE/mkimage.py" "$BASE" "$OUT" "$HERE/dmvcmd.com" "$HERE/DC.BAT"
