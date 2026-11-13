#!/usr/bin/env python3
"""bau_schriften.py - GEM-Bildschirmschriften fuer die DMV aus freien Schriften
und "Decision Line" aus dem Zeichen-ROM der DMV.

  python3 bau_schriften.py [--rom dmv_norm.bin] [--aus VERZEICHNIS]

Ausgabe (Vorgabe ../vga/):
  AA*.VGA   Swiss (Id 2)  aus TeX Gyre Heros  (GUST Font License)
  AI*.VGA   Dutch (Id 14) aus TeX Gyre Termes (GUST Font License)
            7, 10, 14, 18, 20, 28, 36, 48 pt, Dateinamen wie im FreeGEM-Satz
  FH*.VGA   Falsifikata halbfett condensed (Id 62) aus Federo (SIL OFL),
            schmaler und kraeftiger gerastert, 10-36 pt
  DL*.VGA   Decision Line (Id 60), 10-36 pt, und DecisionLine.ttf - nur mit
            --rom: das Hauptplatinen-ROM der DMV (MAME: dmv_norm.bin) liefert
            die Zeichen; ohne ROM wird Decision Line nicht gebaut.

Die Quellschriften liegen in ../quellen (Lizenzen dort); andere Pfade ueber
die Umgebungsvariablen HEROS, TERMES, FEDERO.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import freetype
from gemfnt import schreibe
from zeichensatz import GEM, ERSTES, LETZTES
import decision

HIER = os.path.dirname(os.path.abspath(__file__))
AUS = os.path.join(HIER, '..', 'vga')

# Quellschriften: Pfad, oder Umgebungsvariable mit demselben Namen
TEXGYRE = os.path.join(HIER, '..', 'quellen', 'tex-gyre')
QUELLEN = {
    'HEROS': os.environ.get('HEROS', TEXGYRE + '/texgyreheros-regular.otf'),    # CTAN tex-gyre
    'TERMES': os.environ.get('TERMES', TEXGYRE + '/texgyretermes-regular.otf'),
    'FEDERO': os.environ.get('FEDERO', os.path.join(HIER, '..', 'quellen', 'federo',
                             'Federo-Regular.ttf')),  # google/fonts ofl/federo
}
# Groessen und Dateinamen wie im FreeGEM-Satz (7 und 18 pt mit "P"-Namen)
SATZ = [7, 10, 14, 18, 20, 28, 36, 48]
def satzname(kurz, pt):
    return '%s%03dGVP.VGA' % (kurz, pt * 10) if pt in (7, 18) else '%s%04dGV.VGA' % (kurz, pt * 10)
GROESSEN = [10, 14, 18, 20, 28, 36]   # wie Swiss/Dutch; 7 pt ist fuer Zierschriften zu klein
AUTOHINT = True       # Auto-Hinter von FreeType; False = Hinting der Schrift selbst
DUENN_ST = 0          # waagrechte Striche duenner (26.6, wird je Groesse gesetzt)
MODUS = 'auto'        # je Groesse: 'auto' (Auto-Hinter), 'nativ' (Hinting der Schrift), 'grau' (Graustufen ab SCHWELLE)
SCHWELLE = 96          # Graustufe ab der ein Punkt gesetzt wird (0..255)
SCHRAEG = set('AÄKMNVWXYZ')
LINIEN = False
VOR_LINEAR = 0       # x-Skalierung, wenn der Vorschub ungehintet sein soll, sonst 0
FETT_VOR = 1.0       # Anteil des Fetts, der in die Vorschubbreite geht        # duenne Striche (Haarlinien, Querstriche) nie abreissen lassen

# ---------------- Decision Line ----------------
DL_GROESSEN = [10, 14, 18, 20, 28, 36]

def decision_line():
    """Decision Line in mehreren Groessen, eckig: jedes ROM-Raster (8x16)
    wird auf round(pt*0,8) x round(pt*1,6) Punkte vergroessert (naechster
    Nachbar). 10 pt = ROM 1:1, 20 pt = jeder Punkt verdoppelt."""
    g = decision.baue()
    for pt in DL_GROESSEN:
        w = round(8 * pt / 10)
        h = round(16 * pt / 10)
        zeichen = {}
        for c in range(ERSTES, LETZTES + 1):
            ch = GEM.get(c)
            if ch is None or ch not in g:
                continue
            src = g[ch]
            zeichen[c] = [[src[y * 16 // h][x * 8 // w] for x in range(w)] for y in range(h)]
        k = lambda v: round(v * h / 16)
        top = k(decision.BASIS + 1) - 1
        bottom = h - top - 1
        # Kein Gleichbreiten-Merker (Bit 3): bei 8 Punkten Breite nimmt der
        # Treiber sonst den Schnellweg MONO8XHT, der Codes ab 80h falsch setzt
        n = schreibe(os.path.join(AUS, 'DL%04dGV.VGA' % (pt * 10)), 60, pt, 'Decision Line',
                     ERSTES, LETZTES, top, k(8), k(5), k(3), bottom,
                     zeichen, thick=max(1, k(1)), ul=max(1, k(1)), mono=False, packen=True)
        print('Decision Line %2d pt: %dx%d, %d Byte' % (pt, w, h, n))
    return g

def decision_ttf(g):
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.ttLib import removeOverlaps
    P = 64
    UPM = 16 * P
    zeichen = sorted(ch for ch in g if len(ch) == 1 and ord(ch) >= 32)
    if ' ' not in zeichen:
        zeichen.insert(0, ' ')
    namen = ['.notdef'] + ['uni%04X' % ord(ch) for ch in zeichen]
    cmap = {ord(ch): 'uni%04X' % ord(ch) for ch in zeichen}
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(namen)
    fb.setupCharacterMap(cmap)
    glyphen, metrik = {}, {}
    def quadrat(pen, x, y):
        x0, y0 = x * P, y * P
        pen.moveTo((x0, y0)); pen.lineTo((x0, y0 + P)); pen.lineTo((x0 + P, y0 + P))
        pen.lineTo((x0 + P, y0)); pen.closePath()
    # .notdef: Rahmen
    pen = TTGlyphPen(None)
    for y in range(-3, 9):
        for x in (1, 6):
            quadrat(pen, x, y)
    for x in range(2, 6):
        quadrat(pen, x, -3); quadrat(pen, x, 8)
    glyphen['.notdef'] = pen.glyph(); metrik['.notdef'] = (8 * P, P)
    for ch in zeichen:
        pen = TTGlyphPen(None)
        rows = g.get(ch, decision.leer())
        links = 8
        for r in range(16):
            for x in range(8):
                if rows[r][x]:
                    # Zeile r: Unterkante bei (BASIS - r) Punkten ueber der Grundlinie
                    quadrat(pen, x, decision.BASIS - r)
                    links = min(links, x)
        n = 'uni%04X' % ord(ch)
        glyphen[n] = pen.glyph()
        metrik[n] = (8 * P, links * P if links < 8 else 0)
    fb.setupGlyf(glyphen)
    fb.setupHorizontalMetrics(metrik)
    asc, desc = (decision.BASIS + 1) * P, (16 - decision.BASIS - 1) * P
    fb.setupHorizontalHeader(ascent=asc, descent=-desc)
    fb.setupNameTable({
        'familyName': 'Decision Line', 'styleName': 'Regular',
        'uniqueFontIdentifier': 'Decision Line Regular 1.0',
        'fullName': 'Decision Line', 'psName': 'DecisionLine-Regular',
        'version': 'Version 1.0',
        'copyright': 'Zeichenformen nach dem Zeichengenerator der NCR Decision Mate V (ROM 33610)',
        'description': 'Bildschirmschrift der NCR Decision Mate V, 8x16-Raster',
    })
    fb.setupOS2(sTypoAscender=asc, sTypoDescender=-desc, sTypoLineGap=0,
                usWinAscent=asc, usWinDescent=desc, sxHeight=6 * P, sCapHeight=9 * P,
                achVendID='DMV ', fsType=0, ulCodePageRange1=1,
                panose=__import__('fontTools.ttLib.tables.O_S_2f_2', fromlist=['Panose']).Panose())
    fb.font['OS/2'].panose.bProportion = 9          # monospaced
    fb.font['OS/2'].fsSelection = 0x40               # REGULAR
    fb.font['OS/2'].ulUnicodeRange1 = 0x00000003     # Basic Latin, Latin-1
    fb.setupPost(isFixedPitch=1, underlinePosition=-2 * P, underlineThickness=P)
    fb.setupDummyDSIG() if hasattr(fb, 'setupDummyDSIG') else None
    removeOverlaps.removeOverlaps(fb.font)
    pfad = os.path.join(AUS, 'DecisionLine.ttf')
    fb.save(pfad)
    print('DecisionLine.ttf: %d Glyphen, %d Byte' % (len(namen), os.path.getsize(pfad)))

def glyphe(face, ch, st, hint):
    """Ein Zeichen rastern. hint: Auto-Hinter + 1 Bit (saubere Staemme wie
    bei handgesetzten Bildschirmschriften), sonst Graustufen ab SCHWELLE."""
    F = freetype
    if MODUS == 'grau':
        hint = False
    if hint:
        face.load_char(ch, F.FT_LOAD_NO_BITMAP | (F.FT_LOAD_FORCE_AUTOHINT if AUTOHINT else 0) | F.FT_LOAD_TARGET_MONO)
    else:
        face.load_char(ch, F.FT_LOAD_NO_BITMAP | F.FT_LOAD_TARGET_LIGHT)
    if st:
        from ctypes import byref
        F.raw.FT_Outline_EmboldenXY(byref(face.glyph.outline._FT_Outline), st, -DUENN_ST)   # senkrechte Striche staerker, waagrechte (DUENN) duenner
    face.glyph.render(F.FT_RENDER_MODE_MONO if hint else F.FT_RENDER_MODE_NORMAL)
    b = face.glyph.bitmap
    rows = []
    for r in range(b.rows):
        if hint:
            rows.append([(b.buffer[r * b.pitch + x // 8] >> (7 - x % 8)) & 1 for x in range(b.width)])
        else:
            rows.append([1 if b.buffer[r * b.pitch + x] >= SCHWELLE else 0 for x in range(b.width)])
    if VOR_LINEAR:
        # Vorschub ungehintet (der Auto-Hinter rundet die Breiten auf, die
        # Schrift laeuft sonst bei kleinen Groessen zu weit)
        vor = round(face.glyph.linearHoriAdvance / 65536 * VOR_LINEAR + st * FETT_VOR / 64)
        return rows, face.glyph.bitmap_left, face.glyph.bitmap_top, vor
    return rows, face.glyph.bitmap_left, face.glyph.bitmap_top, (face.glyph.advance.x + int(st * FETT_VOR) + 32) >> 6

DIAERESE = {'ä': 'a', 'ö': 'o', 'ü': 'u', 'Ä': 'A', 'Ö': 'O', 'Ü': 'U', 'ë': 'e',
            'ï': 'ı', 'ÿ': 'y', 'Ÿ': 'Y', 'Ë': 'E', 'Ï': 'I'}

def fein(face, ch, st, em, f=8):
    """Referenz: ungehintet, f-fach fein, Graustufen. Liefert Bitmap (0..255),
    left, top in Feinpunkten."""
    face.set_pixel_sizes(0, em * f)
    F = freetype
    face.load_char(ch, F.FT_LOAD_NO_BITMAP | F.FT_LOAD_NO_HINTING)
    if st:
        from ctypes import byref
        F.raw.FT_Outline_EmboldenXY(byref(face.glyph.outline._FT_Outline), st * f, -DUENN_ST * f)
    face.glyph.render(F.FT_RENDER_MODE_NORMAL)
    b = face.glyph.bitmap
    import numpy as np
    if b.rows and b.width:
        g = np.array(b.buffer, dtype=np.uint8).reshape(b.rows, b.pitch)[:, :b.width].tolist()
    else:
        g = []
    l, t = face.glyph.bitmap_left, face.glyph.bitmap_top
    face.set_pixel_sizes(0, em)
    return g, l, t

def gruppen(bm, schwelle=128):
    """Zusammenhaengende Gruppen (8er-Nachbarschaft) als Punktlisten."""
    import numpy as np
    from scipy import ndimage
    if not bm or not bm[0]:
        return []
    a = np.array(bm) >= schwelle
    lab, n = ndimage.label(a, structure=np.ones((3, 3), int))
    erg = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        erg.append(list(zip(ys.tolist(), xs.tolist())))
    return erg

def setze(rows, bl, bt, X, Y):
    """Punkt bei Spalte X (absolut, Pixel ab Ursprung) und Hoehe Y (Zeile
    ueber der Grundlinie, oberer Rand) setzen; Bitmap waechst bei Bedarf."""
    w = len(rows[0]) if rows else 0
    if not rows:
        return [[1]], X, Y
    if X < bl:
        k = bl - X; rows = [[0] * k + r for r in rows]; bl = X; w += k
    if X >= bl + w:
        k = X - bl - w + 1; rows = [r + [0] * k for r in rows]; w += k
    if Y > bt:
        k = Y - bt; rows = [[0] * w for _ in range(k)] + rows; bt = Y
    if bt - Y >= len(rows):
        k = bt - Y - len(rows) + 1; rows = rows + [[0] * w for _ in range(k)]
    rows[bt - Y][X - bl] = 1
    return rows, bl, bt

def teilweise(teile_ref, g, gl, gt, f):
    """Jede Gruppe der feinen Referenz einzeln auf ganze Punkte bringen
    (Deckung >= 40 %, sonst der staerkste Punkt), groesste zuerst; eine
    kleinere Gruppe, die eine schon gesetzte beruehrt, wird um einen Punkt
    weggeschoben."""
    gesetzt = set()                         # (X, Y): Spalte, Zeilen-Oberkante
    for p in sorted(teile_ref, key=len, reverse=True):
        deck = {}
        for y, x in p:
            k = ((gl + x) // f, (gt - y - 1) // f + 1)
            deck[k] = deck.get(k, 0) + g[y][x]
        zellen = {k for k, v in deck.items() if v >= 0.4 * f * f * 255}
        if not zellen:
            zellen = {max(deck, key=deck.get)}
        def stoesst(z):
            return any((X + dx, Y + dy) in gesetzt for X, Y in z for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        if gesetzt and stoesst(zellen):
            # Richtung weg vom bisherigen Schwerpunkt bevorzugen
            sx = sum(X for X, Y in gesetzt) / len(gesetzt); sy = sum(Y for X, Y in gesetzt) / len(gesetzt)
            zx = sum(X for X, Y in zellen) / len(zellen); zy = sum(Y for X, Y in zellen) / len(zellen)
            kand = sorted([(0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (-1, 1), (1, -1), (-1, -1)],
                          key=lambda d: -((zx + d[0] - sx) ** 2 + (zy + d[1] - sy) ** 2))
            for dx, dy in kand:
                z2 = {(X + dx, Y + dy) for X, Y in zellen}
                if not stoesst(z2):
                    zellen = z2
                    break
            else:
                zellen = {z for z in zellen if not stoesst({z})} or zellen
        gesetzt |= zellen
    X0 = min(X for X, Y in gesetzt); X1 = max(X for X, Y in gesetzt)
    Y1 = max(Y for X, Y in gesetzt); Y0 = min(Y for X, Y in gesetzt)
    rows = [[1 if (X, Y) in gesetzt else 0 for X in range(X0, X1 + 1)] for Y in range(Y1, Y0 - 1, -1)]
    return rows, X0, Y1

def linien(rows, bl, bt, g, gl, gt, f):
    """Duenne Striche erhalten: Skelett der feinen Referenz dort, wo der
    Strich schmaler als 1,5 Punkte ist, auf ganze Punkte bringen und setzen.
    So bleiben der Querstrich des f und die Haarlinien des M stehen, auch
    wenn die 1-Bit-Rasterung sie verliert; kraeftige Staemme bleiben, wie
    sie sind."""
    import numpy as np
    from scipy import ndimage
    from skimage.morphology import skeletonize
    a = np.array(g) >= 40
    if not a.any():
        return rows, bl, bt
    d = ndimage.distance_transform_edt(a)
    sk = skeletonize(a) & (d < 0.75 * f)
    ys, xs = np.nonzero(sk)
    zellen = {}
    for y, x in zip(ys.tolist(), xs.tolist()):
        k = ((gl + x) // f, (gt - y - 1) // f + 1)
        zellen[k] = zellen.get(k, 0) + 1
    deck = {}
    gy, gx = np.nonzero(np.array(g) > 0)
    ga = np.array(g)
    for y, x in zip(gy.tolist(), gx.tolist()):
        k = ((gl + x) // f, (gt - y - 1) // f + 1)
        deck[k] = deck.get(k, 0) + int(ga[y, x])
    for (X, Y), n in zellen.items():
        # wenigstens ein halber Punkt Skelett und 8 % gedeckt (keine
        # Auslaeufer des Skeletts in Ecken und Serifen)
        if n >= f // 2 and deck.get((X, Y), 0) >= 0.08 * f * f * 255:
            rows, bl, bt = setze(rows, bl, bt, X, Y)
    return rows, bl, bt

def f_balken(rows, bl, bt, em):
    """Querstrich des f deutlich machen (sonst liest es sich bei manchen
    Groessen als langes s): Stamm aus der untersten Zeile, Querstrich in der
    breitesten Zeile der oberen Haelfte, beidseitig auf eine sichtbare
    Laenge gebracht."""
    unten = [x for x, b in enumerate(rows[-1]) if b]
    if not unten:
        return rows, bl, bt
    s0, s1 = min(unten), max(unten)
    h = len(rows)
    kand = [(sum(r), i) for i, r in enumerate(rows[h // 5: h * 2 // 3], h // 5)]
    breit, zi = max(kand)
    if breit <= s1 - s0 + 1:
        zi = h // 3                            # kein Querstrich gefunden
    Y = bt - zi
    links = max(1, round(em * 0.06))
    rechts = max(2, round(em * 0.12))
    dq = max(1, round(em / 22))
    for X in range(bl + s0 - links, bl + s1 + rechts + 1):
        for dy in range(dq):
            rows, bl, bt = setze(rows, bl, bt, X, Y - dy)
    return rows, bl, bt

def noppen(rows):
    """Einzelne Ausreisser-Punkte auf glatten Kanten entfernen: Der
    Auto-Hinter laesst den Ueberhang runder Formen (Oberkante von g, o, e)
    oft als 1-2 Punkte breite Noppe stehen. Entfernt wird eine Noppe, die
    auf einer Kante liegt, die auf beiden Seiten wenigstens 2 Punkte weiter
    reicht - Spitzen (A, V) und Punkte (i, j) bleiben."""
    if not rows or len(rows) < 3:
        return rows
    import numpy as np
    a = np.array(rows, dtype=np.uint8)
    for k in range(4):                      # alle vier Richtungen: oben, links, unten, rechts
        h, w = a.shape
        weg = []
        for y in range(h):
            x = 0
            while x < w:
                if not a[y, x]:
                    x += 1
                    continue
                x0 = x
                while x < w and a[y, x]:
                    x += 1
                x1 = x - 1                      # Lauf x0..x1 in Zeile y
                if x1 - x0 > 1 or y + 1 >= h:
                    continue
                if y > 0 and a[y - 1, max(0, x0 - 1):x1 + 2].any():
                    continue                    # darueber etwas: keine Noppe
                if x0 - 2 < 0 or x1 + 2 >= w:
                    continue
                if a[y + 1, x0 - 2:x1 + 3].all():
                    weg.append((y, x0, x1))
        for y, x0, x1 in weg:
            a[y, x0:x1 + 1] = 0
        a = np.rot90(a)
    return a.tolist()

def sauber(face, ch, st, em):
    """Zeichen gehintet rastern und die groebsten Fehler beheben:
    Umlautpunkte selbst setzen (getrennt, mit Abstand), verlorene Teile
    (Punkte, Akzente) aus der feinen Referenz ergaenzen."""
    f = 8
    if ch in DIAERESE and face.get_char_index(ord(DIAERESE[ch])):
        rows, bl, bt, vor = sauber(face, DIAERESE[ch], st, em)
        g, gl, gt = fein(face, ch, st, em, f)
        gb, _, gbt = fein(face, DIAERESE[ch], st, em, f)
        oben_basis = gbt                      # Oberkante des Grundbuchstabens (fein)
        punkte = [p for p in gruppen(g) if max(gt - y for y, x in p) > oben_basis + f // 2
                  and min(gt - y for y, x in p) >= oben_basis - f // 2]
        punkte = sorted(punkte, key=lambda p: min(x for y, x in p))[:2]
        if len(punkte) == 2:
            # Punktgroesse: Hoehe der Punkte, wenigstens 1, hoechstens 3
            hoehe = max(max(gt - y for y, x in p) - min(gt - y for y, x in p) + 1 for p in punkte)
            d = max(1, min(3, round(hoehe / f)))
            xs = [round((gl + sum(x for y, x in p) / len(p)) / f - d / 2) for p in punkte]
            if xs[1] - (xs[0] + d) < 1:            # wenigstens 1 Punkt Luecke
                xs[1] = xs[0] + d + 1
            # oberste besetzte Zeile des Grundbuchstabens
            obenpix = bt
            for r in rows:
                if any(r):
                    break
                obenpix -= 1
            unten = round(min(min(gt - y for y, x in p) for p in punkte) / f)
            unten = max(unten, obenpix + 2)    # 1 Zeile Abstand zum Buchstaben
            for X0 in xs:
                for dx in range(d):
                    for dy in range(d):
                        rows, bl, bt = setze(rows, bl, bt, X0 + dx, unten + d - 1 - dy)
            return rows, bl, bt, vor
    rows, bl, bt, vor = glyphe(face, ch, st, True)
    rows = noppen(rows)
    g, gl, gt = fein(face, ch, st, em, f)
    if LINIEN and g:
        # Referenz ohne das Ausduennen der Waagerechten, sonst sind die
        # Haarlinien (Schraegen des M) auch dort schon weg
        global DUENN_ST
        d0, DUENN_ST = DUENN_ST, 0
        g2, gl2, gt2 = fein(face, ch, st, em, f)
        DUENN_ST = d0
        rows, bl, bt = linien(rows, bl, bt, g2, gl2, gt2, f)
    teile_ref = [p for p in gruppen(g) if len(p) >= f * f // 8]
    if len(teile_ref) > 1 and teile(rows) < len(teile_ref):
        # Teile verschmolzen (Doppelpunkt, Akzent am Buchstaben): jeden Teil
        # einzeln rastern und mit wenigstens 1 Punkt Abstand zusammensetzen
        rows, bl, bt = teilweise(teile_ref, g, gl, gt, f)
        return rows, bl, bt, vor
    for p in gruppen(g):
        if len(p) < f * f // 8:                # Kruemel der Referenz
            continue
        # Ist an dieser Stelle (1 Punkt Toleranz) etwas gesetzt?
        cells = {}
        for y, x in p:
            X = (gl + x) // f; Y = (gt - y - 1) // f + 1     # Y: Zeile, oberer Rand
            cells[(X, Y)] = cells.get((X, Y), 0) + g[y][x]
        da = False
        for (X, Y) in cells:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    xx, yy = X + dx - bl, bt - (Y + dy)
                    if 0 <= yy < len(rows) and 0 <= xx < len(rows[yy]) and rows[yy][xx]:
                        da = True
        if not da:
            X, Y = max(cells, key=cells.get)
            rows, bl, bt = setze(rows, bl, bt, X, Y)
    return rows, bl, bt, vor

def punkte_setzen(rows, bl, bt, em):
    """Zwei Umlautpunkte ueber einen Buchstaben setzen (1 Zeile Abstand)."""
    sp = [x for r in rows for x, b in enumerate(r) if b]
    if not sp:
        return rows, bl, bt
    x0, x1 = min(sp), max(sp)
    obenpix = bt
    for r in rows:
        if any(r):
            break
        obenpix -= 1
    d = max(1, round(em / 16))
    w = x1 - x0 + 1
    xs = [bl + x0 + round(w * 0.27 - d / 2), bl + x0 + round(w * 0.73 - d / 2)]
    if xs[1] - (xs[0] + d) < 1:
        xs[1] = xs[0] + d + 1
    unten = obenpix + 2
    for X0 in xs:
        for dx in range(d):
            for dy in range(d):
                rows, bl, bt = setze(rows, bl, bt, X0 + dx, unten + d - 1 - dy)
    return rows, bl, bt

def teile(rows):
    """Zahl der zusammenhaengenden Punktgruppen (8er-Nachbarschaft)."""
    gesehen = set(); n = 0
    for y, r in enumerate(rows):
        for x, v in enumerate(r):
            if v and (y, x) not in gesehen:
                n += 1; stapel = [(y, x)]; gesehen.add((y, x))
                while stapel:
                    a, b = stapel.pop()
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            q = (a + dy, b + dx)
                            if 0 <= q[0] < len(rows) and 0 <= q[1] < len(rows[q[0]]) and rows[q[0]][q[1]] and q not in gesehen:
                                gesehen.add(q); stapel.append(q)
    return n

# ---------------- aus Umrissschriften gerastert ----------------
def raster(pfad, fid, name, kurz, xskal=1.0, fett=0.0, groessen=None, dateiname=None, modus=None,
           unicase=None, bis=None, duenn=0.0, leicht=1.0, emfak=4/3, fettvor=1.0, linear=False):
    """modus: Funktion pt -> 'auto' | 'nativ' | 'grau' (Vorgabe 'auto').
    unicase: Kleinbuchstaben, die nicht in dieser Zeichenkette stehen, als
    verkleinerte Versalien auf x-Hoehe (Art Peignot); die genannten
    (Ober-/Unterlaengen wie b d f h k l) bleiben gemeine Buchstaben."""
    global AUTOHINT, MODUS, SCHWELLE, DUENN_ST, LINIEN, FETT_VOR, VOR_LINEAR
    FETT_VOR = fettvor
    VOR_LINEAR = xskal if linear else 0
    LINIEN = duenn > 0
    face = freetype.Face(pfad)
    if unicase is not None:
        face.load_char('x', freetype.FT_LOAD_NO_SCALE)
        xh = face.glyph.metrics.height
        face.load_char('H', freetype.FT_LOAD_NO_SCALE)
        kh = face.glyph.metrics.height
        klein = xh / kh
    for pt in (groessen or GROESSEN):
        MODUS = modus(pt) if modus else 'auto'
        AUTOHINT = MODUS != 'nativ'
        SCHWELLE = 110 if MODUS == 'grau' else 96
        em = emfak[pt] if isinstance(emfak, dict) else round(pt * emfak)
        face.set_pixel_sizes(0, em)
        m = freetype.Matrix(int(xskal * 0x10000), 0, 0, 0x10000)
        face.set_transform(m, freetype.Vector(0, 0))
        st = int((fett(pt) if callable(fett) else fett) * em * 64)
        duenn_pt = int(duenn * em * 64) if pt >= 14 else 0
        bm = {}
        oben, unten = 0, 0
        for c in range(ERSTES, LETZTES + 1):
            ch = GEM.get(c)
            if ch is None or face.get_char_index(ord(ch)) == 0 and ch != ' ':
                continue
            quelle = ch
            # Schraegen (M N W A ...) nicht ausduennen - sie reissen sonst ab
            DUENN_ST = 0 if ch.upper() in SCHRAEG else duenn_pt
            if unicase is not None and ch.islower() and ch not in unicase \
                    and ch.upper() != ch and len(ch.upper()) == 1 \
                    and face.get_char_index(ord(ch.upper())):
                # verkleinerte Versalie, etwas breiter als nur verkleinert
                quelle = ch.upper()
                face.set_transform(freetype.Matrix(int(xskal * klein * 1.12 * 0x10000), 0, 0,
                                                   int(klein * 0x10000)), freetype.Vector(0, 0))
            if unicase is not None and ch in 'ij':
                # i und j wie bei der Peignot: Stamm der kleinen Versalie I,
                # beim j bis in die Unterlaenge, Punkt mit deutlichem Abstand
                quelle = 'I'
                face.set_transform(freetype.Matrix(int(xskal * klein * 1.12 * 0x10000), 0, 0,
                                                   int(klein * 0x10000)), freetype.Vector(0, 0))
            # Zeichen mit engen Innenraeumen nicht verstaerken, sonst laufen sie zu
            if unicase is not None and ch in 'ij':
                rows, bl, bt, vor = sauber(face, 'I', st, em)
                sp = [x for r in rows for x, b in enumerate(r) if b]
                x0, x1 = bl + min(sp), bl + max(sp)
                oben = bt
                for r in rows:
                    if any(r):
                        break
                    oben -= 1
                sw = x1 - x0 + 1
                if ch == 'j':
                    tief = max(2, round(em * 0.22))
                    for X in range(x0, x1 + 1):
                        for Y in range(0, -tief, -1):
                            rows, bl, bt = setze(rows, bl, bt, X, Y)
                abst = max(2, round(em * 0.22))
                for X in range(x0, x1 + 1):
                    for Y in range(oben + abst + sw, oben + abst, -1):
                        rows, bl, bt = setze(rows, bl, bt, X, Y)
            elif unicase is not None and ch == 'g' and quelle == 'G':
                # Peignot-g: kleines G - offenes C, rechts ein kraeftiger
                # Stamm erst ab halber Hoehe (oben bleibt die Oeffnung, sonst
                # waere es ein q) bis in die Unterlaenge, mit kurzem Querstrich
                rows, bl, bt, vor = sauber(face, 'C', st, em)
                ri, _, _, _ = sauber(face, 'I', st, em)
                sw = max(sum(r) for r in ri) if ri else 1
                sp = [x for r in rows for x, b in enumerate(r) if b]
                x1 = bl + max(sp)
                oben = bt
                for r in rows:
                    if any(r):
                        break
                    oben -= 1
                tief = max(2, round(em * 0.22))
                mitte = max(2, round(oben * 0.55))
                # rechte Kante der Oeffnung freimachen: oberhalb der Mitte
                # bleibt nur der obere Bogen des C stehen
                for X in range(x1 - sw + 1, x1 + 1):
                    for Y in range(mitte, -tief, -1):
                        rows, bl, bt = setze(rows, bl, bt, X, Y)
                dq = max(1, round(em / 22))
                for X in range(x1 - sw - max(1, sw // 2), x1 - sw + 1):
                    for Y in range(mitte, mitte - dq, -1):
                        rows, bl, bt = setze(rows, bl, bt, X, Y)
            elif quelle in DIAERESE and (quelle != ch or unicase is not None):
                # kleine Versalie mit Umlaut: Grundbuchstabe, Punkte selbst setzen
                rows, bl, bt, vor = sauber(face, DIAERESE[quelle], st, em)
                rows, bl, bt = punkte_setzen(rows, bl, bt, em)
            else:
                sx = st
                if unicase is not None and ch in unicase and ch.isalpha():
                    sx = int(st * leicht)          # gemeine Buchstaben leichter
                rows, bl, bt, vor = sauber(face, quelle, 0 if ch in '#%@$&‰' else sx, em)
                if unicase is not None and ch == 'f' and rows:
                    rows, bl, bt = f_balken(rows, bl, bt, em)
            if quelle != ch:
                face.set_transform(m, freetype.Vector(0, 0))
            bm[c] = (bl, bt, rows, max(vor, 1))
            if rows:
                oben = max(oben, bt)
                unten = max(unten, len(rows) - bt)
        asc_m = face.size.ascender >> 6
        desc_m = -(face.size.descender >> 6)
        # Hoehe aus den Zeichen selbst (Umlaute, Unterlaengen), nicht aus dem
        # Zeilenabstand der Quelle - so wie die Schriften von GEM
        top = oben - 1
        bottom = unten
        fh = top + bottom + 1
        zeichen = {}
        for c, (bl, bt, rows, vor) in bm.items():
            breite = max(vor, bl + (len(rows[0]) if rows else 0))
            lx = max(bl, 0)
            breite = max(breite, lx + (len(rows[0]) if rows else 0))
            z = [[0] * breite for _ in range(fh)]
            for r, zeile in enumerate(rows):
                y = top - (bt - 1) + r
                if 0 <= y < fh:
                    for x, bit in enumerate(zeile):
                        if bit and 0 <= lx + x < breite:
                            z[y][lx + x] = 1
            zeichen[c] = z
        def h(ch):
            c = [k for k, v in GEM.items() if v == ch][0]
            return bm[c][1] if c in bm else 0
        ascent = h('H') - 1 if h('H') else top
        half = h('x') - 1 if h('x') else top // 2
        descent = max(0, bm[ord('p')][2] and len(bm[ord('p')][2]) - bm[ord('p')][1]) if ord('p') in bm else bottom
        dick = max(1, em // 12)
        # Ein Zeichensatz muss in 64 KB passen (Punkt-Versatz 16 Bit, Bild
        # in einem Segment): bei grossen Groessen hinten Zeichen weglassen
        letzt = min(LETZTES, (bis or {}).get(pt, LETZTES))
        def masse(l):
            w = sum(len(zeichen[c][0]) for c in zeichen if c <= l and zeichen[c])
            return w, ((w + 15) // 16) * 2 * fh
        while masse(letzt)[0] > 65535 or masse(letzt)[1] > 65000:
            letzt -= 1
        datei = (dateiname or (lambda k, p: '%s%04dGV.VGA' % (k, p * 10)))(kurz, pt)
        n = schreibe(os.path.join(AUS, datei), fid, pt, name,
                     ERSTES, letzt, top, ascent, half, descent, bottom,
                     {c: v for c, v in zeichen.items() if c <= letzt},
                     thick=dick, ul=dick, packen=True)
        print('%s %2d pt: Hoehe %d, bis %d, %d Byte' % (name, pt, fh, letzt, n))

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description='GEM-Schriften fuer die DMV bauen')
    ap.add_argument('--rom', help='Hauptplatinen-ROM der DMV (dmv_norm.bin) fuer Decision Line')
    ap.add_argument('--aus', help='Ausgabeverzeichnis (Vorgabe ../vga)')
    a = ap.parse_args()
    if a.aus:
        AUS = a.aus
    os.makedirs(AUS, exist_ok=True)
    if a.rom:
        decision.ROM = a.rom
        g = decision_line()
        decision_ttf(g)
    # Zeichenumfang je Groesse wie im FreeGEM-Satz (grosse Groessen kuerzer,
    # sonst belegen die Schriften in jedem Programm zu viel Speicher)
    BIS = {36: 203, 48: 131}
    # Swiss/Dutch in den Massen des GEM-Satzes: Pixelgroesse je Groesse so
    # gewaehlt, dass Versal- und x-Hoehe wie bei den GEM-Schriften ausfallen
    # (etwa 91 dpi statt 96), Vorschub ungehintet (sonst zu weit gesperrt),
    # 14 pt etwas kraeftiger (2 Punkte breite Staemme wie im GEM-Satz)
    raster(QUELLEN['HEROS'], 2, 'Swiss', 'AA', groessen=SATZ, dateiname=satzname, bis=BIS,
           fett=lambda pt: 0.035 if pt == 14 else 0, fettvor=0, linear=True,
           emfak={7: 9, 10: 12, 14: 17, 18: 22, 20: 24, 28: 35, 36: 46, 48: 61})
    # Dutch: kleine Groessen verlieren mit dem Auto-Hinter die Serifen;
    # 10 pt aus Graustufen, ab 14 pt mit dem Hinting der Schrift
    raster(QUELLEN['TERMES'], 14, 'Dutch', 'AI', groessen=SATZ, dateiname=satzname, xskal=0.97,
           modus=lambda pt: 'auto' if pt < 10 else 'grau' if pt < 14 else 'nativ', bis=BIS,
           fett=lambda pt: 0.03 if pt == 14 else 0, fettvor=0, linear=True,
           emfak={7: 9, 10: 13, 14: 18, 18: 24, 20: 27, 28: 37, 36: 48, 48: 63})
    # Falsifikata (Plagiata war leider schon vergeben): Art-deco-Unicase nach dem Vorbild der Peignot - Kleinbuchstaben
    # als kleine Versalien, nur b d f h k l p y bleiben gemein, i j g wie bei der Peignot
    # Federstrich: senkrechte Striche kraeftig, waagrechte duenn (ab 14 pt);
    # die gemeinen Buchstaben leichter, damit sie zu den kleinen Versalien passen
    raster(QUELLEN['FEDERO'], 62, 'Falsifikata halbfett condensed', 'FH', xskal=0.80, fett=0.075,
           unicase='bdfhklijpyß', duenn=0.02, leicht=0.35)
