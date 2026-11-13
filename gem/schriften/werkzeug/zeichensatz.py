"""GEM-Zeichensatz (PC-GEM/3 = Ventura International) als Unicode-Tabelle."""
GEM = {}
for c in range(32, 127):
    GEM[c] = chr(c)
_zeilen = {
    0x80: 'ÇüéâäàåçêëèïîìÄÅ',
    0x90: 'ÉæÆôöòûùÿÖÜø£Ø¤ƒ',
    0xA0: 'áíóúñÑªº¿“”‹›¡«»',
    0xB0: 'ãõ¥¢œŒÀÃÕ§‡†¶©®™',
    0xC0: '„…‰•–—°ÁÂÈÊËÌÍÎÏ',
    0xD0: 'ÒÓÔŠšÙÚÛŸß',
}
for basis, s in _zeilen.items():
    for i, ch in enumerate(s):
        GEM[basis + i] = ch
GEM[0xE1] = 'ß'
ERSTES, LETZTES = 32, 0xE1
