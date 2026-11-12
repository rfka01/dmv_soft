# dmv_soft

Anwendungssoftware für die NCR Decision Mate V (DMV), einen Bürorechner
mit Z80 und 8088 aus den 1980er-Jahren. Alles läuft unter MS-DOS 2.11
(und aufwärts) und wird in MAME (Treiber `dmv`) getestet.

| Programm | Verzeichnis | Stand |
|---|---|---|
| DMVCMD – ANSI-Dualpanel-Dateimanager | `dmvcmd/` | v1.0, in MAME getestet |

Gebaute 360-KB-Sektorabbilder liegen in `images/`. Es sind **reine
Datendisketten ohne DOS** – es wird kein fremder Betriebssystemcode
mitgeliefert. Zum Benutzen von einer eigenen DOS-Startdiskette booten und
das Datenabbild als weiteres Laufwerk einlegen.

## Bauen

Gebraucht wird NASM und – zum Testen – ein MAME mit DMV-Treiber.

```
cd dmvcmd
sh build.sh            # -> ../images/dmvcmd_v10.img (Datendiskette)
```

Der Build übersetzt **nur für den 8086** (Pre-Include `cpu8086.inc`): ohne
diesen Riegel nimmt NASM stillschweigend 386-Befehle an, die der 8088 der
DMV nicht kennt. Eine 386-Anweisung lässt den Build mit „no instruction for
this cpu level" fehlschlagen.

Die Versionsnummer steht zentral in `build.sh` (`VER=`) und muss zum Titel
in `dmvcmd.asm` passen. Der Build legt die Versions-Textdatei `DMVCMD.V10`
mit aufs Abbild und benennt es nach der Version (`dmvcmd_v10.img`).

## Testen

```
cd dmvcmd
BOOT_IMG=/pfad/zur/dos211.img sh test.sh
```

`test.sh` startet den DMV-MAME kopflos, legt die DOS-Startdiskette in A:
und die DMVCMD-Datendiskette in B:, tippt automatisch `B:` + `DC` und zieht
ein Bildschirmfoto. Die DOS-Startdiskette ist **nicht** Teil dieses Repos
(sie enthält fremden Code) und wird über `$BOOT_IMG` angegeben.

## Lizenz

Eigener Code unter MIT (siehe `LICENSE`). Kein fremder Code im Repo.
