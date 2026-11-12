# DMVCMD – Dateimanager für die NCR DMV

Zweispaltiger Dateimanager im Stil des Norton Commander, aber für die DMV:
Er rendert **ausschließlich über DOS (INT 21h) und ANSI-Escapes**, weil die
DMV keinen CPU-adressierbaren Bildspeicher hat. Klassische NC-Klone (NC 2.01,
Volkov, DOS Navigator, NonameCommander) schreiben direkt in den Bildspeicher
0xB800/0xB000 und laufen darum auf der DMV **nicht**.

(Früherer Name: DMVNC.)

## Dateien

- `dmvcmd.asm` – Quelltext (8086, NASM-Syntax)
- `cpu8086.inc` – erzwingt den 8086-Befehlssatz beim Übersetzen
- `build.sh` – NASM-Build (nur 8086) + Datendiskette schreiben
- `mkdata360.py` – leere 360-KB-Datendiskette (FAT12, ohne DOS) erzeugen
- `mkimage.py` – Dateien in ein FAT12-Abbild einfügen/ersetzen
- `fat12.py` / `fat12write.py` – FAT12 lesen / eine Datei ersetzen
- `DC.BAT` – ruft auf dem Abbild `DMVCMD` auf

## Datenträger

Das gebaute Abbild (`../images/dmvcmd.img`) ist eine **reine Datendiskette
ohne DOS**. Format: 360 KB, FAT12, Datensatzkennung (media descriptor)
**0xFD**, BPB nach dem DOS-3.3-Port (dmv_os, `build_img.py`): bps=512, spc=2,
nroot=112, tot=720, spf=2, spt=9, heads=2, cyls=40. Der Bootsektor ist
IBM-kompatibel (55AA-Signatur, Hinweis „Keine Systemdiskette"), die DMV
selbst bootet jedoch über ihre Firmware.

Zum Benutzen von einer DOS-Startdiskette booten, die Datendiskette als
zweites Laufwerk (B:) einlegen, dann `B:` und `DC` eingeben.

## Bedienung

Tasten: Pfeile bzw. `j`/`k` bewegen, `TAB` wechselt die Spalte, `ENTER`
öffnet ein Verzeichnis, `c` kopiert, `d` wählt das Laufwerk, `m` schaltet
Farbe/Mono, `t` springt nach oben, `q` beendet.
