#!/bin/sh
# test.sh - DMVCMD-Datendiskette im DMV-MAME (kopflos) pruefen.
#
#   sh test.sh [DMVCMD.IMG] [SEKUNDEN] [SNAPVERZ]
#
# Ablauf: Eine DOS-2.11-Startdiskette kommt in Laufwerk A: (flop1), die
# DMVCMD-Datendiskette in B: (flop2). Nach dem Hochfahren wird automatisch
# "B:" + "DC" getippt, dann ein Bildschirmfoto gezogen.
#
# Die Startdiskette ist NICHT Teil dieses Repos (sie enthaelt DOS, also
# fremden Code - siehe CLAUDE.md, Regel 2). Pfad ueber $BOOT_IMG angeben:
#
#   BOOT_IMG=/pfad/zur/dos211.img sh test.sh
#
# Voraussetzungen im $MAME_DIR (Vorgabe ../mame, relativ zu diesem Skript):
#   dmv-mame   - der DMV-only-MAME-Build (Treiber "dmv", 0.289)
#   roms/      - mit dmv.zip
# Die DMV wird mit K208 (448K RAM) in Steckplatz 1 bestueckt.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)

IMG="${1:-$HERE/../images/dmvcmd_v10.img}"
SECS="${2:-45}"
SNAP="${3:-snap}"
MAME_DIR="${MAME_DIR:-$HERE/../../work/mame}"
BOOT_IMG="${BOOT_IMG:-$MAME_DIR/dmvtest.img}"

[ -f "$IMG" ]      || { echo "Datendiskette fehlt: $IMG" >&2; exit 1; }
[ -f "$BOOT_IMG" ] || { echo "DOS-Startdiskette fehlt: $BOOT_IMG (per BOOT_IMG= setzen)" >&2; exit 1; }
[ -x "$MAME_DIR/dmv-mame" ] || { echo "dmv-mame fehlt in $MAME_DIR" >&2; exit 1; }

# Autokommando: nach den DOS-Datum/Zeit-Abfragen zweimal Enter, dann auf die
# Datendiskette wechseln und DC.BAT starten.
CMD="${CMD:-\\n\\nB:\\nDC\\n}"

echo "Boot : $BOOT_IMG (A:)"
echo "Daten: $IMG (B:)"
rm -f "$MAME_DIR/$SNAP"/dmv/*.png 2>/dev/null || true
cd "$MAME_DIR"
SDL_VIDEODRIVER=offscreen ./dmv-mame dmv \
  -rompath roms \
  -slot1 k208 \
  -flop1 "$BOOT_IMG" \
  -flop2 "$IMG" \
  -video none -sound none -window -nothrottle \
  -autoboot_delay 28 -autoboot_command "$CMD" \
  -seconds_to_run "$SECS" \
  -snapshot_directory "$SNAP" -skip_gameinfo 2>&1 | grep -iE "speed|error" || true
echo "Bildschirmfoto: $MAME_DIR/$SNAP/dmv/0000.png"
