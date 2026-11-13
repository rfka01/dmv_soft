"""gempack.py - Packformat der GEM-Bildschirmschriften (GEMVDI, Merker 0020h).

Das Bild wird zuerst zeilenweise verknuepft (jede Zeile XOR die Zeile
darueber), dann als Bitstrom aus abwechselnden Laeufen geschrieben:
  Nullen: Laenge z (tatsaechliche Nullen) als n = z (der erste Lauf n = z + 1,
          der Zeiger steht anfangs vor dem ersten Bit):
          n <= 8:  '1' + 3 Bit (n-1);  sonst k Nullen, dann n-1 mit fuehrender 1
          und k+2 weiteren Bits (k = Bitlaenge(n-1) - 3); n-1 = 65535 heisst
          "65535 weiter, dann noch ein Nullenlauf".
  Einsen: Laenge m >= 1 als (m-1) mal '1' und eine '0'.
Bits werden in 16-Bit-Woerter von oben nach unten gefuellt (Intel-Reihenfolge).
Nachgebaut nach DECODE.A86 aus dem GEM-3-VDI (GPL)."""

def _bits_aus(data):
    for b in data:
        for i in range(7, -1, -1):
            yield (b >> i) & 1

def packe(form, fw, fh):
    n = fw * fh
    z = bytearray(form[:n])
    for r in range(fh - 1, 0, -1):            # Zeilen verknuepfen (von unten)
        for x in range(fw):
            z[r * fw + x] ^= z[(r - 1) * fw + x]
    bits = list(_bits_aus(z))
    aus = []
    def wert(v):                               # Nullenlauf-Zaehler n-1
        if v < 8:
            aus.extend([1, (v >> 2) & 1, (v >> 1) & 1, v & 1])
        else:
            L = v.bit_length()
            k = L - 3
            aus.extend([0] * k)
            aus.extend((v >> i) & 1 for i in range(L - 1, -1, -1))
    i = 0
    N = len(bits)
    erster = 1
    while i < N:
        z0 = i
        while i < N and bits[i] == 0:
            i += 1
        nz = i - z0 + erster
        erster = 0
        while nz > 65535:
            wert(65535)                        # 65535 weiter, Nullen gehen weiter
            nz -= 65535
        if i >= N:
            wert(nz - 1)
            break
        wert(nz - 1)
        e0 = i
        while i < N and bits[i] == 1:
            i += 1
        m = i - e0
        aus.extend([1] * (m - 1) + [0])
    while len(aus) % 16:
        aus.append(0)
    out = bytearray()
    for w in range(0, len(aus), 16):
        v = 0
        for b in aus[w:w + 16]:
            v = (v << 1) | b
        out += bytes((v & 255, v >> 8))
    return bytes(out)

def entpacke(pack, fw, fh):
    """Pruefung: wie DECODE.A86."""
    n = fw * fh
    worte = [pack[i] | (pack[i + 1] << 8) for i in range(0, len(pack) - 1, 2)] + [0] * 4
    def bits():
        for w in worte:
            for i in range(15, -1, -1):
                yield (w >> i) & 1
    g = bits()
    aus = [0] * (n * 8)
    pos = -1
    while True:
        k = 0
        while next(g) == 0:
            k += 1
        if k == 0:
            v = (next(g) << 2) | (next(g) << 1) | next(g)
        else:
            v = 1
            for _ in range(k + 2):
                v = (v << 1) | next(g)
        cnt = v + 1
        if cnt == 65536:
            pos += 65535
            if pos >= n * 8:
                break
            continue
        pos += cnt
        if pos >= n * 8:
            break
        while True:
            aus[pos] = 1
            pos += 1
            if pos >= n * 8 or next(g) == 0:
                break
        if pos >= n * 8:
            break
    z = bytearray(n)
    for i in range(n):
        v = 0
        for b in aus[i * 8:i * 8 + 8]:
            v = (v << 1) | b
        z[i] = v
    for r in range(1, fh):
        for x in range(fw):
            z[r * fw + x] ^= z[(r - 1) * fw + x]
    return bytes(z)
