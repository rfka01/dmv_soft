# Bildschirmschriften für GEM auf der DMV

Ersatz für die DR-Schriften aus freien Vorlagen, im GEM-Format (VGA-Satz,
quadratische Punkte, gepackt wie bei GEM: Flag 20h, XOR-Zeilen, Lauflängen).

| Dateien | Schrift | Id | Größen | Vorlage | Lizenz |
|---|---|---|---|---|---|
| `vga/AA*.VGA` | Swiss | 2 | 7–48 pt | TeX Gyre Heros | GUST Font License (LPPL 1.3c) |
| `vga/AI*.VGA` | Dutch | 14 | 7–48 pt | TeX Gyre Termes | GUST Font License (LPPL 1.3c) |
| `vga/FH*.VGA` | Falsifikata halbfett condensed | 62 | 10–36 pt | Federo (Cyreal) | SIL OFL 1.1 |
| `ttf/FalsifikataHalbfettCondensed.ttf` | dieselbe als Umrissschrift | – | – | Federo | SIL OFL 1.1 |
| (nur lokal) `DL*.VGA` | Decision Line | 60 | 10–36 pt | Zeichengenerator der DMV | – |

Swiss und Dutch haben dieselben Ids, Dateinamen und Maße (Versal- und
x-Höhe, Zeilenhöhe) wie die GEM-Schriften und ersetzen sie ohne Änderung
in den Programmen. Gegenüber den Vorlagen sind sie nur gerastert; Name und
Dateinamen sind andere, wie es die GUST-Lizenz erbittet.

**Falsifikata halbfett condensed** ist eine Art-déco-Groteske im Stil der
Peignot, abgewandelt aus Federo: 80 % breit, Senkrechte kräftig und
Waagerechte fein wie mit der Breitfeder, Unicase (Kleinbuchstaben als
kleine Versalien, gemein nur b d f h k l p y ß), i und j mit Versal-Stamm
und abgesetztem Punkt, g als kleines C mit Stamm ab halber Höhe.
Eigentlich sollte sie *Plagiata* heißen – der Name war leider schon
vergeben. „Federo“ ist ein Reserved Font Name der Vorlage und wird nicht
verwendet.

**Decision Line** entsteht aus dem Hauptplatinen-ROM der DMV
(`--rom dmv_norm.bin`); die Schrift selbst liegt nicht im Repo, nur das
Werkzeug.

## Bauen

```
cd werkzeug
python3 bau_schriften.py [--rom dmv_norm.bin]   # -> ../vga (DL*.VGA nur mit ROM)
python3 falsifikata_ttf.py                      # -> ../ttf
python3 muster.py BILD.png ../vga/FH0360GV.VGA "Titel"   # Schriftmuster
```

Gebraucht werden Python 3 mit `freetype-py`, `numpy`, `scipy`,
`scikit-image`, `Pillow`, für die TTF `fontTools` und `skia-pathops`.
Die Vorlagen liegen in `quellen/` mit ihren Lizenzen.

| Werkzeug | Aufgabe |
|---|---|
| `bau_schriften.py` | rastert die Vorlagen (FreeType), Maße wie der GEM-Satz, Kontrast, Unicase, Noppen und Haarlinien |
| `gemfnt.py`, `gempack.py` | GEM-Schriftdatei schreiben/lesen, Packen nach DR-Verfahren (bytegleich geprüft) |
| `zeichensatz.py` | GEM-Zeichensatz (Codes 32–255) |
| `decision.py` | Decision Line aus dem ROM |
| `falsifikata_ttf.py` | Falsifikata als TrueType (Umrisse mit skia-pathops) |
| `muster.py`, `zeige.py` | Alphabet- und Textmuster als PNG |

Lizenzen: Werkzeug MIT (Wurzel-`LICENSE`); `vga/` und `ttf/` mit
`OFL.txt` bzw. `GUST-FONT-LICENSE.txt`.
