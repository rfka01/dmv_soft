; UHR.ACC - GEM-Zubehoer fuer die NCR DMV: Uhr und Monatskalender.
; Eigenes Programm (rfka01/Claude), MIT-Lizenz. NASM, ein Segment.
; Zeigt Wochentag, Datum (TT.MM.JJJJ) und Uhrzeit (24 h, jede Sekunde neu)
; und den Kalender des Monats; < und > blaettern, heute ist markiert.
STAPEL  equ 512
%include "gemacc.inc"

O_DATUM equ 2
O_ZEIT  equ 3
O_KAL   equ 4
O_ZEILE equ 6                           ; 6..11 Wochen
O_HEUTE equ 12
O_ZURUECK equ 13
O_MONAT equ 14
O_VOR   equ 15
O_OK    equ 16
N_OBJ   equ 17

vorbereiten:
        mov ax, 77                      ; graf_handle: Zeichengroesse
        mov bx, 0005h
        xor cx, cx
        call aesruf
        mov ax, [intout+2]
        mov [zb], ax
        mov ax, [intout+4]
        mov [zh], ax
        mov si, baum
        mov cx, N_OBJ
        jmp segs

haupt:  call datum_holen
        mov ax, [jahr]
        mov [kjahr], ax
        mov al, [monat]
        mov [kmonat], al
        call texte
        call kalender
        mov si, baum
        call dialog_auf
.l:     mov ax, 1000
        call ereignis
        test word [ev_was], 32          ; Zeit
        jz .k
        mov al, [tag]
        push ax
        call datum_holen
        call texte
        mov si, baum
        mov ax, O_ZEIT
        call zeichne_ab
        pop ax
        cmp al, [tag]                   ; neuer Tag: Datum und Markierung
        je .k
        mov ax, O_DATUM
        call zeichne_ab
        call kalender
        mov ax, O_KAL
        call zeichne_ab
.k:     test word [ev_was], 2       ; Knopf
        jz .t
        mov cx, [ev_x]
        mov dx, [ev_y]
        call finde
        cmp ax, O_OK
        je .ende_k
        cmp ax, O_ZURUECK
        je .zurueck
        cmp ax, O_VOR
        je .vor
        jmp .l
.t:     test word [ev_was], 1       ; Taste
        jz .l
        mov ax, [ev_taste]
        cmp al, 13                      ; Eingabe
        je .ende
        cmp al, 27                      ; Esc
        je .ende
        cmp al, '-'
        je .z2
        cmp al, '+'
        je .v2
        jmp .l
.zurueck:
        call knopf_druecken
.z2:    dec byte [kmonat]
        jnz .neu
        mov byte [kmonat], 12
        dec word [kjahr]
        jmp short .neu
.vor:   call knopf_druecken
.v2:    inc byte [kmonat]
        cmp byte [kmonat], 13
        jb .neu
        mov byte [kmonat], 1
        inc word [kjahr]
.neu:   call kalender
        mov si, baum
        mov ax, O_KAL
        call zeichne_ab
        mov ax, O_MONAT
        call zeichne_ab
        jmp .l
.ende_k:
        call knopf_druecken
.ende:  mov si, baum
        jmp dialog_zu

; datum_holen: DOS-Datum und -Zeit
datum_holen:
        mov ah, 2Ah
        int 21h
        mov [jahr], cx
        mov [monat], dh
        mov [tag], dl
        mov [wtag], al
        mov ah, 2Ch
        int 21h
        mov [std], ch
        mov [min], cl
        mov [sek], dh
        ret

; texte: Datumszeile "Donnerstag, 12.11.2026" und Zeit "14:05:32"
texte:  push es
        push cs
        pop es
        mov di, t_datum
        mov bl, [wtag]
        xor bh, bh
        shl bx, 1
        mov si, [wtage + bx]
.w:     lodsb
        or al, al
        jz .w2
        stosb
        jmp .w
.w2:    mov ax, ', '
        stosw
        mov al, [tag]
        call zahl2
        mov al, '.'
        stosb
        mov al, [monat]
        call zahl2
        mov al, '.'
        stosb
        mov ax, [jahr]
        mov bl, 100
        div bl                          ; AL Jahrhundert, AH Rest
        push ax
        call zahl2
        pop ax
        mov al, ah
        call zahl2
        xor al, al
        stosb
        mov di, t_zeit
        mov al, [std]
        call zahl2
        mov al, ':'
        stosb
        mov al, [min]
        call zahl2
        mov al, ':'
        stosb
        mov al, [sek]
        call zahl2
        pop es
        ret

; kalender: Wochenzeilen und Monatsname fuer kmonat/kjahr, Markierung heute
kalender:
        push es
        push cs
        pop es
        ; Monatsname
        mov di, t_monat
        mov bl, [kmonat]
        xor bh, bh
        dec bx
        shl bx, 1
        mov si, [monate + bx]
.mn:    lodsb
        or al, al
        jz .mn2
        stosb
        jmp .mn
.mn2:   mov al, ' '
        stosb
        mov ax, [kjahr]
        mov bl, 100
        div bl
        push ax
        call zahl2
        pop ax
        mov al, ah
        call zahl2
        xor al, al
        stosb
        ; Wochentag des Ersten (0 = Montag)
        mov ax, [kjahr]
        mov bl, [kmonat]
        mov bh, 1
        call wochentag
        mov [erster], al
        ; Tage im Monat
        mov bl, [kmonat]
        xor bh, bh
        mov al, [mtage + bx - 1]
        cmp bl, 2
        jne .tm
        mov dx, [kjahr]
        call schaltjahr
        jnc .tm
        inc al
.tm:    mov [tage], al
        ; Zeilen fuellen: 6 x 7 Felder zu 3 Zeichen
        mov di, t_wochen
        mov cx, 6 * 22
        mov al, ' '
        rep stosb
        mov di, t_wochen
        mov cx, 6
.z0:    mov byte [di + 21], 0
        add di, 22
        loop .z0
        xor dx, dx                      ; DL = Tag-1, Feld = erster + DL
.f:     cmp dl, [tage]
        jae .fe
        mov al, dl
        add al, [erster]
        xor ah, ah
        mov bl, 7
        div bl                          ; AL Zeile, AH Spalte
        mov bx, ax
        mov al, 22
        mul bl                          ; Zeile * 22
        mov di, ax
        mov al, bh
        mov ah, 3
        mul ah
        add di, ax
        add di, t_wochen + 1
        mov al, dl
        inc al
        aam
        add ax, 3030h
        cmp ah, '0'
        jne .zz
        mov ah, ' '
.zz:    xchg al, ah
        stosw
        inc dl
        jmp .f
.fe:    ; Markierung heute
        mov si, baum
        mov ax, O_HEUTE
        call obj
        or word [bx + 8], 80h           ; HIDETREE
        mov ax, [jahr]
        cmp ax, [kjahr]
        jne .ok
        mov al, [monat]
        cmp al, [kmonat]
        jne .ok
        and word [bx + 8], 0FF7Fh
        mov al, [tag]
        dec al
        add al, [erster]
        xor ah, ah
        mov cl, 7
        div cl                          ; AL Zeile, AH Spalte
        push ax
        mov al, ah
        mov ah, 3
        mul ah
        inc ax                          ; Spalte * 3 + 1
        mul word [zb]
        mov [bx + 16], ax
        pop ax
        xor ah, ah
        inc ax                          ; Kopfzeile
        mul word [zh]
        mov [bx + 18], ax
        mov al, [tag]
        mov di, t_heute
        call zahl2
.ok:    pop es
        ret

; wochentag: AX Jahr, BL Monat, BH Tag -> AL 0 = Montag ... 6 = Sonntag
; (Sakamoto: (y + y/4 - y/100 + y/400 + t[m-1] + d) mod 7, 0 = Sonntag)
wochentag:
        cmp bl, 3
        jae .a
        dec ax
.a:     mov si, ax                      ; y
        mov cx, ax
        shr cx, 1
        shr cx, 1                       ; y/4
        add si, cx
        xor dx, dx
        mov cx, 100
        div cx                          ; AX = y/100
        sub si, ax
        shr ax, 1
        shr ax, 1                       ; y/400
        add si, ax
        xor ax, ax
        mov al, bl
        mov di, ax
        mov al, [sak + di - 1]
        add si, ax
        mov al, bh
        add si, ax
        mov ax, si
        xor dx, dx
        mov cx, 7
        div cx                          ; DX = 0 Sonntag
        mov ax, dx
        add ax, 6
        xor dx, dx
        div cx
        mov ax, dx                      ; 0 Montag
        ret

; schaltjahr: DX Jahr -> CF gesetzt, wenn Schaltjahr
schaltjahr:
        push ax
        mov ax, dx
        test ax, 3
        jnz .nein
        push dx
        xor dx, dx
        mov cx, 100
        div cx
        or dx, dx
        pop dx
        jnz .ja
        mov ax, dx
        xor dx, dx
        mov cx, 400
        div cx
        or dx, dx
        jz .ja
.nein:  pop ax
        clc
        ret
.ja:    pop ax
        stc
        ret

; ---- Daten ----
titel:  db '  Uhr und Kalender', 0
zb:     dw 8
zh:     dw 16
jahr:   dw 0
monat:  db 0
tag:    db 0
wtag:   db 0
std:    db 0
min:    db 0
sek:    db 0
kjahr:  dw 0
kmonat: db 0
erster: db 0
tage:   db 0
sak:    db 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4
mtage:  db 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
wtage:  dw w0, w1, w2, w3, w4, w5, w6
w0:     db 'Sonntag', 0
w1:     db 'Montag', 0
w2:     db 'Dienstag', 0
w3:     db 'Mittwoch', 0
w4:     db 'Donnerstag', 0
w5:     db 'Freitag', 0
w6:     db 'Samstag', 0
monate: dw m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12
m1:     db 'Januar', 0
m2:     db 'Februar', 0
m3:     db 'M', 84h, 'rz', 0
m4:     db 'April', 0
m5:     db 'Mai', 0
m6:     db 'Juni', 0
m7:     db 'Juli', 0
m8:     db 'August', 0
m9:     db 'September', 0
m10:    db 'Oktober', 0
m11:    db 'November', 0
m12:    db 'Dezember', 0
leer:   db 0
s_titel: db ' Uhr und Kalender ', 0
s_kopf: db ' Mo Di Mi Do Fr Sa So', 0
s_zur:  db '<', 0
s_vor:  db '>', 0
s_ok:   db 'OK', 0
t_datum: times 32 db 0
t_zeit: db '00:00:00', 0
t_monat: times 20 db 0
t_heute: db '00', 0
t_wochen: times 6 * 22 db 0

ted_titel: TED s_titel, leer, leer, 3, 2, 1191h, -1, 19, 1
ted_datum: TED t_datum, leer, leer, 3, 2, 1180h, 0, 32, 1
ted_zeit:  TED t_zeit, leer, leer, 3, 2, 1180h, 0, 9, 1
ted_monat: TED t_monat, leer, leer, 3, 2, 1180h, 0, 20, 1
ted_heute: TED t_heute, leer, leer, 3, 2, 1170h, 0, 3, 1

baum:
OB NIL,  1, 16, 20, 3000h, 0, 114Bh, 3, 0, 0, 30, 18      ; 0 Kasten
OB   2, NIL, NIL, 22, 0, 0, ted_titel, 0, 1, 1, 28, 1     ; 1 Titel
OB   3, NIL, NIL, 21, 0, 0, ted_datum, 0, 1, 3, 28, 1     ; 2 Datum
OB   4, NIL, NIL, 21, 0, 0, ted_zeit, 0, 1, 4, 28, 1      ; 3 Zeit
OB  13,  5, 12, 20, 0, 0, 1170h, 0, 4, 6, 22, 7           ; 4 Kalender
OB   6, NIL, NIL, 28, 0, 0, s_kopf, 0, 0, 0, 21, 1        ; 5 Kopfzeile
OB   7, NIL, NIL, 28, 0, 0, t_wochen, 0, 0, 1, 21, 1      ; 6..11 Wochen
OB   8, NIL, NIL, 28, 0, 0, t_wochen + 22, 0, 0, 2, 21, 1
OB   9, NIL, NIL, 28, 0, 0, t_wochen + 44, 0, 0, 3, 21, 1
OB  10, NIL, NIL, 28, 0, 0, t_wochen + 66, 0, 0, 4, 21, 1
OB  11, NIL, NIL, 28, 0, 0, t_wochen + 88, 0, 0, 5, 21, 1
OB  12, NIL, NIL, 28, 0, 0, t_wochen + 110, 0, 0, 6, 21, 1
OB   4, NIL, NIL, 22, 80h, 1, ted_heute, 0, 0, 0, 2, 1    ; 12 heute (versteckt)
OB  14, NIL, NIL, 26, 5, 0, s_zur, 0, 3, 14, 3, 1         ; 13 <
OB  15, NIL, NIL, 21, 0, 0, ted_monat, 0, 7, 14, 16, 1    ; 14 Monat
OB  16, NIL, NIL, 26, 5, 0, s_vor, 0, 24, 14, 3, 1        ; 15 >
OB   0, NIL, NIL, 26, 27h, 0, s_ok, 0, 11, 16, 8, 1       ; 16 OK

ZUB_ENDE
