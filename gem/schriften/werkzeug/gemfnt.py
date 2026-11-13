"""gemfnt.py - GEM-Bitmapschriften (GDOS, Intel-Format) lesen und schreiben."""
import struct
KOPF = '<hh32shhhhhhhhhhhhhHHHIIIhhI'
def lies(pfad):
    d = open(pfad, 'rb').read()
    h = list(struct.unpack_from(KOPF, d, 0))
    (fid, pt, name, fa, la, top, asc, half, desc, bot, mcw, mcellw, lo, ro, thick, ul,
     light, skew, flags, hor, off, dat, fw, fh, nxt) = h
    offs = struct.unpack_from('<%dH' % (la - fa + 2), d, off)
    if flags & 0x20:                       # gepackt
        from gempack import entpacke
        d = d[:dat] + entpacke(d[dat:], fw, fh)
    zeichen = {}
    for i, c in enumerate(range(fa, la + 1)):
        x0, x1 = offs[i], offs[i + 1]
        rows = []
        for r in range(fh):
            zeile = d[dat + r * fw: dat + (r + 1) * fw]
            bits = [(zeile[x // 8] >> (7 - x % 8)) & 1 for x in range(x0, x1)]
            rows.append(bits)
        zeichen[c] = rows
    return dict(id=fid, pt=pt, name=name.split(b'\0')[0].decode('latin1'), first=fa, last=la,
                top=top, ascent=asc, half=half, descent=desc, bottom=bot, flags=flags,
                thick=thick, ul=ul, fh=fh, zeichen=zeichen, hor=hor, off=off, dat=dat, fw=fw)

def schreibe(pfad, fid, pt, name, first, last, top, ascent, half, descent, bottom,
             zeichen, thick=1, ul=1, mono=False, packen=False):
    """zeichen: dict code -> Liste von Zeilen (Listen 0/1), alle gleich hoch
    (top+bottom+1). Fehlende Codes werden 0 breit."""
    fh = top + bottom + 1
    breiten = [len(zeichen[c][0]) if c in zeichen and zeichen[c] and zeichen[c][0] is not None else 0
               for c in range(first, last + 1)]
    offs = [0]
    for b in breiten:
        offs.append(offs[-1] + b)
    gesamt = offs[-1]
    fw = ((gesamt + 15) // 16) * 2
    daten = bytearray(fw * fh)
    for i, c in enumerate(range(first, last + 1)):
        if not breiten[i]:
            continue
        rows = zeichen[c]
        assert len(rows) == fh, (c, len(rows), fh)
        for r in range(fh):
            for x, bit in enumerate(rows[r]):
                if bit:
                    X = offs[i] + x
                    daten[r * fw + X // 8] |= 0x80 >> (X % 8)
    n = last - first + 1
    hor = 152 if packen else 88
    off = hor + 2 * n
    dat = off + 2 * (n + 1)
    mw = max(breiten) if breiten else 0
    flags = 0x0004 if False else 0
    if mono:
        flags |= 0x08
    kopf = struct.pack(KOPF, fid, pt, name.encode('latin1')[:31].ljust(32, b'\0'), first, last,
                       top, ascent, half, descent, bottom, mw, mw, 0, 0, thick, ul,
                       0x5555, 0x5555, flags | 0x02, hor, off, dat, fw, fh, 0)
    hortab = b'\0' * (2 * n)
    offtab = struct.pack('<%dH' % (n + 1), *offs)
    if packen:
        # gepackt (Merker 0020h, GEMVDI entpackt beim Laden): Kopf 152 Byte,
        # Wort 150 = Laenge ab der Tabelle
        from gempack import packe
        bild = packe(bytes(daten), fw, fh)
        kopf = bytearray(kopf)
        struct.pack_into('<H', kopf, 66, struct.unpack_from('<H', kopf, 66)[0] | 0x20)
        rest = len(hortab) + len(offtab) + len(bild)
        kopf += bytes(152 - len(kopf))
        struct.pack_into('<H', kopf, 150, rest)
        daten = bild
    open(pfad, 'wb').write(bytes(kopf) + hortab + offtab + bytes(daten))
    return len(kopf) + len(hortab) + len(offtab) + len(daten)
