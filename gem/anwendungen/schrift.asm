; SCHRIFT.APP - GEM-Programm fuer die NCR DMV: zeigt die Bildschirmschriften,
; die GEMVDI nachladen kann (vst_load_fonts), mit allen Groessen und dem
; Speicher, den sie kosten. Eigenes Programm (rfka01/Claude), NASM.
; Bedienung: Klick oder Taste blaettert weiter, am Ende zurueck zum Desktop.
        cpu 8086
KOPF    equ 32
section .hdr start=0
kopf:   db 'MZ'
        dw ende % 512
        dw (ende + 511) / 512
        dw 0
        dw KOPF / 16
        dw 0                            ; min. zusaetzlich
        dw 0                            ; max. zusaetzlich (Speicher bleibt fuer GEMVDI)
        dw 0
        dw stapel_ende
        dw 0
        dw 0
        dw 0
        dw 28
        dw 0
        times KOPF - ($ - kopf) db 0

section .text start=KOPF vstart=0
start:  mov bx, ds                      ; DS = PSP
        mov ax, cs
        mov ds, ax
        cli
        mov ss, ax
        mov sp, stapel_ende
        sti
        mov [psp], bx
        ; Speicher auf das Programm verkleinern (GEMVDI braucht den Rest)
        mov es, bx
        mov bx, (stapel_ende - start + 15) / 16 + 16
        mov ah, 4Ah
        int 21h
        push ds
        pop es
        mov ax, cs
        mov [ap_s1], ax
        mov [ap_s2], ax
        mov [ap_s3], ax
        mov [ap_s4], ax
        mov [ap_s5], ax
        mov [ap_s6], ax
        mov [vp_s1], ax
        mov [vp_s2], ax
        mov [vp_s3], ax
        mov [vp_s4], ax
        mov [vp_s5], ax
        ; appl_init
        mov ax, 10
        mov bx, 0001h                   ; intin 0, intout 1
        xor cx, cx
        call aesruf
        ; graf_handle -> physischer Handle
        mov ax, 77
        mov bx, 0005h
        xor cx, cx
        call aesruf
        mov ax, [intout]
        mov [vctrl+12], ax
        ; v_opnvwk
        mov di, intin
        mov cx, 10
        mov ax, 1
        rep stosw
        mov word [intin+20], 2
        mov ax, 100
        mov bx, 0
        mov cx, 11
        call vdiruf_h
        mov ax, [vctrl+12]
        mov [handle], ax
        ; Speicher vorher
        call frei
        mov [mem_vor], ax
        ; vst_load_fonts
        mov word [intin], 0
        mov ax, 119
        xor bx, bx
        mov cx, 1
        call vdiruf
        mov ax, [intout]
        mov [anzahl], ax
        call frei
        mov [mem_nach], ax
        ; wind_update(BEG_UPDATE), graf_mouse(M_OFF)
        mov word [intin], 1
        mov ax, 107
        mov bx, 0101h
        xor cx, cx
        call aesruf
        mov word [intin], 256
        call maus
        ; Grundeinstellungen
        mov word [intin], 2             ; transparent
        mov ax, 32
        xor bx, bx
        mov cx, 1
        call vdiruf
        mov word [intin], 0             ; vst_alignment links, oben
        mov word [intin+2], 5
        mov ax, 39
        xor bx, bx
        mov cx, 2
        call vdiruf
        mov word [intin], 1
        mov ax, 22                      ; vst_color 1
        xor bx, bx
        mov cx, 1
        call vdiruf
        call seite_neu
        ; Kopfzeile in der Systemschrift
        mov ax, [anzahl]
        mov di, k_anz
        call zahl5
        mov ax, [mem_vor]
        sub ax, [mem_nach]
        mov di, k_mem
        call bytes7
        mov ax, [mem_nach]
        mov di, k_frei
        call bytes7
        mov si, kopfzeile
        call zeile_sys
        ; Schriften 1 .. anzahl+1
        mov word [index], 1
.schrift:
        mov ax, [anzahl]
        inc ax
        cmp [index], ax
        ja .ende
        ; vqt_name
        mov ax, [index]
        mov [intin], ax
        mov ax, 130
        xor bx, bx
        mov cx, 1
        call vdiruf
        mov ax, [intout]
        mov [font_id], ax
        ; Name nach name_txt (32 Zeichen, Leerzeichen hinten weg)
        mov si, intout + 2
        mov di, name_txt
        mov cx, 32
.n:     lodsw
        or al, al
        jz .nende
        stosb
        loop .n
.nende: cmp di, name_txt
        je .nz
        cmp byte [di-1], ' '
        jne .nz
        dec di
        jmp .nende
.nz:    mov byte [di], 0
        ; vst_font
        mov ax, [font_id]
        mov [intin], ax
        mov ax, 21
        xor bx, bx
        mov cx, 1
        call vdiruf
        mov word [letzt], 0
        mov si, groessen
.gr:    lodsw
        or ax, ax
        jz .naechste
        push si
        mov [intin], ax
        mov [wunsch], ax
        mov ax, 107                     ; vst_point
        xor bx, bx
        mov cx, 1
        call vdiruf
        mov ax, [intout]
        cmp ax, [wunsch]                ; nur Groessen, die es gibt: hat GEMVDI
        jne .gw                         ; eine andere gewaehlt oder hochgerechnet
        cmp ax, [letzt]                 ; (abgeschnitten ab ~45 Zeilen), weglassen
        je .gw
        mov [letzt], ax
        mov di, z_pt
        call zahl3
        mov ax, [font_id]
        mov di, z_id
        call zahl3
        mov ax, [ptsout+6]              ; Zellenhoehe
        add ax, 4
        mov [zh], ax
        add ax, [y]
        cmp ax, 396
        jbe .passt
        call warten
        call seite_neu
.passt: ; Zeile: "Name (Id n) nn pt: Beispiel"
        mov si, name_txt
        mov di, puffer
.c1:    lodsb
        or al, al
        jz .c2
        stosb
        jmp .c1
.c2:    mov si, z_rest
.c3:    lodsb
        stosb
        or al, al
        jnz .c3
        mov si, puffer
        call text
        mov ax, [zh]
        add [y], ax
.gw:    pop si
        jmp .gr
.naechste:
        inc word [index]
        jmp .schrift
.ende:  call warten
        ; vst_unload_fonts
        mov word [intin], 0
        mov ax, 120
        xor bx, bx
        mov cx, 1
        call vdiruf
        mov word [intin], 257           ; graf_mouse(M_ON)
        call maus
        mov word [intin], 0             ; wind_update(END_UPDATE)
        mov ax, 107
        mov bx, 0101h
        xor cx, cx
        call aesruf
        ; form_dial(FMD_FINISH, 0,0,0,0, 0,0,640,400) -> Desktop neu zeichnen
        mov di, intin
        mov ax, 3
        stosw
        xor ax, ax
        stosw
        stosw
        stosw
        stosw
        stosw
        stosw
        mov ax, 640
        stosw
        mov ax, 400
        stosw
        mov ax, 51
        mov bx, 0901h
        xor cx, cx
        call aesruf
        mov ax, 101                     ; v_clsvwk
        xor bx, bx
        xor cx, cx
        call vdiruf
        mov ax, 19                      ; appl_exit
        mov bx, 0001h
        xor cx, cx
        call aesruf
        mov ax, 4C00h
        int 21h

; aesruf: AX = Opcode, BL = intout-Anzahl, BH = intin-Anzahl, CX = addrin
aesruf: mov [actrl], ax
        mov al, bh
        xor ah, ah
        mov [actrl+2], ax
        mov al, bl
        mov [actrl+4], ax
        mov [actrl+6], cx
        mov word [actrl+8], 0
        mov bx, apb
        mov cx, 200
        xor dx, dx
        int 0EFh
        ret
maus:   mov ax, 78
        mov bx, 0101h
        mov cx, 1
        mov word [addrin], 0
        mov word [addrin+2], 0
        jmp aesruf

; vdiruf: AX = Opcode, BX = ptsin-Paare, CX = intin-Anzahl (Handle aus [handle])
vdiruf: push ax
        mov ax, [handle]
        mov [vctrl+12], ax
        pop ax
vdiruf_h:
        mov [vctrl], ax
        mov [vctrl+2], bx
        mov [vctrl+6], cx
        mov word [vctrl+10], 0
        mov dx, vpb
        mov cx, 0473h
        int 0EFh
        ret

; frei: AX = groesster freier Block in Paragraphen
frei:   mov ah, 48h
        mov bx, 0FFFFh
        int 21h
        mov ax, bx
        ret

; seite_neu: Schirm weiss, y oben
seite_neu:
        mov word [intin], 0
        mov ax, 25                      ; vsf_color 0
        xor bx, bx
        mov cx, 1
        call vdiruf
        mov word [intin], 1
        mov ax, 23                      ; vsf_interior voll
        xor bx, bx
        mov cx, 1
        call vdiruf
        mov word [ptsin], 0
        mov word [ptsin+2], 0
        mov word [ptsin+4], 639
        mov word [ptsin+6], 399
        mov ax, 114
        mov bx, 2
        xor cx, cx
        call vdiruf
        mov word [y], 4
        ret

; warten: auf Taste oder Klick (evnt_multi)
warten: mov di, intin
        mov ax, 3                       ; MU_KEYBD | MU_BUTTON
        stosw
        mov ax, 1                       ; 1 Klick
        stosw
        stosw                           ; Maske linke Taste
        stosw                           ; Zustand gedrueckt
        mov cx, 12
        xor ax, ax
        rep stosw
        mov word [addrin], puffer
        mov [addrin+2], cs
        mov ax, 25
        mov bx, 1007h
        mov cx, 1
        call aesruf
        ; Taste loslassen abwarten (evnt_button Zustand 0)
        test word [intout], 2
        jz .r
        mov word [intin], 1
        mov word [intin+2], 1
        mov word [intin+4], 0
        mov ax, 21
        mov bx, 0305h
        xor cx, cx
        call aesruf
.r:     ret

; zeile_sys: Text SI in der Systemschrift (Font 1) ausgeben, Zeile weiter
zeile_sys:
        push si
        mov word [intin], 1
        mov ax, 21
        xor bx, bx
        mov cx, 1
        call vdiruf
        mov word [intin], 10
        mov ax, 107
        xor bx, bx
        mov cx, 1
        call vdiruf
        pop si
        call text
        add word [y], 22
        ret

; text: nullterminierten Text SI an (8, [y]) ausgeben
text:   mov di, intin
        xor cx, cx
        xor ah, ah
.l:     lodsb
        or al, al
        jz .a
        stosw
        inc cx
        cmp cx, 120
        jb .l
.a:     mov word [ptsin], 8
        mov ax, [y]
        mov [ptsin+2], ax
        mov ax, 8
        mov bx, 1
        call vdiruf
        ret

; zahl3/zahl5: AX dezimal rechtsbuendig, 3 bzw. 5 Stellen ab DI
zahl3:  mov cx, 3
        jmp zahl
zahl5:  mov cx, 5
zahl:   add di, cx
        dec di
        mov bx, 10
.l:     xor dx, dx
        div bx
        add dl, '0'
        mov [di], dl
        dec di
        dec cx
        jz .r
        or ax, ax
        jnz .l
.s:     mov byte [di], ' '
        dec di
        loop .s
.r:     ret
; bytes7: AX Paragraphen -> Bytes, 7 Stellen ab DI
bytes7: mov dx, ax
        mov cl, 4
        shl ax, cl
        mov cl, 12
        shr dx, cl
        mov bx, 10
        add di, 6
        mov cx, 7
.l:     push ax
        mov ax, dx
        xor dx, dx
        div bx
        mov si, ax
        pop ax
        div bx
        add dl, '0'
        mov [di], dl
        dec di
        mov dx, si
        dec cx
        jz .r
        mov bx, dx
        or bx, ax
        mov bx, 10
        jnz .l
.s:     mov byte [di], ' '
        dec di
        loop .s
.r:     ret

apb:    dw actrl
ap_s1:  dw 0
        dw aglobal
ap_s2:  dw 0
        dw intin
ap_s3:  dw 0
        dw intout
ap_s4:  dw 0
        dw addrin
ap_s5:  dw 0
        dw addrout
ap_s6:  dw 0
vpb:    dw vctrl
vp_s1:  dw 0
        dw intin
vp_s2:  dw 0
        dw ptsin
vp_s3:  dw 0
        dw intout
vp_s4:  dw 0
        dw ptsout
vp_s5:  dw 0
wunsch:  dw 0
groessen: dw 7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 36, 48, 0
kopfzeile:
        db 'GEM-Schriften auf der DMV:'
k_anz:  db '    0 nachgeladen, belegen'
k_mem:  db '      0 Byte, frei'
k_frei: db '      0 Byte.  Klick/Taste: weiter', 0
z_rest: db ' (Id'
z_id:   db '   ) '
z_pt:   db '   pt: Franz jagt im Taxi quer durch Bayern. ', 8Eh, 99h, 9Ah, ' ', 84h, 94h, 81h, ' 0123456789', 0
y:      dw 4
psp:    times 1 dw 0
handle: times 1 dw 0
anzahl: times 1 dw 0
mem_vor: times 1 dw 0
mem_nach: times 1 dw 0
index:  times 1 dw 0
font_id: times 1 dw 0
letzt:  times 1 dw 0
zh:     times 1 dw 0
actrl:  times 5 dw 0
aglobal: times 15 dw 0
addrin: times 4 dw 0
addrout: times 4 dw 0
vctrl:  times 12 dw 0
intin:  times 130 dw 0
intout: times 64 dw 0
ptsin:  times 16 dw 0
ptsout: times 16 dw 0
name_txt: times 34 db 0
puffer: times 200 db 0
        times 1024 db 0
stapel_ende:
ende    equ KOPF + (stapel_ende - start)
