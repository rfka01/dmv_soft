# GEM-Anwendungen für die DMV

Eigene Programme für unser GEM, NASM, ein Segment, nur 8086-Befehle.
Bauen: `sh build.sh` (NASM nötig), Ergebnis in `aus/`.

| Datei | Quelle | Was |
|---|---|---|
| UHR.ACC | `uhr.asm` | Uhr und Monatskalender: Wochentag, TT.MM.JJJJ, 24 h, `<`/`>` blättern |
| RECHNER.ACC | `rechner.asm` | Rechner `+ - * /`, 4 Nachkommastellen (64-Bit-Festkomma), Maus und Tastatur |
| NOTIZ.ACC | `notiz.asm` | Notizblock 12 × 40 Zeichen, gespeichert als `NOTIZ.TXT` im GEM-Verzeichnis |
| FREIMEM.ACC | `freimem.asm` | Freier Speicher (größter Block, Summe) – im Diskettensatz ab Stufe 3x ersetzt durch die Anzeige unter „Desktop-Info“ |
| SCHRIFT.APP | `schrift.asm` | zeigt alle nachladbaren Bildschirmschriften in allen Größen und was sie an Speicher kosten |

`gemacc.inc` ist der gemeinsame Rahmen der Zubehöre: MZ-Kopf, AES-Aufruf
(INT EFh, CX = 200), Objektbäume mit Segment-Nachtrag zur Laufzeit,
`rsrc_obfix`, eigene `evnt_multi`-Schleife, `menu_register`.

Zum Zubehör: GEM lädt **höchstens drei** Zubehöre (`NUM_ACCS 3` im AES)
und nur, solange einem Programm 206 KB bleiben.

In MAME getestet. Lizenz MIT (siehe `LICENSE` im Wurzelverzeichnis).
