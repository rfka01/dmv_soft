; NOTIZ.ACC - GEM-Zubehoer fuer die NCR DMV: kleiner Notizblock.
; Eigenes Programm (rfka01/Claude), MIT-Lizenz. NASM, ein Segment.
; 12 Zeilen zu 40 Zeichen, gespeichert als Text in NOTIZ.TXT im Verzeichnis,
; aus dem GEM gestartet wurde (C:\GEMAPPS\GEMSYS). Pfeiltasten wechseln die
; Zeile, Eingabe sichert, Esc bricht ab.
STAPEL  equ 768
%include "gemacc.inc"

ZEILEN  equ 12
BREITE  equ 40
O_ERSTE equ 2
O_SICHERN equ O_ERSTE + ZEILEN
O_ABBRUCH equ O_SICHERN + 1
N_OBJ   equ O_ABBRUCH + 1

vorbereiten:
        ; Pfad: aktuelles Laufwerk und Verzeichnis + \NOTIZ.TXT
        mov ah, 19h
        int 21h
        add al, 'A'
        mov di, pfad
        stosb
        mov ax, ':\'
        stosw
        mov si, di
        xor dl, dl
        mov ah, 47h
        int 21h
.e:     lodsb
        or al, al
        jnz .e
        lea di, [si - 1]
        cmp byte [di - 1], '\'
        je .n
        mov al, '\'
        stosb
.n:     mov si, s_datei
.k:     lodsb
        stosb
        or al, al
        jnz .k
        ; TEDINFO der Zeilen anlegen
        mov di, teds
        mov bx, zeilen
        mov cx, ZEILEN
.t:     mov [di], bx                    ; te_ptext
        mov word [di + 4], vorlage
        mov word [di + 8], gueltig
        mov word [di + 12], 3           ; Schrift
        mov word [di + 16], 0           ; links
        mov word [di + 18], 1180h       ; Farbe
        mov word [di + 22], 0
        mov word [di + 24], BREITE + 1
        mov word [di + 26], BREITE + 1
        add di, 28
        add bx, BREITE + 1
        loop .t
        mov si, baum
        mov cx, N_OBJ
        jmp segs

haupt:  call laden
        mov si, baum
        call dialog_auf
        mov word [intin], O_ERSTE       ; form_do(baum, erstes Feld)
        mov [addrin], si
        mov [addrin+2], cs
        mov ax, 50
        mov bx, 0101h
        mov cx, 0100h
        call aesruf
        and ax, 7FFFh
        push ax
        call obj
        and word [bx + 10], 0FFFEh      ; Knopf wieder abwaehlen
        call dialog_zu
        pop ax
        cmp ax, O_SICHERN
        jne .r
        call sichern
.r:     ret

; laden: NOTIZ.TXT in die Zeilen (fehlt sie, bleiben die Zeilen leer)
laden:  mov di, zeilen
        mov cx, ZEILEN * (BREITE + 1)
        xor al, al
        rep stosb
        mov dx, pfad
        mov ax, 3D00h
        int 21h
        jc .r
        mov bx, ax
        mov dx, puf
        mov cx, PUFLEN
        mov ah, 3Fh
        int 21h
        jc .zu
        mov cx, ax                      ; gelesene Bytes
        mov si, puf
        mov di, zeilen
        xor dx, dx                      ; DL Zeile, DH Spalte
.z:     jcxz .zu
        lodsb
        dec cx
        cmp al, 1Ah
        je .zu
        cmp al, 13
        je .z
        cmp al, 10
        je .nl
        cmp al, 9
        jne .c
        mov al, ' '
.c:     cmp al, ' '
        jb .z
        cmp dh, BREITE
        jae .z
        stosb
        inc dh
        jmp .z
.nl:    inc dl
        cmp dl, ZEILEN
        jae .zu
        xor dh, dh
        mov al, BREITE + 1
        mul dl
        add ax, zeilen
        mov di, ax
        jmp .z
.zu:    mov ah, 3Eh
        int 21h
.r:     ret

; sichern: Zeilen ohne Leerzeichen am Ende, leere Zeilen am Schluss weg
sichern:
        ; letzte nicht leere Zeile
        mov bp, ZEILEN
.l:     or bp, bp
        jz .s
        mov ax, bp
        dec ax
        mov dl, BREITE + 1
        mul dl
        mov si, ax
        add si, zeilen
        call laenge
        or cx, cx
        jnz .s
        dec bp
        jmp .l
.s:     mov dx, pfad
        xor cx, cx
        mov ah, 3Ch
        int 21h
        jc .fehler
        mov bx, ax
        mov si, zeilen
.w:     or bp, bp
        jz .zu
        push si
        call laenge
        mov dx, si
        mov ah, 40h
        int 21h
        mov dx, crlf
        mov cx, 2
        mov ah, 40h
        int 21h
        pop si
        add si, BREITE + 1
        dec bp
        jmp .w
.zu:    mov ah, 3Eh
        int 21h
        ret
.fehler:
        mov word [intin], 1             ; form_alert
        mov word [addrin], s_fehler
        mov [addrin+2], cs
        mov ax, 52
        mov bx, 0101h
        mov cx, 0100h
        jmp aesruf

; laenge: Zeile SI -> CX Zeichen ohne Leerzeichen am Ende
laenge: push bx
        xor cx, cx
        xor bx, bx
.l:     mov al, [si + bx]
        or al, al
        jz .r
        inc bx
        cmp al, ' '
        je .l
        mov cx, bx
        jmp .l
.r:     pop bx
        ret

; ---- Daten ----
titel:  db '  Notizblock', 0
s_datei: db 'NOTIZ.TXT', 0
s_fehler: db '[3][NOTIZ.TXT l', 84h, 'sst sich|nicht schreiben.][ OK ]', 0
crlf:   db 13, 10
leer:   db 0
s_titel: db ' Notizblock ', 0
s_sichern: db 'Sichern', 0
s_abbruch: db 'Abbruch', 0
vorlage: times BREITE db '_'
        db 0
gueltig: times BREITE db 'X'
        db 0
ted_titel: TED s_titel, leer, leer, 3, 2, 1191h, -1, 13, 1
pfad:   times 80 db 0
teds:   times ZEILEN * 28 db 0
zeilen: times ZEILEN * (BREITE + 1) db 0

baum:
OB NIL,  1, O_ABBRUCH, 20, 3000h, 0, 114Bh, 3, 0, 0, 44, ZEILEN + 6
OB   2, NIL, NIL, 22, 0, 0, ted_titel, 0, 1, 1, 42, 1
%assign i 0
%rep ZEILEN
OB O_ERSTE + i + 1, NIL, NIL, 29, 8, 0, teds + i * 28, 0, 2, 3 + i, BREITE, 1
%assign i i + 1
%endrep
OB O_ABBRUCH, NIL, NIL, 26, 7, 0, s_sichern, 0, 22, ZEILEN + 4, 9, 1
OB 0, NIL, NIL, 26, 225h, 0, s_abbruch, 0, 33, ZEILEN + 4, 9, 1

PUFLEN  equ ZEILEN * (BREITE + 2) + 64
puf:    times PUFLEN db 0

ZUB_ENDE
