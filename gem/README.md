# GEM für die NCR DMV

Deutsches GEM (FreeGEM 3: AES 3.0, Desktop 3.2.3, GEMVDI) mit eigenem
Bildschirmtreiber für die NCR Decision Mate V unter MS-DOS 3.3 – 640 × 400,
einfarbig oder mit acht Farben, Maus K806 oder seriell an der K801.
In MAME getestet.

| Teil | Verzeichnis | Lizenz |
|---|---|---|
| GEM an sich – AES, Desktop, VDI, Bildschirmtreiber, Installation | `system/` | GPL v2 (folgt) |
| GEM-Anwendungen und Zubehör | `anwendungen/` | MIT |
| Bildschirmschriften und Schriftwerkzeug | `schriften/` | Werkzeug MIT, Schriften OFL bzw. GUST |

`system/` kommt in einem eigenen Schritt: AES, Desktop und der Rahmen des
Bildschirmtreibers stammen von Digital Research und sind von Caldera 1999
unter der GPL freigegeben (OpenGEM-SDK, FreeGEM). Sie sind damit die
Ausnahme von der Regel „kein fremder Code“ in diesem Repo und stehen dort
vollständig mit eigener GPL-LICENSE. Original-Dateien von DR GEM 1.x–3.x,
DR-Schriften und die Programmpakete von DR (Paint usw.) kommen nicht ins Repo.

## Disketten

Der Satz heißt „DMV OpenGEM v<Stufe> <Inhalt>“, als Datei
`DMV-OpenGEM-v<Stufe>-<Inhalt>.IMG`, Volumename `OPENGEM<STUFE>-<n>`
(z. B. `DMV-OpenGEM-v3x-System.IMG`, `OPENGEM3X-1`):

| Nr. | Inhalt |
|---|---|
| 1 System | GEMKOPIE, AES, Desktop, GEMVDI, Ressourcen, Batchdateien, LIESMICH |
| 2 Treiber | Bildschirmtreiber, Zubehör, SCHRIFT.APP, Bildschirmschriften |
| 3 Ausgabe | GEM Output, Druckertreiber, Druckerschriften (in Arbeit) |

Installation: Diskette 1 in A:, `A:GEMKOPIE`, die Batchdatei fragt nach den
weiteren Disketten.

Code von Claude (Anthropic), Idee, Tests und Prompts von rfka01. GEM:
Digital Research, Caldera-Freigabe 1999; FreeGEM: John Elliott u. a.
