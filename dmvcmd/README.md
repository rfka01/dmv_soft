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
- `build.sh` – NASM-Build (8086) + Abbild schreiben
- `mkimage.py` – Dateien in ein 360-KB-FAT12-Abbild einfügen/ersetzen
- `fat12.py` / `fat12write.py` – FAT12 lesen / eine Datei ersetzen
- `DC.BAT` – ruft auf dem Abbild `DMVCMD` auf
- `base360.img` – leeres DOS-2.11-Startabbild als Basis

## Bedienung (auf der DMV)

`DC` oder `DMVCMD` starten. Tasten: Pfeile bzw. `j`/`k` bewegen, `TAB`
wechselt die Spalte, `ENTER` öffnet ein Verzeichnis, `c` kopiert, `d` wählt
das Laufwerk, `m` schaltet Farbe/Mono, `t` springt nach oben, `q` beendet.
