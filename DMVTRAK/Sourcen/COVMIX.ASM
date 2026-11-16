; COVMIX.ASM - Covox-Ausgabe fuer DMVTRAK (nasm -f bin)
;
; Der Code laeuft in einem eigenen, auf 16 Byte ausgerichteten Segment,
; das DMVTRAK auf dem Heap anlegt; dieses Programm wird an Offset 10B0h
; kopiert (CODEBASE). Belegung des Segments:
;   0000-0FFF  Ringpuffer (vorzeichenlose Abtastwerte fuer den DAC), 4 KB
;   1000-101F  Variablen (siehe unten)
;   1020-109F  8 Kanaele zu 16 Byte
;   10A0-10AF  Arbeitsvariablen des Mischers
;   10B0-12FF  dieser Code
;   1300-23FF  Lautstaerketabellen 0..16 zu 256 Byte (von DMVTRAK berechnet)
;
; 10B0  ISR:  Timer-Interrupt (IRQ0 = INT 08h, 8253 Kanal 2 auf Abtastrate):
;             ein Byte aus dem Ring an Port 60h (K210, Port A); alle
;             OLDDIV Zaehlschritte wird der alte INT-08h-Handler aufgerufen.
; 10B3  MIX:  (far) mischt NSAMP Werte aller NCH Kanaele in den Ring.
;
; Code: Claude (Anthropic), Idee und Prompts: rfka01 - Lizenz MIT

        cpu 8086
        bits 16

RD      equ 1000h       ; Leseindex des Rings (ISR)
WR      equ 1002h       ; Schreibindex (MIX)
TACC    equ 1004h       ; Zaehler fuer den alten Takt
OLDDIV  equ 1006h
NEWDIV  equ 1008h
OLDVEC  equ 100Ah       ; dword
ICOUNT  equ 100Eh       ; Interrupts gezaehlt
UNDER   equ 1010h       ; Aussetzer (Ring leer)
NSAMP   equ 1014h
NCH     equ 1016h
CHI     equ 1018h       ; laufender Kanal
CPTR    equ 101Ah       ; Zeiger auf Kanalblock
SEG1    equ 10A0h       ; (frueher Mischpuffer, jetzt Arbeitsvariablen)
SEG2    equ 10A2h
REM     equ 10A4h
STEPI1  equ 10A6h
CEND    equ 10A8h
CLOOPL  equ 10AAh
COFF    equ 10ACh
CHAN    equ 1020h
VOLTAB  equ 13h         ; Hi-Byte der Tabelle fuer Lautstaerke 0

; Kanalblock
C_SEG   equ 0           ; Segment des Samples, 0 = aus
C_POS   equ 2
C_FRAC  equ 4
C_STEPI equ 6
C_STEPF equ 8
C_END   equ 10          ; Offset hinter dem Ende (bzw. Schleifenende)
C_LOOPL equ 12          ; Schleifenlaenge, 0 = keine
C_VOL   equ 14          ; 0..16

        org 10B0h

        jmp near isr
        jmp near mix

; ------------------------------------------------------------------
isr:    push ax
        push bx
        mov bx,[cs:RD]
        cmp bx,[cs:WR]
        je .under
        mov al,[cs:bx]
        out 60h,al
        inc bx
        and bh,0Fh
        mov [cs:RD],bx
.chain: inc word [cs:ICOUNT]
        mov ax,[cs:NEWDIV]
        sub [cs:TACC],ax
        jnc .done
        mov ax,[cs:OLDDIV]
        add [cs:TACC],ax
        pop bx
        pop ax
        jmp far [cs:OLDVEC]     ; der alte Handler endet mit IRET
.done:  pop bx
        pop ax
        iret
.under: inc word [cs:UNDER]
        jmp .chain

; ------------------------------------------------------------------
; MIX: Ring an WR um NSAMP Werte (vorher Platz geprueft) mit 80h fuellen,
; dann jeden Kanal dazuaddieren (Werte der Tabellen sind vorzeichen-
; behaftet und so klein, dass die Summe nicht ueberlaeuft). Ein Ring-
; ueberlauf teilt den Block in zwei Stuecke.
mix:    push ds
        push es
        push bp
        push si
        push di
        mov ax,cs
        mov ds,ax
        mov es,ax
        cld
        mov ax,1000h            ; Stueck 1: WR .. min(Ende, WR+N)
        sub ax,[WR]
        mov cx,[NSAMP]
        cmp ax,cx
        jb .s1
        mov ax,cx
.s1:    mov [SEG1],ax
        sub cx,ax
        mov [SEG2],cx
        mov di,[WR]             ; mit 80h vorbelegen
        mov cx,[SEG1]
        mov al,80h
        rep stosb
        xor di,di
        mov cx,[SEG2]
        rep stosb
        mov word [CHI],0
.chl:   mov bx,[CHI]
        cmp bx,[NCH]
        jb .ch
        jmp .done
.ch:    mov cl,4
        shl bx,cl
        add bx,CHAN
        mov [CPTR],bx
        mov ax,[bx+C_SEG]
        or ax,ax
        jnz .act
        jmp .next
.act:   cmp byte [bx+C_VOL],0
        jne .mixit
        jmp .adv                ; stumm: nur vorruecken
.mixit: mov es,ax
        mov ax,[bx+C_STEPI]
        mov [cs:run.pa1+2],ax   ; Selbstmodifikation: adc si,stepi
        mov [cs:run.pa2+2],ax
        mov [cs:run.pa3+2],ax
        mov [cs:run.pa4+2],ax
        inc ax
        mov [STEPI1],ax
        mov ax,[bx+C_END]
        mov [CEND],ax
        mov ax,[bx+C_LOOPL]
        mov [CLOOPL],ax
        mov byte [COFF],0
        mov si,[bx+C_POS]
        mov dx,[bx+C_FRAC]
        mov bp,[bx+C_STEPF]
        mov ah,[bx+C_VOL]
        add ah,VOLTAB
        mov bh,ah
        mov di,[WR]
        mov ax,[SEG1]
        mov [REM],ax
        call run
        xor di,di
        mov ax,[SEG2]
        mov [REM],ax
        call run
        mov bx,[CPTR]
        cmp byte [COFF],0
        je .store
        mov word [bx+C_SEG],0
        jmp short .next
.store: mov [bx+C_POS],si
        mov [bx+C_FRAC],dx
.next:  inc word [CHI]
        jmp .chl

; stummer Kanal: Position um NSAMP Schritte vorruecken (MUL statt Schleife)
.adv:   mov cx,[NSAMP]
        mov ax,[bx+C_STEPF]
        mul cx                  ; DX:AX = N * Bruchschritt
        add ax,[bx+C_FRAC]
        adc dx,0
        mov [bx+C_FRAC],ax
        mov si,dx               ; ganzzahliger Uebertrag
        mov ax,[bx+C_STEPI]
        mul cx                  ; DX:AX = N * ganzer Schritt
        add ax,si
        adc dx,0
        add ax,[bx+C_POS]
        adc dx,0                ; DX:AX = neue Position
        or dx,dx
        jnz .past
        cmp ax,[bx+C_END]
        jb .advst
.past:  mov cx,[bx+C_LOOPL]
        jcxz .aoff
        mov si,[bx+C_END]       ; Schleifenanfang
        sub si,cx
        sub ax,si
        sbb dx,0
        div cx                  ; Rest = Lage in der Schleife
        mov ax,dx
        add ax,si
.advst: mov [bx+C_POS],ax
        jmp .next
.aoff:  mov word [bx+C_SEG],0
        jmp .next
.done:  mov ax,[WR]
        add ax,[NSAMP]
        and ax,0FFFh
        mov [WR],ax
        pop di
        pop si
        pop bp
        pop es
        pop ds
        retf

; run: REM Werte ab DI dazumischen. Register: ES:SI Sample, DX Bruchteil,
; BP Schritt (Bruch), BH Lautstaerketabelle.
run:    cmp byte [COFF],0
        jne .ret
.top:   mov cx,[REM]
        jcxz .ret
        push dx                 ; sicher bis zum Ende: (END-SI-1)/(STEPI+1)
        mov ax,[CEND]
        sub ax,si
        dec ax
        xor dx,dx
        div word [STEPI1]
        pop dx
        or ax,ax
        jz .one
        cmp ax,cx
        jae .full
        mov cx,ax
.full:  sub [REM],cx
        shr cx,1                ; zweifach abgerollt
        jnc .f2
        mov bl,[es:si]          ; ungerade Anzahl: erst ein Wert
        mov al,[bx]
        add [di],al
        inc di
        add dx,bp
.pa1:   adc si,1234h
        jcxz .fe
.f2:    mov bl,[es:si]
        mov al,[bx]
        add [di],al
        inc di
        add dx,bp
.pa3:   adc si,1234h
        mov bl,[es:si]
        mov al,[bx]
        add [di],al
        inc di
        add dx,bp
.pa4:   adc si,1234h
        loop .f2
.fe:    jmp .top
.one:   mov bl,[es:si]          ; ein Wert mit Pruefung des Endes
        mov al,[bx]
        add [di],al
        inc di
        add dx,bp
.pa2:   adc si,1234h
        dec word [REM]
        cmp si,[CEND]
        jb .top
        mov ax,[CLOOPL]
        or ax,ax
        jz .off
.wrap:  sub si,ax
        cmp si,[CEND]
        jae .wrap
        jmp .top
.off:   mov byte [COFF],1
.ret:   ret
