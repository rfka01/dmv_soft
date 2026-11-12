#!/usr/bin/env python3
# mkdata360.py - eine leere, formatierte 360-KB-Datendiskette fuer die DMV
# erzeugen (FAT12, KEIN DOS). Das BPB entspricht dem, was der DOS-3.3-Port
# (dmv_os, os/msdos33/src/bau/build_img.py) fuer 360 KB vorgibt:
#
#   bps=512 spc=2 rsvd=1 nfat=2 nroot=112 tot=720
#   Datensatzkennung (media descriptor) = 0xFD, FAT[0..2] = FD FF FF
#   spf=2 spt=9 heads=2 cyls=40   -> das IBM-kompatible 360-KB-Standardformat
#
# Der Bootsektor ist IBM-kompatibel: gueltiges BPB, 55AA-Signatur und eine
# kurze Meldung, falls jemand von der Datendiskette zu booten versucht. Die
# DMV selbst bootet ueber ihre Firmware, nicht ueber diesen Sektor; er dient
# nur dazu, dass die Diskette ueberall als gueltige Datendiskette gilt.
#
#   python3 mkdata360.py AUSGABE.IMG [DATENTRAEGERNAME]
import struct, sys

BPS, SPC, RSVD, NFAT, NROOT, TOT, MEDIA, SPF, SPT, HEADS, CYLS = \
    512, 2, 1, 2, 112, 720, 0xFD, 2, 9, 2, 40
OEM = b'DMVSOFT '                      # 8 Zeichen


def boot_sector():
    bs = bytearray(BPS)
    # EB 3C 90 = JMP SHORT 0x3E / NOP  (IBM-ueblicher Sprung ueber das BPB)
    bs[0:3] = b'\xEB\x3C\x90'
    bs[0x03:0x0B] = OEM
    # BPB ab 0x0B: bps, spc, rsvd, nfat, nroot, tot, media, spf, spt, heads, hidden
    struct.pack_into('<HBHBHHBHHHH', bs, 0x0B,
                     BPS, SPC, RSVD, NFAT, NROOT, TOT, MEDIA, SPF, SPT, HEADS, 0)
    # kleiner Stub ab 0x3E: Meldung ausgeben, Taste, Neustart (INT 19h)
    msg = b'Keine Systemdiskette - Datendiskette DMVCMD.\r\n'
    code = bytes([
        0xFA,                            # cli
        0x31, 0xC0,                      # xor ax,ax
        0x8E, 0xD8,                      # mov ds,ax
        0x8E, 0xD0,                      # mov ss,ax
        0xBC, 0x00, 0x7C,                # mov sp,0x7C00
        0xFB,                            # sti
        0xBE, 0x5E, 0x7C,                # mov si,0x7C5E  (msg-Adresse, s.u.)
    ])
    prnt = bytes([
        0xAC,                            # lodsb
        0x08, 0xC0,                      # or al,al
        0x74, 0x06,                      # jz +6 -> warten
        0xB4, 0x0E,                      # mov ah,0x0E
        0xCD, 0x10,                      # int 0x10
        0xEB, 0xF5,                      # jmp -11 (naechstes Zeichen)
        0x30, 0xE4,                      # xor ah,ah  (warten: Taste lesen)
        0xCD, 0x16,                      # int 0x16
        0xCD, 0x19,                      # int 0x19   (Neustart)
    ])
    bs[0x3E:0x3E + len(code)] = code
    off = 0x3E + len(code)
    bs[off:off + len(prnt)] = prnt
    # Meldung an feste Adresse 0x7C5E = Offset 0x5E im Sektor
    bs[0x5E:0x5E + len(msg)] = msg
    bs[510:512] = b'\x55\xAA'            # IBM-Signatur
    return bs


def build(outpath, label=''):
    raw = bytearray(TOT * BPS)
    raw[:BPS] = boot_sector()

    # zwei FATs anlegen, Startbytes FD FF FF
    fat = bytearray(SPF * BPS)
    fat[0], fat[1], fat[2] = MEDIA, 0xFF, 0xFF
    for n in range(NFAT):
        off = (RSVD + n * SPF) * BPS
        raw[off:off + len(fat)] = fat

    # optionaler Datentraegername als Wurzeleintrag (Attribut 0x08)
    if label:
        root_off = (RSVD + NFAT * SPF) * BPS
        name = label.upper().ljust(11)[:11].encode('latin-1')
        ent = bytearray(32)
        ent[0:11] = name
        ent[0x0B] = 0x08
        # festes Datum (4.5.1988), damit zwei Baeue gleich sind
        struct.pack_into('<HHHI', ent, 0x16, 0, ((1988 - 1980) << 9) | (5 << 5) | 4, 0, 0)
        raw[root_off:root_off + 32] = ent

    open(outpath, 'wb').write(raw)
    print(f"-> {outpath}  (360 KB, FAT12, media 0x{MEDIA:02X}, ohne DOS"
          + (f", Name {label!r}" if label else "") + ")")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit("Aufruf: python3 mkdata360.py AUSGABE.IMG [DATENTRAEGERNAME]")
    build(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else '')
