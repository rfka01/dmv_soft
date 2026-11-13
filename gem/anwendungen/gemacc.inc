; gemacc.inc - gemeinsamer Rahmen fuer die GEM-Zubehoere der DMV (NASM).
; Eigenes Programm (rfka01/Claude), MIT-Lizenz.
;
; Ein Zubehoer ist eine kleine .EXE in einem Segment (CS = DS = SS). Vor
; dem Einbinden definieren: STAPEL (Byte). Das Programm stellt bereit:
;   haupt   - wird nach appl_init und menu_register aufgerufen bei AC_OPEN
;   titel   - Menueeintrag (0-terminiert)
; Am Ende des Programms: ZUB_ENDE
        cpu 8086
KOPF    equ 32
section .hdr start=0
kopf:   db 'MZ'
        dw ende % 512
        dw (ende + 511) / 512
        dw 0
        dw KOPF / 16
        dw 0
        dw 0
        dw 0
        dw stapel_ende - start
        dw 0
        dw 0
        dw 0
        dw 28
        dw 0
        times KOPF - ($ - kopf) db 0

section .text start=KOPF vstart=0
start:  cli
        mov ax, cs
        mov ds, ax
        mov ss, ax
        mov sp, stapel_ende
        sti
        mov es, ax
        mov [pb_s1], ax
        mov [pb_s2], ax
        mov [pb_s3], ax
        mov [pb_s4], ax
        mov [pb_s5], ax
        mov [pb_s6], ax
        cld
        call vorbereiten                ; vom Programm (Baeume fixieren usw.)
        mov ax, 10                      ; appl_init
        mov bx, 0001h
        mov cx, 0000h
        call aesruf
        mov ax, [intout]
        mov [apid], ax
        mov [intin], ax                 ; menu_register(apid, titel)
        mov word [addrin], titel
        mov ax, 35
        mov bx, 0101h
        mov cx, 0100h
        call aesruf
.schleife:
        mov word [addrin], puffer       ; evnt_mesag
        mov ax, 23
        mov bx, 0001h
        mov cx, 0100h
        call aesruf
        cmp word [puffer], 40           ; AC_OPEN
        jne .schleife
        call haupt
        jmp .schleife

; aesruf: AX = Opcode, BH = Zahl intin, BL = Zahl intout,
;         CH = Zahl addrin, CL = Zahl addrout
aesruf: mov [ctrl], ax
        mov al, bh
        xor ah, ah
        mov [ctrl+2], ax
        mov al, bl
        mov [ctrl+4], ax
        mov al, ch
        mov [ctrl+6], ax
        mov al, cl
        mov [ctrl+8], ax
        push es
        push cs
        pop es
        mov bx, pb
        xor dx, dx
        mov cx, 200
        int 0EFh
        pop es
        mov ax, [intout]
        ret

; ---- kleine Helfer (Baum in SI) ----------------------------------
; obfix: alle Objekte des Baums SI (Zahl in CX) von Zeichen in Punkte
obfix:  xor dx, dx
.o:     push cx
        push dx
        mov [intin], dx
        mov [addrin], si
        mov [addrin+2], cs
        mov ax, 114
        mov bx, 0101h
        mov cx, 0100h
        call aesruf
        pop dx
        pop cx
        inc dx
        loop .o
        ret

; segs: Zeiger im Baum SI (CX Objekte) auf unser Segment setzen und den
; Baum von Zeichen- in Punktmasse umrechnen
segs:   push cx
        push si
.s:     mov ax, [si+6]                  ; Typ
        cmp ax, 21                      ; G_TEXT, G_BOXTEXT, G_FTEXT, G_FBOXTEXT: TEDINFO
        je .ted
        cmp ax, 22
        je .ted
        cmp ax, 29
        je .ted
        cmp ax, 30
        je .ted
        cmp ax, 26                      ; G_BUTTON, G_STRING, G_TITLE: Text
        je .zeig
        cmp ax, 28
        je .zeig
        cmp ax, 32
        je .zeig
        jmp short .weiter
.ted:   mov bx, [si+12]
        mov [bx+2], cs
        mov [bx+6], cs
        mov [bx+10], cs
.zeig:  mov [si+14], cs
.weiter:
        add si, 24
        loop .s
        pop si
        pop cx
        jmp obfix

; dialog_auf: Baum SI zentrieren, Hintergrund sichern lassen, zeichnen
dialog_auf:
        mov ax, 1                       ; wind_update(BEG_UPDATE)
        call wupd
        mov ax, 3                       ; BEG_MCTRL
        call wupd
        mov [addrin], si
        mov [addrin+2], cs
        mov ax, 54                      ; form_center
        mov bx, 0005h
        mov cx, 0100h
        call aesruf
        mov ax, [intout+2]
        mov [dx_], ax
        mov ax, [intout+4]
        mov [dy_], ax
        mov ax, [intout+6]
        mov [dw_], ax
        mov ax, [intout+8]
        mov [dh_], ax
        xor ax, ax                      ; FMD_START
        call fdial
        xor ax, ax
        jmp zeichne_ab                  ; ganzen Baum zeichnen

; dialog_zu: FMD_FINISH, Steuerung zurueck
dialog_zu:
        mov ax, 3
        call fdial
        mov ax, 2                       ; END_MCTRL
        call wupd
        xor ax, ax                      ; END_UPDATE
        jmp wupd

wupd:   mov [intin], ax
        mov ax, 107
        mov bx, 0101h
        xor cx, cx
        jmp aesruf

fdial:  mov [intin], ax
        mov ax, [dx_]
        mov [intin+2], ax
        mov [intin+10], ax
        mov ax, [dy_]
        mov [intin+4], ax
        mov [intin+12], ax
        mov ax, [dw_]
        mov [intin+6], ax
        mov [intin+14], ax
        mov ax, [dh_]
        mov [intin+8], ax
        mov [intin+16], ax
        mov ax, 51
        mov bx, 0901h
        xor cx, cx
        jmp aesruf

; zeichne_ab: Objekt AX des Baums SI samt Kindern zeichnen (im Dialogrechteck)
zeichne_ab:
        mov [intin], ax
        mov word [intin+2], 8
        mov ax, [dx_]
        mov [intin+4], ax
        mov ax, [dy_]
        mov [intin+6], ax
        mov ax, [dw_]
        mov [intin+8], ax
        mov ax, [dh_]
        mov [intin+10], ax
        mov [addrin], si
        mov [addrin+2], cs
        mov ax, 42
        mov bx, 0601h
        mov cx, 0100h
        jmp aesruf

; finde: Objekt unter (CX, DX) im Baum SI -> AX (-1 keins)
finde:  mov word [intin], 0
        mov word [intin+2], 8
        mov [intin+4], cx
        mov [intin+6], dx
        mov [addrin], si
        mov [addrin+2], cs
        mov ax, 43
        mov bx, 0401h
        mov cx, 0100h
        jmp aesruf

; obj: Adresse des Objekts AX im Baum SI -> BX
obj:    push dx
        mov bx, 24
        mul bx
        mov bx, ax
        add bx, si
        pop dx
        ret

; zustand: Objekt AX auf Zustand DX setzen und neu zeichnen
zustand:
        push ax
        call obj
        mov [bx+10], dx
        pop ax
        jmp zeichne_ab

; warte: AX Millisekunden (evnt_timer)
warte:  mov [intin], ax
        mov word [intin+2], 0
        mov ax, 24
        mov bx, 0201h
        xor cx, cx
        jmp aesruf

; ereignis: evnt_multi Knopf|Tastatur|Zeit (AX ms) -> AX = Ereignisse,
; [ev_x], [ev_y], [ev_taste]
ereignis:
        mov [intin+28], ax              ; Zeit lo
        mov word [intin+30], 0
        mov word [intin], 1|2|32        ; MU_KEYBD|MU_BUTTON|MU_TIMER
        mov word [intin+2], 1           ; ein Klick
        mov word [intin+4], 1           ; linke Taste
        mov word [intin+6], 1           ; gedrueckt
        mov di, intin+8
        mov cx, 10
        xor ax, ax
.n:     mov [di], ax
        add di, 2
        loop .n
        mov word [addrin], puffer
        mov [addrin+2], cs
        mov ax, 25
        mov bx, 1007h
        mov cx, 0100h
        call aesruf
        mov [ev_was], ax
        mov bx, [intout+2]
        mov [ev_x], bx
        mov bx, [intout+4]
        mov [ev_y], bx
        mov bx, [intout+10]
        mov [ev_taste], bx
        ret

; knopf_druecken: Knopf AX kurz gedrueckt zeigen
knopf_druecken:
        push ax
        mov dx, 1                       ; SELECTED
        call knopf_st
        mov ax, 90
        call warte
        pop ax
        xor dx, dx
knopf_st:
        push ax
        call obj
        mov cx, [bx+10]
        and cx, 0FFFEh
        or cx, dx
        mov dx, cx
        pop ax
        jmp zustand

; zahl2: AL (0-99) zweistellig nach [DI], DI += 2
zahl2:  aam
        add ax, 3030h
        xchg al, ah
        stosw
        ret

; ---- AES-Parameterblock ----
pb:     dw ctrl
pb_s1:  dw 0, glob
pb_s2:  dw 0, intin
pb_s3:  dw 0, intout
pb_s4:  dw 0, addrin
pb_s5:  dw 0, addrout
pb_s6:  dw 0
ctrl:   times 5 dw 0
glob:   times 15 dw 0
intin:  times 16 dw 0
intout: times 8 dw 0
addrin: times 4 dw 0
addrout: times 4 dw 0
apid:   dw 0
puffer: times 8 dw 0
dx_:    dw 0
dy_:    dw 0
dw_:    dw 0
dh_:    dw 0
ev_x:   dw 0
ev_y:   dw 0
ev_taste: dw 0
ev_was: dw 0

%macro ZUB_ENDE 0
        align 16
stapel: times STAPEL db 0
stapel_ende:
bild_ende:
ende    equ KOPF + (bild_ende - start)
%endmacro

; Objekt: OB naechst, kopf, schwanz, typ, flags, zustand, spec(lo,hi), x, y, b, h
%macro OB 12
        dw %1, %2, %3, %4, %5, %6
        dw %7, %8
        dw %9, %10, %11, %12
%endmacro
%define NIL 0FFFFh
; TEDINFO: text, vorlage, gueltig, font, just, farbe, dicke, len text, len vorlage
%macro TED 9
        dw %1, 0, %2, 0, %3, 0
        dw %4, 0, %5, %6, 0, %7, %8, %9
%endmacro
