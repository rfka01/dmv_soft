#!/bin/sh
# build.sh - baut die GEM-Anwendungen fuer die DMV mit NASM nach ./aus
# (UHR.ACC, RECHNER.ACC, NOTIZ.ACC, FREIMEM.ACC, SCHRIFT.APP)
set -e
cd "$(dirname "$0")"
mkdir -p aus
for x in uhr:UHR.ACC rechner:RECHNER.ACC notiz:NOTIZ.ACC freimem:FREIMEM.ACC schrift:SCHRIFT.APP; do
  nasm -f bin "${x%%:*}.asm" -o "aus/${x##*:}"
  echo "aus/${x##*:}  $(wc -c < "aus/${x##*:}") Byte"
done
