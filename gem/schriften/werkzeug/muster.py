"""muster.py - Schriftmuster wie ein Alphabetblatt: Versal schwarz, daneben
der Kleinbuchstabe rot und etwas tiefer, darunter die Ziffern.
python3 muster.py ausgabe.png SCHRIFT.VGA [Titel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from gemfnt import lies

f = lies(sys.argv[2])
fh = f['fh']
def zeichen(c):
    return f['zeichen'].get(c.encode('cp437')[0])
def setze(im, c, x, y, farbe):
    z = zeichen(c)
    if not z:
        return 0
    for r, row in enumerate(z):
        for X, b in enumerate(row):
            if b:
                im.putpixel((x + X, y + r), farbe)
    return len(z[0])
zeilen = ['ABCDEFG', 'HIJKLMN', 'OPQRSTU', 'VWXYZ']
B = 18 * fh; H = int(fh * 1.5) * 6 + fh
im = Image.new('RGB', (B, H), (248, 246, 240))
y = fh // 2
maxx = 0
for z in zeilen:
    x = fh // 2
    for c in z:
        x += setze(im, c, x, y, (30, 30, 30)) - fh // 12
        x += setze(im, c.lower(), x, y + fh // 4, (210, 50, 40)) + fh // 3
    maxx = max(maxx, x)
    y += int(fh * 1.5)
x = fh // 2
for c in '1234567890':
    x += setze(im, c, x, y, (30, 30, 30)) + fh // 8
im = im.crop((0, 0, max(maxx, x) + fh // 2, y + fh + fh // 4))
im.save(sys.argv[1])
