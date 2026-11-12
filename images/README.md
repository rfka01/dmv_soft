# Disketten-Abbilder

Gebaute 360-KB-Sektorabbilder (FAT12, Datensatzkennung 0xFD) aus `../dmvcmd`.
`dmvcmd_v<VER>.img` entsteht per `sh ../dmvcmd/build.sh` und ist eine **reine
Datendiskette ohne DOS** mit `DMVCMD.COM`, `DC.BAT` und der Versions-Textdatei
`DMVCMD.V<VER>`. Der Dateiname trägt die Version (z. B. `dmvcmd_v10.img` für
v1.0).

Zum Benutzen von einer DOS-Startdiskette booten und dieses Abbild als
weiteres Laufwerk einlegen.
