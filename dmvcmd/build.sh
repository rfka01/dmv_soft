#!/bin/sh
# build.sh - DMVCMD mit NASM (nur 8086) uebersetzen und zusammen mit DC.BAT
# auf eine frische, DOS-freie 360-KB-Datendiskette schreiben.
#
#   sh build.sh [AUSGABE.IMG]
#
# Der 8086-Riegel ist Pflicht: ohne "-p cpu8086.inc" nimmt NASM stillschweigend
# 386-Befehle an (mov eax,..; push imm16; shl ax,imm), die der 8088 der DMV
# nicht kennt. Der Pre-Include laesst NASM alles oberhalb des 8086 schon beim
# Uebersetzen ablehnen.
#
# Das Abbild ist eine REINE DATENDISKETTE ohne DOS. Datensatzkennung 0xFD,
# BPB nach dem DOS-3.3-Port (dmv_os, build_img.py). Zum Benutzen von einer
# DOS-Startdiskette booten und das Abbild als Datendiskette einlegen.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="${1:-$HERE/../images/dmvcmd.img}"

echo "== NASM uebersetzen (nur 8086) =="
nasm -f bin -p "$HERE/cpu8086.inc" -w+all -o "$HERE/dmvcmd.com" "$HERE/dmvcmd.asm"
echo "   -> dmvcmd.com $(wc -c < "$HERE/dmvcmd.com") Bytes"

echo "== leere 360-KB-Datendiskette (ohne DOS) =="
mkdir -p "$(dirname "$OUT")"
python3 "$HERE/mkdata360.py" "$OUT" DMVCMD

echo "== DMVCMD.COM + DC.BAT aufspielen =="
python3 "$HERE/mkimage.py" "$OUT" "$OUT" "$HERE/dmvcmd.com" "$HERE/DC.BAT"
