"""zeige.py - GEM-Schriftdateien (*.VGA) als PNG-Probe darstellen.
python3 zeige.py ausgabe.png datei1.VGA [datei2.VGA ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from gemfnt import lies

TEXT = 'Peignot Design Grafik: ÄÖÜäöü gigantisch Fenster 0123'

def zeile(p):
    f = lies(p)
    x = 0; px = []
    for ch in ('%s %d: ' % (f['name'][:12], f['pt'])) + TEXT:
        z = f['zeichen'].get(ch.encode('cp437', 'replace')[0])
        if not z:
            continue
        for r, row in enumerate(z):
            for X, b in enumerate(row):
                if b:
                    px.append((x + X, r))
        x += len(z[0])
    im = Image.new('L', (max(x, 1), f['fh']), 255)
    for q in px:
        im.putpixel(q, 0)
    return im

ims = [zeile(p) for p in sys.argv[2:]]
W = max(i.width for i in ims); H = sum(i.height + 4 for i in ims)
o = Image.new('L', (W, H), 255); y = 0
for i in ims:
    o.paste(i, (0, y)); y += i.height + 4
o.resize((W * 2, H * 2), Image.NEAREST).save(sys.argv[1])
