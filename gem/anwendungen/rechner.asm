; RECHNER.ACC - GEM-Zubehoer fuer die NCR DMV: Taschenrechner.
; Eigenes Programm (rfka01/Claude), MIT-Lizenz. NASM, ein Segment.
; Grundrechenarten mit 4 Nachkommastellen (64-Bit-Festkomma, Wert * 10000,
; bis etwa 900 Billionen), Vorzeichen, Korrektur; Bedienung mit Maus oder
; Tastatur (Ziffern , . + - * / = Eingabe, Rueckschritt, C, Esc schliesst).
STAPEL  equ 512
%include "gemacc.inc"

O_ANZ   equ 2
N_OBJ   equ 23

vorbereiten:
        mov si, baum
        mov cx, N_OBJ
        jmp segs

haupt:  call anzeigen
        mov si, baum
        call dialog_auf
.l:     mov ax, 60000
        call ereignis
        test word [ev_was], 2
        jz .t
        mov cx, [ev_x]
        mov dx, [ev_y]
        mov si, baum
        call finde
        cmp ax, N_OBJ
        jae .l
        mov bx, ax
        mov bl, [aktion + bx]
        or bl, bl
        jz .l
        push bx
        call knopf_druecken
        pop bx
        mov al, bl
        jmp short .tu
.t:     test word [ev_was], 1
        jz .l
        mov ax, [ev_taste]
        cmp al, 27
        je .zu
        cmp al, 13
        jne .t1
        mov al, '='
.t1:    cmp al, '.'
        jne .t2
        mov al, ','
.t2:    cmp al, 'c'
        jne .t3
        mov al, 'C'
.t3:    cmp al, 7Fh
        jne .tu
        mov al, 'C'
.tu:    cmp al, 'X'
        je .zu
        call taste
        call anzeigen
        mov si, baum
        mov ax, O_ANZ
        call zeichne_ab
        jmp .l
.zu:    mov si, baum
        jmp dialog_zu

;---------------------------------------------------------------------
; taste: AL = Ziffer, ',', + - * /, =, C, S (Vorzeichen), 8 (Rueckschritt)
;---------------------------------------------------------------------
taste:  cmp byte [fehler], 0
        je .a
        cmp al, 'C'
        jne .r
.a:     cmp al, '0'
        jb .k1
        cmp al, '9'
        jbe .ziffer
.k1:    cmp al, ','
        je .komma
        cmp al, 'C'
        je .loesch
        cmp al, 'S'
        je .vz
        cmp al, 8
        je .zurueck
        cmp al, '='
        je .gleich
        cmp al, '+'
        je .op
        cmp al, '-'
        je .op
        cmp al, '*'
        je .op
        cmp al, '/'
        je .op
.r:     ret
.ziffer:
        call eingabe_beginn
        cmp byte [e_ziff], 15
        jae .r
        inc byte [e_ziff]
        jmp short .anhaengen
.komma: call eingabe_beginn
        cmp byte [e_komma], 0
        jne .r
        mov byte [e_komma], 1
        cmp byte [e_ziff], 0
        jne .anhaengen
        push ax
        mov al, '0'
        call .anhaengen
        inc byte [e_ziff]
        pop ax
.anhaengen:
        mov bx, [e_len]
        mov [e_text + bx], al
        inc bx
        mov byte [e_text + bx], 0
        mov [e_len], bx
        ret
.zurueck:
        cmp byte [eingabe], 0
        je .r
        mov bx, [e_len]
        or bx, bx
        jz .r
        dec bx
        mov al, [e_text + bx]
        mov byte [e_text + bx], 0
        mov [e_len], bx
        cmp al, ','
        jne .zz
        mov byte [e_komma], 0
        ret
.zz:    cmp al, '-'
        jne .zd
        mov byte [e_neg], 0
        ret
.zd:    dec byte [e_ziff]
        ret
.vz:    cmp byte [eingabe], 0
        jne .vze
        mov si, akku
        jmp neg64
.vze:   xor byte [e_neg], 1
        ret
.loesch:
        mov di, akku
        call null64
        mov byte [op], 0
        mov byte [eingabe], 0
        mov byte [fehler], 0
        ret
.op:    push ax
        call rechnen
        pop ax
        mov [op], al
        ret
.gleich:
        call rechnen
        mov byte [op], 0
        ret

eingabe_beginn:
        cmp byte [eingabe], 0
        jne .r
        mov byte [eingabe], 1
        mov word [e_len], 0
        mov byte [e_text], 0
        mov byte [e_ziff], 0
        mov byte [e_komma], 0
        mov byte [e_neg], 0
.r:     ret

; rechnen: laufende Eingabe mit dem offenen Operator in den Akku
rechnen:
        cmp byte [eingabe], 0
        je .r
        mov byte [eingabe], 0
        call eingabe_wert               ; -> wert
        mov al, [op]
        or al, al
        jnz .op
        mov si, wert
        mov di, akku
        jmp kopie64
.op:    cmp al, '+'
        je .plus
        cmp al, '-'
        je .minus
        cmp al, '*'
        je .mal
        jmp teilen
.plus:  mov si, wert
        mov di, akku
        call add64
        jo fehler_setzen
        ret
.minus: mov si, wert
        call neg64
        mov di, akku
        call add64
        jo fehler_setzen
.r:     ret
.mal:   jmp malnehmen

fehler_setzen:
        mov byte [fehler], 1
        ret

; eingabe_wert: e_text -> wert (* 10000)
eingabe_wert:
        mov di, wert
        call null64
        mov si, e_text
        xor cx, cx                      ; CL Nachkommastellen, CH Komma gesehen
.z:     lodsb
        or al, al
        jz .e
        cmp al, ','
        jne .d
        mov ch, 1
        jmp .z
.d:     or ch, ch
        jz .d1
        cmp cl, 4
        jae .z
        inc cl
.d1:    sub al, '0'
        push cx
        push si
        push ax
        mov bx, 10
        call mal_wort                   ; wert *= 10
        pop ax
        mov si, wert
        xor ah, ah
        add [si], ax
        adc word [si+2], 0
        adc word [si+4], 0
        adc word [si+6], 0
        pop si
        pop cx
        jmp .z
.e:     ; auf 4 Nachkommastellen bringen
.s:     cmp cl, 4
        jae .v
        push cx
        mov bx, 10
        call mal_wort
        pop cx
        inc cl
        jmp .s
.v:     cmp byte [e_neg], 0
        je .r
        mov si, wert
        call neg64
.r:     ret

; mal_wort: wert *= BX (16 Bit, ohne Ueberlaufpruefung, Eingabe ist begrenzt)
mal_wort:
        mov si, wert
        xor cx, cx                      ; Uebertrag
        mov di, 4
.w:     mov ax, [si]
        mul bx
        add ax, cx
        adc dx, 0
        mov [si], ax
        mov cx, dx
        add si, 2
        dec di
        jnz .w
        ret

;---------------------------------------------------------------------
; 64-Bit-Hilfen (SI, DI zeigen auf 4 Woerter)
;---------------------------------------------------------------------
null64: xor ax, ax
        mov [di], ax
        mov [di+2], ax
        mov [di+4], ax
        mov [di+6], ax
        ret
kopie64:
        push cx
        mov cx, 4
.k:     mov ax, [si]
        mov [di], ax
        add si, 2
        add di, 2
        loop .k
        pop cx
        ret
neg64:  not word [si]
        not word [si+2]
        not word [si+4]
        not word [si+6]
        add word [si], 1
        adc word [si+2], 0
        adc word [si+4], 0
        adc word [si+6], 0
        ret
add64:  mov ax, [si]
        add [di], ax
        mov ax, [si+2]
        adc [di+2], ax
        mov ax, [si+4]
        adc [di+4], ax
        mov ax, [si+6]
        adc [di+6], ax                  ; OF = Ueberlauf
        ret
; betrag: [SI] positiv machen, AL ^= 1 wenn es negativ war
betrag: test byte [si+7], 80h
        jz .r
        xor al, 1
        push ax
        call neg64
        pop ax
.r:     ret

; malnehmen: akku = akku * wert / 10000
malnehmen:
        xor al, al
        mov si, akku
        call betrag
        mov si, wert
        call betrag
        mov [vorz], al
        ; p (8 Woerter) = akku * wert
        mov di, p
        mov cx, 8
        xor ax, ax
        rep stosw                       ; ES = CS
        xor bx, bx                      ; i * 2
.i:     xor di, di                      ; j * 2
.j:     mov ax, [akku + bx]
        mul word [wert + di]
        push bx
        add bx, di
        add [p + bx], ax
        adc [p + bx + 2], dx
        jnc .ok
.c:     add bx, 4                       ; Uebertrag weiterreichen
        cmp bx, 16
        jae .ok
        add word [p + bx], 1
        jnc .ok
        sub bx, 2
        jmp .c
.ok:    pop bx
        add di, 2
        cmp di, 8
        jb .j
        add bx, 2
        cmp bx, 8
        jb .i
        ; / 10000, von oben nach unten
        mov bx, 14
        xor dx, dx
        mov cx, 10000
.d:     mov ax, [p + bx]
        div cx
        mov [p + bx], ax
        sub bx, 2
        jns .d
        jmp ergebnis

; teilen: akku = akku * 10000 / wert
teilen: mov si, wert
        mov ax, [si]
        or ax, [si+2]
        or ax, [si+4]
        or ax, [si+6]
        jz fehler_setzen
        xor al, al
        mov si, akku
        call betrag
        mov si, wert
        call betrag
        mov [vorz], al
        ; p = akku * 10000 (128 Bit)
        mov di, p
        mov cx, 8
        xor ax, ax
        rep stosw
        xor bx, bx
        xor cx, cx
.m:     mov ax, [akku + bx]
        mov si, 10000
        mul si
        add ax, cx
        adc dx, 0
        mov [p + bx], ax
        mov cx, dx
        add bx, 2
        cmp bx, 8
        jb .m
        mov [p + 8], cx
        ; Langdivision: Rest r (64 Bit), 128 Schritte
        mov di, r
        call null64
        mov cx, 128
.s:     shl word [p], 1                 ; p:r um 1 nach links
        rcl word [p+2], 1
        rcl word [p+4], 1
        rcl word [p+6], 1
        rcl word [p+8], 1
        rcl word [p+10], 1
        rcl word [p+12], 1
        rcl word [p+14], 1
        rcl word [r], 1
        rcl word [r+2], 1
        rcl word [r+4], 1
        rcl word [r+6], 1
        ; r >= wert?
        mov ax, [r+6]
        cmp ax, [wert+6]
        jne .v
        mov ax, [r+4]
        cmp ax, [wert+4]
        jne .v
        mov ax, [r+2]
        cmp ax, [wert+2]
        jne .v
        mov ax, [r]
        cmp ax, [wert]
.v:     jb .n
        mov ax, [wert]
        sub [r], ax
        mov ax, [wert+2]
        sbb [r+2], ax
        mov ax, [wert+4]
        sbb [r+4], ax
        mov ax, [wert+6]
        sbb [r+6], ax
        or word [p], 1                  ; Quotientenbit
.n:     loop .s

; ergebnis: p (128 Bit, Betrag) -> akku mit Vorzeichen vorz, sonst Fehler
ergebnis:
        mov ax, [p+8]
        or ax, [p+10]
        or ax, [p+12]
        or ax, [p+14]
        jnz fehler_setzen
        test byte [p+7], 80h
        jnz fehler_setzen
        mov si, p
        mov di, akku
        call kopie64
        cmp byte [vorz], 0
        je .r
        mov si, akku
        call neg64
.r:     ret

;---------------------------------------------------------------------
; anzeigen: Text der Anzeige: Fehler, laufende Eingabe oder Akku
;---------------------------------------------------------------------
anzeigen:
        push es
        push cs
        pop es
        mov di, t_anz
        cmp byte [fehler], 0
        je .a
        mov si, s_fehler
.k:     lodsb
        stosb
        or al, al
        jnz .k
        jmp .ende
.a:     cmp byte [eingabe], 0
        je .wert
        cmp byte [e_neg], 0
        je .e1
        mov al, '-'
        stosb
.e1:    mov si, e_text
        cmp byte [si], 0
        jne .k
        mov ax, '0'
        stosw
        jmp .ende
.wert:  ; akku -> Ziffern rueckwaerts in z_puf
        mov si, akku
        mov di, wert
        call kopie64
        xor al, al
        mov si, wert
        call betrag
        mov [vorz], al
        mov bx, z_puf + 24
        mov byte [bx], 0
        xor cx, cx                      ; Ziffern
.z:     ; wert /= 10, Rest -> Ziffer
        push bx
        mov bx, 6
        xor dx, dx
        mov si, 10
.zd:    mov ax, [wert + bx]
        div si
        mov [wert + bx], ax
        sub bx, 2
        jns .zd
        pop bx
        add dl, '0'
        dec bx
        mov [bx], dl
        inc cx
        cmp cx, 4
        jne .z1
        dec bx
        mov byte [bx], ','
.z1:    mov ax, [wert]
        or ax, [wert+2]
        or ax, [wert+4]
        or ax, [wert+6]
        jnz .z
        cmp cx, 5                       ; wenigstens "0,xxxx"
        jb .z
        ; Nachkommanullen entfernen
        mov si, z_puf + 23
.n:     cmp byte [si], '0'
        jne .n2
        mov byte [si], 0
        dec si
        jmp .n
.n2:    cmp byte [si], ','
        jne .n3
        mov byte [si], 0
.n3:    cmp byte [vorz], 0
        je .n4
        dec bx
        mov byte [bx], '-'
.n4:    mov si, bx
        mov di, t_anz
        jmp .k
.ende:  pop es
        ret

; ---- Daten ----
titel:  db '  Rechner', 0
akku:   dq 0
wert:   dq 0
r:      dq 0
p:      times 8 dw 0
vorz:   db 0
op:     db 0
eingabe: db 0
fehler: db 0
e_ziff: db 0
e_komma: db 0
e_neg:  db 0
e_len:  dw 0
e_text: times 20 db 0
z_puf:  times 26 db 0
leer:   db 0
s_fehler: db 'Fehler', 0
s_titel: db ' Rechner ', 0
t_anz:  times 24 db 0
s_c:    db 'C', 0
s_vz:   db 0F1h, 0                      ; plus/minus
s_rk:   db '<-', 0
s_dv:   db '/', 0
s_ml:   db '*', 0
s_mi:   db '-', 0
s_pl:   db '+', 0
s_gl:   db '=', 0
s_km:   db ',', 0
s_0:    db '0', 0
s_1:    db '1', 0
s_2:    db '2', 0
s_3:    db '3', 0
s_4:    db '4', 0
s_5:    db '5', 0
s_6:    db '6', 0
s_7:    db '7', 0
s_8:    db '8', 0
s_9:    db '9', 0
s_zu:   db 'Schlie', 0E1h, 'en', 0

; Aktion je Objekt (0 = keine)
aktion: db 0, 0, 0
        db 'C', 'S', 8, '/'
        db '7', '8', '9', '*'
        db '4', '5', '6', '-'
        db '1', '2', '3', '+'
        db '0', ',', '=', 'X'

ted_titel: TED s_titel, leer, leer, 3, 2, 1191h, -1, 10, 1
ted_anz:   TED t_anz, leer, leer, 3, 1, 1170h, -1, 24, 1

%define KN 26, 1, 0                     ; G_BUTTON, SELECTABLE, Zustand 0
baum:
OB NIL,  1, 22, 20, 3000h, 0, 114Bh, 3, 0, 0, 26, 17     ; 0 Kasten
OB   2, NIL, NIL, 22, 0, 0, ted_titel, 0, 1, 1, 24, 1    ; 1 Titel
OB   3, NIL, NIL, 22, 0, 0, ted_anz, 0, 2, 3, 22, 1      ; 2 Anzeige
OB   4, NIL, NIL, KN, s_c, 0, 2, 5, 4, 1                 ; 3
OB   5, NIL, NIL, KN, s_vz, 0, 8, 5, 4, 1
OB   6, NIL, NIL, KN, s_rk, 0, 14, 5, 4, 1
OB   7, NIL, NIL, KN, s_dv, 0, 20, 5, 4, 1
OB   8, NIL, NIL, KN, s_7, 0, 2, 7, 4, 1                 ; 7
OB   9, NIL, NIL, KN, s_8, 0, 8, 7, 4, 1
OB  10, NIL, NIL, KN, s_9, 0, 14, 7, 4, 1
OB  11, NIL, NIL, KN, s_ml, 0, 20, 7, 4, 1
OB  12, NIL, NIL, KN, s_4, 0, 2, 9, 4, 1                 ; 11
OB  13, NIL, NIL, KN, s_5, 0, 8, 9, 4, 1
OB  14, NIL, NIL, KN, s_6, 0, 14, 9, 4, 1
OB  15, NIL, NIL, KN, s_mi, 0, 20, 9, 4, 1
OB  16, NIL, NIL, KN, s_1, 0, 2, 11, 4, 1                ; 15
OB  17, NIL, NIL, KN, s_2, 0, 8, 11, 4, 1
OB  18, NIL, NIL, KN, s_3, 0, 14, 11, 4, 1
OB  19, NIL, NIL, KN, s_pl, 0, 20, 11, 4, 1
OB  20, NIL, NIL, KN, s_0, 0, 2, 13, 10, 1               ; 19
OB  21, NIL, NIL, KN, s_km, 0, 14, 13, 4, 1
OB  22, NIL, NIL, KN, s_gl, 0, 20, 13, 4, 1
OB   0, NIL, NIL, 26, 27h, 0, s_zu, 0, 7, 15, 12, 1       ; 22 Schliessen

ZUB_ENDE
