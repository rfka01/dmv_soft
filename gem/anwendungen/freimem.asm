; FREIMEM.ACC - GEM-Zubehoer fuer die NCR DMV: zeigt den freien Speicher.
; Eigenes Programm (rfka01/Claude), NASM, ein Segment.
; Menue "Freier Speicher" -> Meldung mit groesstem freien Block und
; Summe aller freien Bloecke (MCB-Kette ueber INT 21h/52h).
        cpu 8086
KOPF    equ 32                          ; MZ-Kopf, 2 Paragraphen
section .hdr start=0
kopf:   db 'MZ'
        dw ende % 512                   ; Bytes auf der letzten Seite
        dw (ende + 511) / 512           ; Seiten
        dw 0                            ; keine Verschiebungen
        dw KOPF / 16                    ; Kopfgroesse in Paragraphen
        dw 0                            ; min. zusaetzlich
        dw 0                            ; max. zusaetzlich
        dw 0                            ; SS relativ
        dw stapel_ende - start          ; SP (im Bild: das AES gibt nur die Dateigroesse)
        dw 0                            ; Pruefsumme
        dw 0                            ; IP
        dw 0                            ; CS relativ
        dw 28                           ; Verschiebungstabelle
        dw 0
        times KOPF - ($ - kopf) db 0

STAPEL  equ 512
section .text start=KOPF vstart=0
start:  cli                             ; eigener Stapel (wie CALCLOCK)
        mov ax, cs
        mov ds, ax
        mov ss, ax
        mov sp, stapel_ende
        sti
        mov es, ax
        mov [pb_s1], ax                 ; Segmente im Parameterblock
        mov [pb_s2], ax
        mov [pb_s3], ax
        mov [pb_s4], ax
        mov [pb_s5], ax
        mov [pb_s6], ax
        ; appl_init
        mov word [ctrl], 10
        mov word [ctrl+2], 0
        mov word [ctrl+4], 1
        mov word [ctrl+6], 0
        mov word [ctrl+8], 0
        call aes
        mov ax, [intout]
        mov [apid], ax
        ; menu_register(apid, titel)
        mov word [ctrl], 35
        mov word [ctrl+2], 1
        mov word [ctrl+4], 1
        mov word [ctrl+6], 1
        mov [intin], ax
        mov word [addrin], titel
        mov [addrin+2], cs
        call aes
schleife:
        ; evnt_mesag(puffer)
        mov word [ctrl], 23
        mov word [ctrl+2], 0
        mov word [ctrl+4], 1
        mov word [ctrl+6], 1
        mov word [addrin], puffer
        mov [addrin+2], cs
        call aes
        cmp word [puffer], 40           ; AC_OPEN
        jne schleife
        call messen
        ; form_alert(1, meldung)
        mov word [ctrl], 52
        mov word [ctrl+2], 1
        mov word [ctrl+4], 1
        mov word [ctrl+6], 1
        mov word [intin], 1
        mov word [addrin], meldung
        mov [addrin+2], cs
        call aes
        jmp schleife

aes:    mov word [ctrl+8], 0            ; AES: CX = 200, DX = 0, ES:BX = Block
        push es
        push cs
        pop es
        mov bx, pb
        xor dx, dx
        mov cx, 200
        int 0EFh
        pop es
        ret

; messen: groesster Block (48h, BX=FFFF) und Summe der freien MCBs
messen: mov ah, 48h
        mov bx, 0FFFFh
        int 21h                         ; schlaegt fehl, BX = groesster Block
        mov ax, bx
        mov di, z_block
        call schreib_par
        ; MCB-Kette
        push es
        mov ah, 52h
        int 21h
        mov ax, [es:bx-2]               ; erster MCB
        xor si, si                      ; Summe (Paragraphen, 32 Bit in DX:SI)
        xor dx, dx
        mov cx, 4000                    ; Notbremse
.l:     mov es, ax
        mov bl, [es:0]
        cmp bl, 'M'
        je .ok
        cmp bl, 'Z'
        jne .fertig
.ok:    cmp word [es:1], 0              ; Besitzer 0 = frei
        jne .weiter
        add si, [es:3]
        adc dx, 0
.weiter:
        cmp bl, 'Z'
        je .fertig
        add ax, [es:3]
        inc ax
        loop .l
.fertig:
        pop es
        mov ax, si                      ; DX:AX Paragraphen (DX ist 0)
        mov di, z_summe
        call schreib_par
        ret

; schreib_par: AX Paragraphen -> Bytes dezimal, rechtsbuendig in 7 Stellen ab DI
schreib_par:
        mov dx, ax
        mov cl, 4
        shl ax, cl                      ; DX:AX = AX * 16
        mov cl, 12
        shr dx, cl
        mov bx, 10
        add di, 6
        mov cx, 7
.z:     push ax                         ; DX:AX / 10, 32 Bit
        mov ax, dx
        xor dx, dx
        div bx
        mov si, ax                      ; hoher Teil des Quotienten
        pop ax
        div bx                          ; DX = Rest
        add dl, '0'
        mov [di], dl
        dec di
        mov dx, si
        mov si, ax
        or si, dx
        jz .leer
        loop .z
        ret
.leer:  dec cx
        jz .r
.lz:    mov byte [di], ' '
        dec di
        loop .lz
.r:     ret

pb:     dw ctrl
pb_s1:  dw 0, glob
pb_s2:  dw 0, intin
pb_s3:  dw 0, intout
pb_s4:  dw 0, addrin
pb_s5:  dw 0, addrout
pb_s6:  dw 0
titel:  db '  Freier Speicher', 0
meldung:
        db '[1][Freier Speicher unter GEM:| |'
        db 'Gr', 94h, 0E1h, 'ter Block: '
z_block: db '      0 Byte|'
        db 'Frei zusammen: '
z_summe: db '      0 Byte][  OK  ]', 0
ctrl:   times 5 dw 0
glob: times 15 dw 0
intin:  times 4 dw 0
intout: times 4 dw 0
addrin: times 4 dw 0
addrout: times 4 dw 0
apid:   dw 0
puffer: times 8 dw 0
        align 16
stapel: times STAPEL db 0
stapel_ende:
bild_ende:
ende    equ KOPF + (bild_ende - start)
