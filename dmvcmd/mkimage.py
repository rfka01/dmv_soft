#!/usr/bin/env python3
# mkimage.py - Dateien in ein 360-KB-FAT12-Sektorabbild der DMV einfuegen
# oder ersetzen. Im Gegensatz zu fat12write.py (nur ersetzen) legt dieses
# Werkzeug auch neue Verzeichniseintraege an, damit frische Dateien wie
# DC.BAT und DMVCMD.COM ins Image kommen.
#
#   python3 mkimage.py BASIS.IMG AUSGABE.IMG  DATEI1 [DATEI2 ...]
#
# Jede DATEI wird unter ihrem (grossgeschriebenen) 8.3-Basisnamen abgelegt.
# Existiert der Name schon, wird er ersetzt; sonst neu angelegt.
import struct, sys, os, time
from fat12 import F12


def _dos_datetime(path):
    """mtime der Datei -> (FAT-Zeitwort, FAT-Datumswort)."""
    t = time.localtime(os.path.getmtime(path))
    jahr = max(1980, t.tm_year)
    date = ((jahr - 1980) << 9) | (t.tm_mon << 5) | t.tm_mday
    tim = (t.tm_hour << 11) | (t.tm_min << 5) | (t.tm_sec // 2)
    return tim & 0xFFFF, date & 0xFFFF


def _dos83(name):
    """Dateiname -> (8-Byte-Name, 3-Byte-Erweiterung), grossgeschrieben."""
    base = os.path.basename(name).upper()
    stem, _, ext = base.partition('.')
    return stem[:8].ljust(8), ext[:3].ljust(3)


def build(basepath, outpath, files):
    f = F12(basepath)
    d = bytearray(f.d)
    spc_bytes = f.spc * f.bps
    total_clusters = (len(f.d) - f.dataoff) // spc_bytes + 2

    def fatent(n):
        off = f.fat0 + (n * 3) // 2
        cur = d[off] | (d[off + 1] << 8)
        return (cur & 0xFFF) if (n & 1) == 0 else (cur >> 4)

    def setfat(n, val):
        off = f.fat0 + (n * 3) // 2
        cur = d[off] | (d[off + 1] << 8)
        if (n & 1) == 0:
            cur = (cur & 0xF000) | (val & 0xFFF)
        else:
            cur = (cur & 0x000F) | ((val & 0xFFF) << 4)
        d[off] = cur & 0xff
        d[off + 1] = (cur >> 8) & 0xff
        off2 = off + f.spf * f.bps          # zweite FAT spiegeln
        d[off2] = cur & 0xff
        d[off2 + 1] = (cur >> 8) & 0xff

    def find_entry(nm8, ex3):
        """Verzeichnisoffset eines vorhandenen Eintrags, sonst None."""
        for i in range(f.ndir):
            o = f.rootoff + i * 32
            e = d[o:o + 32]
            if e[0] in (0, 0xE5):
                continue
            if e[0x0b] & 0x0F == 0x0F:       # LFN
                continue
            if bytes(e[0:8]) == nm8.encode('latin1') and \
               bytes(e[8:11]) == ex3.encode('latin1'):
                return o
        return None

    def free_entry():
        for i in range(f.ndir):
            o = f.rootoff + i * 32
            if d[o] in (0, 0xE5):
                return o
        raise Exception("Wurzelverzeichnis voll")

    def free_clusters(want, reuse):
        got = list(reuse)
        for c in range(2, total_clusters):
            if len(got) >= want:
                break
            if c in reuse:
                continue
            if fatent(c) == 0:
                got.append(c)
        if len(got) < want:
            raise Exception("nicht genug Platz im Abbild")
        return got[:want]

    for path in files:
        data = open(path, 'rb').read()
        nm8, ex3 = _dos83(path)
        entoff = find_entry(nm8, ex3)
        reuse = []
        if entoff is not None:                       # vorhanden: alte Kette frei
            start = struct.unpack('<H', d[entoff + 0x1a:entoff + 0x1c])[0]
            reuse = f.chain(start) if start >= 2 else []
            for c in reuse:
                setfat(c, 0)
        else:
            entoff = free_entry()

        n = max(1, (len(data) + spc_bytes - 1) // spc_bytes)
        use = free_clusters(n, reuse)
        for idx, cl in enumerate(use):
            o = f.dataoff + (cl - 2) * spc_bytes
            chunk = data[idx * spc_bytes:(idx + 1) * spc_bytes]
            d[o:o + len(chunk)] = chunk
            if len(chunk) < spc_bytes:
                d[o + len(chunk):o + spc_bytes] = b'\x00' * (spc_bytes - len(chunk))
            setfat(cl, use[idx + 1] if idx < len(use) - 1 else 0xFFF)

        e = bytearray(32)
        e[0:8] = nm8.encode('latin1')
        e[8:11] = ex3.encode('latin1')
        e[0x0b] = 0x20                                # Archiv-Bit
        tim, date = _dos_datetime(path)               # echte Build-Zeit
        struct.pack_into('<H', e, 0x16, tim)          # Zeit
        struct.pack_into('<H', e, 0x18, date)         # Datum
        struct.pack_into('<H', e, 0x1a, use[0])
        struct.pack_into('<I', e, 0x1c, len(data))
        d[entoff:entoff + 32] = e
        print(f"  {nm8.strip()}.{ex3.strip()}: {len(data)} Bytes, "
              f"{len(use)} Cluster ab {use[0]}")

    open(outpath, 'wb').write(d)
    print(f"-> {outpath}")


if __name__ == '__main__':
    if len(sys.argv) < 4:
        sys.exit("Aufruf: python3 mkimage.py BASIS.IMG AUSGABE.IMG DATEI [DATEI ...]")
    build(sys.argv[1], sys.argv[2], sys.argv[3:])
