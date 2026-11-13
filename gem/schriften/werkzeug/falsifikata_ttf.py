#!/usr/bin/env python3
"""falsifikata_ttf.py [FEDERO.TTF] [ZIEL.TTF]

Baut "Falsifikata halbfett condensed" als TrueType-Umrissschrift: dieselbe
Abwandlung von Federo (Cyreal, SIL OFL 1.1), die bau_schriften.py fuer die
GEM-Bildschirmschrift (Id 62) rastert, hier im Umriss:

- alles auf 80 % Breite (condensed)
- Senkrechte kraeftiger (waagrecht 0,075 em dazu), Waagerechte um 0,02 em
  duenner - Kontrast wie bei einer Breitfeder (nicht bei den Schraegen
  A K M N V W X Y Z, die reissen sonst ab, und nicht beim f)
- Unicase wie die Peignot: Kleinbuchstaben sind kleine Versalien auf
  x-Hoehe; gemein bleiben nur b d f h k l p y ss (leichter verstaerkt)
- i und j: Stamm der kleinen Versalie I, Punkt in Stammbreite mit
  deutlichem Abstand, j mit Unterlaenge
- g: kleines C mit Stamm ab halber Hoehe bis in die Unterlaenge und
  kurzem Querstrich (sonst liest es sich als q bzw. Q)

Der Name: eigentlich sollte sie "Plagiata" heissen - der war leider schon
vergeben (Bernd Flickinger, 2016). "Federo" ist ein Reserved Font Name der
Vorlage und darf fuer die Abwandlung nicht verwendet werden.

Benoetigt fontTools und skia-pathops. MIT (dieses Werkzeug); die erzeugte
Schrift steht wie die Vorlage unter der SIL OFL 1.1.
"""
import sys
import pathops
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib.tables import ttProgram

import os
HIER = os.path.dirname(os.path.abspath(__file__))
QUELLE = sys.argv[1] if len(sys.argv) > 1 else \
    os.path.join(HIER, '..', 'quellen', 'federo', 'Federo-Regular.ttf')
ZIEL = sys.argv[2] if len(sys.argv) > 2 else \
    os.path.join(HIER, '..', 'ttf', 'FalsifikataHalbfettCondensed.ttf')

XSKAL = 0.80
FETT = 0.075            # em, waagrecht dazu (wie bau_schriften.py)
DUENN = 0.02            # em, Waagerechte duenner
LEICHT = 0.35           # Anteil fuer die gemeinen Buchstaben
GEMEIN = 'bdfhklpyß'    # bleiben gemein (dazu i j g als eigene Formen)
SCHRAEG = set('AÄKMNVWXYZ')
UMLAUT = {'ä': 'Ä', 'ö': 'Ö', 'ü': 'Ü'}

f = TTFont(QUELLE, recalcTimestamp=False)   # reproduzierbar: Zeitstempel der Vorlage
UPM = f['head'].unitsPerEm
gs = f.getGlyphSet()
cmap = f.getBestCmap()
hmtx = f['hmtx']
glyf = f['glyf']
name_of = {chr(u): n for u, n in cmap.items()}

def hoehe(ch):
    bp = BoundsPen(gs)
    gs[name_of[ch]].draw(bp)
    return bp.bounds[3]

XH, KH = hoehe('x'), hoehe('H')
KLEIN = XH / KH
ST = FETT * UPM
DU = DUENN * UPM


def pfad(gname, matrix):
    p = pathops.Path()
    pen = pathops.PathPen(p, glyphSet=gs)
    gs[gname].draw(TransformPen(pen, matrix))
    return p


def verschoben(p, dx, dy):
    q = pathops.Path()
    p.draw(TransformPen(pathops.PathPen(q), (1, 0, 0, 1, dx, dy)))
    return q


def vereinige(pfade):
    return pathops.op_union(pfade) if False else _union(pfade)


def _union(pfade):
    b = pathops.OpBuilder(fix_winding=True, keep_starting_points=False)
    for p in pfade:
        b.add(p, pathops.PathOp.UNION)
    return b.resolve()


def fett(p, sx, dy):
    """Waagrecht um sx verbreitern (Spur einer waagrechten Strecke, in
    feinen Schritten), senkrecht um dy verduennen (Schnitt zweier
    verschobener Kopien) - wie FT_Outline_EmboldenXY(sx, -dy)."""
    if sx > 0:
        n = max(2, int(sx / 4))
        p = _union([verschoben(p, sx * k / n, 0) for k in range(n + 1)])
    if dy > 0:
        p = pathops.op(verschoben(p, 0, dy / 2), verschoben(p, 0, -dy / 2),
                       pathops.PathOp.INTERSECTION, fix_winding=True)
    return p


def rechteck(x0, y0, x1, y1):
    p = pathops.Path()
    p.moveTo(x0, y0); p.lineTo(x0, y1); p.lineTo(x1, y1); p.lineTo(x1, y0); p.close()
    return p


def grenzen(p):
    bp = BoundsPen(None)
    p.draw(bp)
    return bp.bounds


def glyph_aus(p):
    tp = TTGlyphPen(None)
    p.draw(Cu2QuPen(tp, max_err=1.0, reverse_direction=False))
    return tp.glyph()


VERS = (XSKAL, 0, 0, 1, 0, 0)
KV = (XSKAL * KLEIN * 1.12, 0, 0, KLEIN, 0, 0)

neu = {}
for u, gname in sorted(cmap.items()):
    ch = chr(u)
    if glyf[gname].numberOfContours == 0 and not glyf[gname].isComposite():
        neu[gname] = (None, hmtx[gname][0] * XSKAL)
        continue
    matrix, quelle, sx, dy = VERS, gname, ST, DU
    breite = hmtx[gname][0] * XSKAL
    klein = False
    if ch in 'ij':
        quelle, matrix, klein = name_of['I'], KV, True
    elif ch == 'g':
        quelle, matrix, klein = name_of['C'], KV, True
    elif ch in UMLAUT:
        quelle, matrix, klein = name_of[UMLAUT[ch]], KV, True
    elif ch.islower() and ch not in GEMEIN and len(ch.upper()) == 1 \
            and ch.upper() in name_of:
        quelle, matrix, klein = name_of[ch.upper()], KV, True
    elif ch in GEMEIN:
        sx = ST * LEICHT
    if klein:
        breite = hmtx[quelle][0] * matrix[0]
    if ch.upper() in SCHRAEG or ch in 'fß':
        dy = 0
    qg = glyf[quelle]
    if qg.isComposite() and len(qg.components) > 1:
        # Grundbuchstabe verstaerkt, Akzente/Punkte kaum (sonst
        # verschmelzen die Umlautpunkte zu einem Balken)
        teile = []
        for k, comp in enumerate(qg.components):
            a, b, c, d, e, f_ = matrix
            m = (a, 0, 0, d, a * comp.x, d * comp.y)
            teile.append(fett(pfad(comp.glyphName, m), sx if k == 0 else ST * 0.15,
                              dy if k == 0 else 0) if k == 0 else
                         verschoben(fett(pfad(comp.glyphName, m), ST * 0.15, 0), sx / 2, 0))
        p = _union(teile)
    else:
        p = fett(pfad(quelle, matrix), sx, dy)
    if ch in 'ijg':
        # Stammbreite aus dem verstaerkten kleinen I
        x0, _, x1, oben = grenzen(fett(pfad(name_of['I'], KV), sx, dy))
        sw = x1 - x0
        tief = 0.22 * UPM
        abst = 0.22 * UPM
        if ch in 'ij':
            teile = [p, rechteck(x0, oben + abst, x1, oben + abst + sw)]
            if ch == 'j':
                teile.append(rechteck(x0, -tief, x1, 1))
            p = _union(teile)
        else:
            cx0, _, cx1, coben = grenzen(p)
            mitte = coben * 0.55
            dq = UPM / 22
            p = _union([p, rechteck(cx1 - sw, -tief, cx1, mitte),
                        rechteck(cx1 - sw - sw / 2, mitte - dq, cx1 - sw + 1, mitte)])
    # Verstaerkung nach rechts: Vorschub waechst um sx
    neu[gname] = (glyph_aus(p), breite + sx)

for gname, (g, w) in neu.items():
    if g is not None:
        g.program = ttProgram.Program(); g.program.fromBytecode(b'')
        glyf[gname] = g
        g.recalcBounds(glyf)
        lsb = g.xMin if g.numberOfContours else 0
    else:
        lsb = 0
    hmtx[gname] = (int(round(w)), int(lsb))
# nicht abgebildete Glyphen (notdef u. a.) nur schmaler
for gname in f.getGlyphOrder():
    if gname not in neu:
        w, l = hmtx[gname]
        hmtx[gname] = (int(round(w * XSKAL)), int(round(l * XSKAL)))

# Hinting, Kerning und Positionen der Vorlage passen nicht mehr
for t in ('fpgm', 'prep', 'cvt ', 'LTSH', 'VDMX', 'hdmx', 'kern', 'GPOS'):
    if t in f:
        del f[t]
for gname in f.getGlyphOrder():
    g = glyf[gname]
    if hasattr(g, 'program'):
        g.program = ttProgram.Program(); g.program.fromBytecode(b'')
f['head'].flags &= ~(1 << 4)            # keine Abhaengigkeit von ppem mehr
f['maxp'].maxSizeOfInstructions = 0
f['gasp'].gaspRange = {0xFFFF: 0x000A}  # Glaetten, kein Hinting
br = [hmtx[n][0] for n in f.getGlyphOrder() if hmtx[n][0] > 0]
f['OS/2'].xAvgCharWidth = int(sum(br) / len(br))
f['OS/2'].usWeightClass = 600
f['OS/2'].usWidthClass = 3
f['OS/2'].achVendID = 'NONE'

FAM = 'Falsifikata Halbfett Condensed'
nm = f['name']
nm.names = [n for n in nm.names if n.nameID in (0, 13, 14)]
texte = {
    0: 'Copyright (c) 2011, Olexa M. Volochay (Cyreal), with Reserved Font Name '
       '"Federo". Abwandlung "Falsifikata" (c) 2026 rfka01 und Claude.',
    1: FAM,
    2: 'Regular',
    3: 'Falsifikata-HalbfettCondensed;1.000',
    4: 'Falsifikata halbfett condensed',
    5: 'Version 1.000',
    6: 'Falsifikata-HalbfettCondensed',
    8: 'rfka01 / Claude (Abwandlung), Cyreal (Federo)',
    10: 'Art-deco-Groteske im Stil der Peignot fuer GEM auf der NCR Decision '
        'Mate V: abgewandelt aus Federo (Cyreal), 80 % breit, Unicase, '
        'Kontrast wie mit der Breitfeder. Eigentlich sollte sie Plagiata '
        'heissen - der Name war leider schon vergeben.',
    16: 'Falsifikata',
    17: 'Halbfett Condensed',
}
for i, s in texte.items():
    nm.setName(s, i, 3, 1, 0x409)
    nm.setName(s, i, 1, 0, 0)
f['post'].formatType = 2.0
f.save(ZIEL)
print(ZIEL, 'gespeichert,', len(neu), 'Zeichen')
