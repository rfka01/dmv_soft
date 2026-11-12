#!/bin/sh
# build.sh - DMVCMD mit NASM (nur 8086) uebersetzen und zusammen mit DC.BAT
# auf eine frische, DOS-freie 360-KB-Datendiskette schreiben.
#
#   sh build.sh [AUSGABE.IMG]
#
# Ohne Argument entsteht ../images/dmvcmd_v<VER>.img.
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

# --- Version zentral. Muss zum Titel in dmvcmd.asm passen (DMVCMD vX.Y). ---
VER=1.0
VTAG=$(echo "$VER" | tr -d '.')              # "1.0" -> "10" (fuer 8.3-Namen)
VFILE="DMVCMD.V$VTAG"                          # Versions-Textdatei, z.B. DMVCMD.V10
OUT="${1:-$HERE/../images/dmvcmd_v$VTAG.img}"

echo "== Version $VER =="

echo "== NASM uebersetzen (nur 8086) =="
nasm -f bin -p "$HERE/cpu8086.inc" -w+all -o "$HERE/dmvcmd.com" "$HERE/dmvcmd.asm"
echo "   -> dmvcmd.com $(wc -c < "$HERE/dmvcmd.com") Bytes"

echo "== Versions-Textdatei $VFILE =="
# Inhalt mit DOS-Zeilenenden (CRLF). Traegt die Versionsnummer auf dem Image.
printf 'DMVCMD Version %s\r\nANSI-Dualpanel-Dateimanager fuer die NCR Decision Mate V\r\nGebaut: %s\r\n' \
  "$VER" "$(date -u '+%Y-%m-%d %H:%M UTC')" > "$HERE/$VFILE"

echo "== leere 360-KB-Datendiskette (ohne DOS) =="
mkdir -p "$(dirname "$OUT")"
python3 "$HERE/mkdata360.py" "$OUT" "DMVCMD V$VTAG"

echo "== DMVCMD.COM + DC.BAT + $VFILE aufspielen =="
python3 "$HERE/mkimage.py" "$OUT" "$OUT" "$HERE/dmvcmd.com" "$HERE/DC.BAT" "$HERE/$VFILE"

echo "== fertig: $OUT =="
