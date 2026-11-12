# dmv_soft

Anwendungssoftware für die NCR Decision Mate V (DMV), einen Bürorechner
mit Z80 und 8088 aus den 1980er-Jahren. Alles läuft unter MS-DOS 2.11
(und aufwärts) und wird in MAME (Treiber `dmv`) getestet.

| Programm | Verzeichnis | Stand |
|---|---|---|
| DMVCMD – ANSI-Dualpanel-Dateimanager | `dmvcmd/` | v8.4, in MAME getestet |

Gebaute 360-KB-Sektorabbilder liegen in `images/`. Es sind **reine
Datendisketten ohne DOS** – es wird kein fremder Betriebssystemcode
mitgeliefert. Zum Benutzen von einer eigenen DOS-Startdiskette booten und
das Datenabbild als weiteres Laufwerk einlegen.

## Bauen

Gebraucht wird NASM und – zum Testen – ein MAME mit DMV-Treiber.

```
cd dmvcmd
sh build.sh            # -> ../images/dmvcmd.img (Datendiskette)
```

Der Build übersetzt **nur für den 8086** (Pre-Include `cpu8086.inc`): ohne
diesen Riegel nimmt NASM stillschweigend 386-Befehle an, die der 8088 der
DMV nicht kennt. Eine 386-Anweisung lässt den Build mit „no instruction for
this cpu level" fehlschlagen.

## Lizenz

Eigener Code unter MIT (siehe `LICENSE`). Kein fremder Code im Repo.
