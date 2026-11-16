# DMVTRAK – MOD-Player und Tracker

*English below.*

## Deutsch

DMVTRAK spielt Amiga-MODs auf der NCR Decision Mate V und ist zugleich ein kleiner Tracker zum Bearbeiten und Schreiben eigener Stücke. Geschrieben in Turbo Pascal 3.01A für MS-DOS, Version 0.6.

Drei Wege zum Klang:

- **Mit der Firmware [EXTKB](https://github.com/rfka01/dmv_hardware/tree/main/EXTKB)** erzeugt der Tastaturcontroller 8741 drei Rechteckstimmen und Rauschen. DMVTRAK verteilt die drei wichtigsten Kanäle auf die Stimmen, stellt die Tonhöhe exakt aus der MOD-Periode (Slides und Arpeggio stufenlos) und nimmt das Rauschen für Schlagzeug. Den Takt liefert der Timer des 8741.
- **Mit der Originalfirmware** klingt eine Stimme in Halbtönen; DMVTRAK spielt dann die führende Stimme oder wechselt die Kanäle im Arpeggio.
- **Mit einem Covox Speech Thing** an der Centronics-Karte K210 (`/C`) spielt DMVTRAK die echten Samples des MODs: alle Kanäle mit Lautstärke gemischt, 2000–6400 Hz (Vorgabe 5000 Hz). Der 8253 gibt dafür den Takt per Interrupt vor; das braucht die K235. DTK-Dateien haben keine Samples und gehen mit `/C` nicht.

Ohne `/C` werden MODs ohne Samples geladen (15 oder 31 Instrumente, 4/6/8 Kanäle). Gespeichert wird im eigenen, kleinen Format DTK, das Prioritäten und Rauschen der Instrumente mitführt. Das Format erkennt DMVTRAK am Inhalt, nicht an der Endung.

### Dateien

| | |
|---|---|
| `Images/DMVSOUND.IMG` | 360-KB-DOS-Diskette: `DMVTRAK.COM`, `DMVTRAK.TXT`, `SYNDEMO.COM`, `SYNTH.TXT`, Musik `AXELF.DTK`, `JARRE.DTK`, `POPCORN.MOD`, `OXYGENE2.MOD` |
| `Sourcen/` | `DMVTRAK.PAS` (Hauptdatei), `DTK*.INC`, `COVBIN.INC`; `COVMIX.ASM` (Covox-Ausgabe und Mischer, nasm); `DMVTRAK.TXT` Beschreibung mit allen Tasten |

Die Firmware liegt in [EXTKB](https://github.com/rfka01/dmv_hardware/tree/main/EXTKB).

### Aufruf

```
DMVTRAK                 Editor mit leerem Lied
DMVTRAK datei           Editor mit MOD oder DTK
DMVTRAK datei /P        nur abspielen über den 8741
DMVTRAK datei /C        nur abspielen über das Covox (MOD mit Samples)
DMVTRAK datei /C:4000   ... mit 4000 Hz
DMVTRAK /?              Hilfeschirm
```

Beim Abspielen: Leertaste Pause/weiter, RETURN von vorn, S Stopp, Pfeil links/rechts 10 s zurück/vor, ESC Ende; bei `/C` ändern `+` und `−` die Abtastrate in Schritten von 500 Hz, die Anzeige zählt Aussetzer. Im Editor öffnet ESC das Menü (Laden, Speichern, Instrumente, Reihenfolge, Klang, Tempo, E Ende); die Leertaste spielt ab Cursor, RETURN von vorn. Alle Tasten stehen in `DMVTRAK.TXT`.

### Neu bauen

Turbo Pascal 3.01A, `DMVTRAK.PAS` als Hauptdatei, Compiler-Option C (Com-file), die Dateien `DTK*.INC` und `COVBIN.INC` im selben Verzeichnis. `COVBIN.INC` entsteht mit nasm aus `COVMIX.ASM` (Byte-Tabelle des assemblierten Codes). Die Pascal-Quelltexte haben CRLF-Zeilenenden.

### Test

Im Emulator (emu2 mit Modellen des 8741, der K210 mit Covox und des 8253-Interrupts) und mit der zyklengenauen Simulation des 8741 geprüft; von rfka01 in MAME getestet, auch mit Covox. Auf einer echten DMV noch nicht getestet.

### Musik

`AXELF`, `JARRE`, `POPCORN` und `OXYGENE2` sind MODs anderer Autoren und fallen nicht unter die MIT-Lizenz.

## English

DMVTRAK plays Amiga MODs on the NCR Decision Mate V and is also a small tracker for editing and writing your own pieces. Written in Turbo Pascal 3.01A for MS-DOS, version 0.6.

Three ways to sound:

- **With the firmware [EXTKB](https://github.com/rfka01/dmv_hardware/tree/main/EXTKB)** the 8741 keyboard controller generates three square-wave voices and noise. DMVTRAK assigns the three most important channels to the voices, sets the pitch exactly from the MOD period (smooth slides and arpeggio) and uses the noise for drums. The 8741 timer provides the tempo.
- **With the original firmware** a single voice plays in semitones; DMVTRAK then plays the leading voice or alternates the channels as an arpeggio.
- **With a Covox Speech Thing** on the K210 Centronics card (`/C`) DMVTRAK plays the real samples of the MOD: all channels mixed with volume, 2000–6400 Hz (default 5000 Hz). The 8253 sets the pace by interrupt, which needs the K235. DTK files have no samples and cannot be played with `/C`.

Without `/C` MODs are loaded without samples (15 or 31 instruments, 4/6/8 channels). Songs are saved in a small format of its own, DTK, which keeps the priorities and noise settings of the instruments. DMVTRAK recognises the format by content, not by the file extension.

### Files

| | |
|---|---|
| `Images/DMVSOUND.IMG` | 360 KB DOS disk: `DMVTRAK.COM`, `DMVTRAK.TXT` (German), `SYNDEMO.COM`, `SYNTH.TXT`, music `AXELF.DTK`, `JARRE.DTK`, `POPCORN.MOD`, `OXYGENE2.MOD` |
| `Sourcen/` | `DMVTRAK.PAS` (main file), `DTK*.INC`, `COVBIN.INC`; `COVMIX.ASM` (Covox output and mixer, nasm); `DMVTRAK.TXT` description with all keys (German) |

The firmware is in [EXTKB](https://github.com/rfka01/dmv_hardware/tree/main/EXTKB).

### Usage

```
DMVTRAK                 editor with an empty song
DMVTRAK file            editor with a MOD or DTK
DMVTRAK file /P         play only, through the 8741
DMVTRAK file /C         play only, through the Covox (MOD with samples)
DMVTRAK file /C:4000    ... at 4000 Hz
DMVTRAK /?              help screen
```

While playing: space pause/resume, RETURN from the start, S stop, arrow left/right 10 s back/forward, ESC end; with `/C`, `+` and `−` change the sample rate in steps of 500 Hz and the display counts dropouts. In the editor ESC opens the menu (load, save, instruments, order, sound, tempo, E end); space plays from the cursor, RETURN from the start. All keys are listed in `DMVTRAK.TXT`.

### Building

Turbo Pascal 3.01A, `DMVTRAK.PAS` as main file, compiler option C (com file), the `DTK*.INC` files and `COVBIN.INC` in the same directory. `COVBIN.INC` is made with nasm from `COVMIX.ASM` (byte table of the assembled code). The Pascal sources have CRLF line endings.

### Tests

Checked in an emulator (emu2 with models of the 8741, the K210 with Covox and the 8253 interrupt) and with the cycle-accurate 8741 simulation; tested by rfka01 in MAME, including Covox. Not yet tested on a real DMV.

### Music

`AXELF`, `JARRE`, `POPCORN` and `OXYGENE2` are MODs by other authors and are not covered by the MIT license.

---

MIT License, see [LICENSE](../LICENSE). Code: Claude (Anthropic) · Prompts: rfka01
