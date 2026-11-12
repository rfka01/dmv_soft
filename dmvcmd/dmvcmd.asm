; ============================================================================
; DMVCMD - ANSI dual-panel file manager for the NCR Decision Mate V
; (vormals DMVNC; umbenannt in dmv_soft)
; Renders via DOS INT 21h + ANSI escapes. Color by default; mono toggle.
; NC-style: directories UPPERCASE, files lowercase, system files marked.
; Keys: arrows (ADM-3A diamond ^E/^X/^S/^D) + k/j, TAB, ENTER, BKSP,
;       F10/q quit, F5 mono/color toggle.
; ============================================================================
    org 100h

MAXENT   equ 128
; entry layout: name(13) + attr(1) + size(4) + date(2) = 20
ENTSZ    equ 20
E_ATTR   equ 13           ; offset of attr within entry
E_SIZE   equ 14           ; offset of dword file size
E_DATE   equ 18           ; offset of word packed date
LISTROWS equ 17           ; visible list rows (screen rows 3..19), inside frame
LCOL     equ 2            ; left panel content column (inside left border)
RCOL     equ 42           ; right panel content column (inside right border)
PANW     equ 37           ; total field width per panel row
NAMEW    equ 16           ; name column width (rest = size + date)
MAXDRIVE equ 26           ; hard ceiling A..Z; real count comes from probe
; drive status codes (in drvstat[] table, one byte per drive 0..MAXPROBE-1)
DS_ABSENT  equ 0          ; drive letter not present in system
DS_READY   equ 1          ; drive present and media readable
DS_NOTRDY  equ 2          ; drive present but no disk / not ready
DS_UNKNOWN equ 3          ; drive present, media not probed yet (startup)
MAXPROBE   equ 8          ; probe drives A..H (0..7)
; frame geometry
LBORD    equ 1            ; left box left-border column
LBORDR   equ 40           ; left box right-border column
RBORD    equ 41           ; right box left-border column
RBORDR   equ 80           ; right box right-border column
TOPROW   equ 2            ; top border row
BOTROW   equ 20           ; bottom border row (TOPROW + 1 + LISTROWS)

P_CNT    equ 0
P_SEL    equ 2
P_TOP    equ 4
P_DRIVE  equ 6            ; current drive for this panel (0=A,1=B,...)
P_CWDPTR equ 8            ; word: pointer to this panel's own cwd string buffer
P_DATA   equ 10

DTA_ATTR equ 21
DTA_TIME equ 22           ; word: packed time
DTA_DATE equ 24           ; word: packed date (y-1980<<9 | mon<<5 | day)
DTA_SIZE equ 26           ; dword: file size
DTA_NAME equ 30

start:
    cld
    call install_int24       ; our own critical-error handler (silent abort)
    call probe_drives        ; build drvstat[] + drivecount
    call setcolor            ; establish color palette (or mono per flag)
    call cls
    mov word [actpanel],0
    mov word [monoflag],0    ; 0 = color, 1 = mono
    ; initialize both panels to the current default drive
    mov ah,19h
    int 21h                  ; AL = current drive (0=A)
    mov ah,0
    mov [LEFT+P_DRIVE],ax
    mov [RIGHT+P_DRIVE],ax
    ; wire each panel to its own cwd buffer, start at root (empty string)
    mov word [LEFT+P_CWDPTR],leftcwd
    mov word [RIGHT+P_CWDPTR],rightcwd
    mov byte [leftcwd],0
    mov byte [rightcwd],0
    mov bx,LEFT
    call panel_load_bx
    mov bx,RIGHT
    call panel_load_bx
    call draw_all
main_loop:
    call read_key
    ; --- quit ---
    cmp al,'q'
    je do_quit
    cmp al,'Q'
    je do_quit
    ; --- navigation single keys ---
    cmp al,9
    je do_tab
    cmp al,13
    je do_enter
    cmp al,'k'
    je do_up
    cmp al,'j'
    je do_down
    ; ADM-3A / WordStar diamond arrows
    cmp al,05h               ; ^E up
    je do_up
    cmp al,18h               ; ^X down
    je do_down
    cmp al,13h               ; ^S left  -> switch to left panel
    je go_left
    cmp al,04h               ; ^D right -> switch to right panel
    je go_right
    cmp al,'h'               ; h = left panel
    je go_left
    cmp al,'l'               ; l = right panel
    je go_right
    cmp al,'t'               ; t = jump to top
    je do_top
    cmp al,'T'
    je do_top
    cmp al,'m'               ; toggle mono/color
    je do_toggle
    cmp al,'M'
    je do_toggle
    cmp al,'d'               ; cycle active panel's drive
    je do_drive
    cmp al,'D'
    je do_drive
    cmp al,'c'               ; copy selected file to other panel's dir
    je do_copy
    cmp al,'C'
    je do_copy
    ; --- extended (00 + fnum) function keys ---
    jmp main_loop

go_left:
    mov word [actpanel],0
    call draw_all
    jmp main_loop
go_right:
    mov word [actpanel],1
    call draw_all
    jmp main_loop

do_toggle:
    mov ax,[monoflag]
    xor ax,1
    mov [monoflag],ax
    call setcolor
    call draw_all
    jmp main_loop

; open the NC-style drive submenu for the active panel
do_drive:
    call drive_menu           ; returns AL=chosen drive (0..) or AL=0FFh cancel
    cmp al,0FFh
    je dm_cancel
    ; got a ready drive: assign to active panel and reload
    mov ah,0
    call cur_panel_ptr        ; BX = active panel
    mov [bx+P_DRIVE],ax
    call panel_load_bx
dm_cancel:
    call draw_all
    jmp main_loop

do_top:
    call cur_panel_ptr
    mov word [bx+P_SEL],0
    mov word [bx+P_TOP],0
    call draw_panel_bx
    jmp main_loop

do_quit:
    call restore_int24       ; put back the DOS critical-error handler
    call setnormal
    call cls
    mov ax,4C00h
    int 21h

do_tab:
    mov ax,[actpanel]
    xor ax,1
    mov [actpanel],ax
    call draw_all
    jmp main_loop

do_up:
    call cur_panel_ptr
    mov ax,[bx+P_SEL]
    cmp ax,0
    je ml2
    dec ax
    mov [bx+P_SEL],ax
    mov cx,[bx+P_TOP]
    cmp ax,cx
    jae up_ns
    mov [bx+P_TOP],ax
up_ns:
    call draw_panel_bx
ml2:
    jmp main_loop

do_down:
    call cur_panel_ptr
    mov ax,[bx+P_SEL]
    inc ax
    cmp ax,[bx+P_CNT]
    jae ml2
    mov [bx+P_SEL],ax
    mov cx,[bx+P_TOP]
    add cx,LISTROWS
    cmp ax,cx
    jb dn_ns
    mov cx,ax
    sub cx,LISTROWS
    inc cx
    mov [bx+P_TOP],cx
dn_ns:
    call draw_panel_bx
    jmp main_loop

do_enter:
    call sel_entry_ptr
    mov al,[si+E_ATTR]
    test al,10h
    jz ml2b                  ; not a directory -> ignore ENTER
    ; SI -> entry; the name is at the entry base (SI). Update panel cwd string.
    ; Is it ".."? (name[0]=='.' and name[1]=='.')
    mov al,[si]
    cmp al,'.'
    jne de_descend
    mov al,[si+1]
    cmp al,'.'
    jne de_descend
    ; ".." -> pop last segment from panel cwd
    call cwd_pop
    jmp de_reload
de_descend:
    ; append the directory name (at SI) as a new segment
    call cwd_push            ; SI = name to append
de_reload:
    call cur_panel_ptr
    call panel_load_bx
    call draw_all
ml2b:
    jmp main_loop

; ============================================================================
;  do_copy - copy the selected file from the active panel to the other panel's
;  directory (classic NC F5). Files only; directories are skipped for now.
; ============================================================================
do_copy:
    ; get the selected entry in the active panel
    call sel_entry_ptr        ; SI -> entry name, BX -> active panel
    ; skip directories (attr bit 10h) - can't copy a dir yet
    mov al,[si+E_ATTR]
    test al,10h
    jnz dc_abort
    ; remember the filename pointer (entry name is at the entry base = SI)
    mov [copyname],si
    ; --- build source path into srcpath: active panel + filename ---
    call cur_panel_ptr        ; BX = active (source) panel
    mov si,[copyname]
    mov di,srcpath
    call build_path
    ; --- build dest path into dstpath: other panel + same filename ---
    call other_panel_ptr      ; BX = inactive (dest) panel
    mov si,[copyname]
    mov di,dstpath
    call build_path
    ; --- ask for confirmation before copying ---
    call copy_confirm         ; AL=1 OK, AL=0 cancel
    cmp al,1
    jne dc_cancel
    ; --- perform the byte copy ---
    call copy_file            ; CF set on error
    jc dc_err
    ; success: reload the DEST panel so the new file shows, redraw
    call other_panel_ptr
    call panel_load_bx
    call draw_all
    call copy_status_ok
    jmp main_loop
dc_cancel:
    call draw_all
    jmp main_loop
dc_err:
    call draw_all
    call copy_status_err
    jmp main_loop
dc_abort:
    jmp main_loop

; other_panel_ptr: BX = the NON-active panel (copy destination)
other_panel_ptr:
    mov bx,RIGHT
    cmp word [actpanel],0
    je opp_e
    mov bx,LEFT
opp_e:
    ret

; build_path: construct "<drive>:\<cwd>\<name>" (ASCIIZ) at ES:DI (=DS:DI here).
; IN: BX = panel base (for P_DRIVE), SI = ASCIIZ filename. Clobbers AX,CX,DX,DI.
; Note: selects the panel's drive first so getcwd (AH=47h) reflects it.
build_path:
    push si
    ; drive letter
    mov al,[bx+P_DRIVE]
    add al,'A'
    mov [di],al
    inc di
    mov al,':'
    mov [di],al
    inc di
    mov al,92                 ; backslash
    mov [di],al
    inc di
    ; copy this panel's own cwd string (relative, no leading backslash)
    mov si,[bx+P_CWDPTR]
    mov cx,0                  ; count of cwd chars copied
bp_cwd:
    mov al,[si]
    or al,al
    jz bp_cwddone
    mov [di],al
    inc di
    inc si
    inc cx
    jmp bp_cwd
bp_cwddone:
    ; if cwd was non-empty, add a separating backslash
    cmp cx,0
    je bp_name
    mov al,92
    mov [di],al
    inc di
bp_name:
    ; append the filename
    pop si                    ; SI = filename
bp_nloop:
    mov al,[si]
    or al,al
    jz bp_end
    mov [di],al
    inc di
    inc si
    jmp bp_nloop
bp_end:
    mov byte [di],0           ; terminate
    ret

; sync_cwd: make the DOS current directory match BX panel's own cwd string.
; DOS keeps one cwd per drive; panels may differ, so we reset to root then
; chdir into the panel's stored relative path. Drive already selected by caller.
sync_cwd:
    push ax
    push dx
    push si
    ; chdir to root first
    mov ah,3Bh
    mov dx,rootstr
    int 21h
    ; if panel cwd is empty, we're done (at root)
    mov si,[bx+P_CWDPTR]
    mov al,[si]
    or al,al
    jz sc_done
    ; chdir into the stored relative path (DOS accepts multi-level "A\B\C")
    mov ah,3Bh
    mov dx,[bx+P_CWDPTR]
    int 21h
sc_done:
    pop si
    pop dx
    pop ax
    ret

; cwd_push: append directory name at SI as a new segment to active panel's cwd.
; Adds a backslash separator if the cwd is non-empty. Uses active panel.
cwd_push:
    push ax
    push cx
    push di
    push si                  ; save segment name pointer
    call cur_panel_ptr
    mov di,[bx+P_CWDPTR]
    ; find end of current cwd, counting chars
    mov cx,0
cp_findend:
    mov al,[di]
    or al,al
    jz cp_atend
    inc di
    inc cx
    jmp cp_findend
cp_atend:
    ; if non-empty, add separator backslash
    cmp cx,0
    je cp_copy
    mov al,92
    mov [di],al
    inc di
cp_copy:
    pop si                   ; restore segment name pointer
cp_cloop:
    mov al,[si]
    or al,al
    jz cp_cdone
    mov [di],al
    inc di
    inc si
    jmp cp_cloop
cp_cdone:
    mov byte [di],0
    pop di
    pop cx
    pop ax
    ret

; cwd_pop: remove the last "\segment" (or the only segment) from active panel cwd.
cwd_pop:
    push ax
    push di
    push si
    call cur_panel_ptr
    mov di,[bx+P_CWDPTR]
    ; find end
    mov si,di
cpp_findend:
    mov al,[si]
    or al,al
    jz cpp_scanback
    inc si
    jmp cpp_findend
cpp_scanback:
    ; si at terminator; walk back to last backslash or start
    cmp si,di
    je cpp_done              ; already empty
cpp_back:
    dec si
    cmp si,di
    je cpp_truncstart       ; reached start with no backslash -> whole thing goes
    mov al,[si]
    cmp al,92
    jne cpp_back
    ; si points at a backslash -> terminate here
    mov byte [si],0
    jmp cpp_done
cpp_truncstart:
    ; no backslash found: single segment, truncate to empty
    mov byte [di],0
cpp_done:
    pop si
    pop di
    pop ax
    ret

; copy_confirm: show a confirmation box with the file name and full source/
; destination paths. Returns AL=1 if the user confirms (ENTER/Y), AL=0 on
; cancel (ESC/N). Draws over the panels; caller redraws afterwards.
copy_confirm:
    ; --- top border + title ---
    mov word [outrow],8
    mov word [outcol],8
    call gotoxy
    mov dx,[esc_titlecol]
    call puts
    mov dx,cc_top
    call puts
    mov dx,[esc_reset]
    call puts
    ; --- line 9: "| Copy  <name>" (padded) ---
    mov word [outrow],9
    mov dx,[esc_sel]
    mov si,cc_l1              ; label ("| Copy  ")
    mov bx,[copyname]        ; variable text (filename)
    call dlg_line
    ; --- line 10: "| from  <srcpath>" ---
    mov word [outrow],10
    mov dx,[esc_dir]
    mov si,cc_l2
    mov bx,srcpath
    call dlg_line
    ; --- line 11: "| to    <dstpath>" ---
    mov word [outrow],11
    mov dx,[esc_dir]
    mov si,cc_l3
    mov bx,dstpath
    call dlg_line
    ; --- prompt line ---
    mov word [outrow],12
    mov word [outcol],8
    call gotoxy
    mov dx,[esc_titlecol]
    call puts
    mov dx,cc_prompt
    call puts
    mov dx,[esc_reset]
    call puts
    ; --- bottom border ---
    mov word [outrow],13
    mov word [outcol],8
    call gotoxy
    mov dx,[esc_titlecol]
    call puts
    mov dx,cc_bot
    call puts
    mov dx,[esc_reset]
    call puts
cc_key:
    call read_key
    cmp al,13                 ; ENTER = OK
    je cc_ok
    cmp al,'y'
    je cc_ok
    cmp al,'Y'
    je cc_ok
    cmp al,27                 ; ESC = cancel
    je cc_no
    cmp al,'n'
    je cc_no
    cmp al,'N'
    je cc_no
    cmp al,'q'
    je cc_no
    jmp cc_key
cc_ok:
    mov al,1
    ret
cc_no:
    mov al,0
    ret

; dlg_line: draw one dialog row inside the box, padded to the box width with a
; closing '|'. IN: outrow set, DX = color escape ptr, SI = label ASCIIZ
; (starts with "| "), BX = variable ASCIIZ text. Builds into dlgbuf then prints.
DLGW equ 43                   ; total inner width incl. both borders
dlg_line:
    push dx
    ; fill dlgbuf with spaces, closing '|' at DLGW-1, terminator after
    mov di,dlgbuf
    mov cx,DLGW
dl_fill:
    mov byte [di],' '
    inc di
    loop dl_fill
    mov byte [dlgbuf+DLGW-1],'|'
    mov byte [dlgbuf+DLGW],'$'  ; puts terminator
    ; copy label into start of dlgbuf
    mov di,dlgbuf
dl_lbl:
    mov al,[si]
    or al,al
    jz dl_lbldone
    mov [di],al
    inc di
    inc si
    jmp dl_lbl
dl_lbldone:
    ; append variable text (BX) after the label, stop before the closing '|'
    mov si,bx
dl_var:
    mov al,[si]
    or al,al
    jz dl_vardone
    ; guard: don't overrun into the closing border
    mov ax,di
    sub ax,dlgbuf
    cmp ax,DLGW-1
    jae dl_vardone
    mov al,[si]
    mov [di],al
    inc di
    inc si
    jmp dl_var
dl_vardone:
    ; position and print
    mov word [outcol],8
    call gotoxy
    pop dx                     ; color
    call puts                  ; color escape
    mov dx,dlgbuf
    call puts
    mov dx,[esc_reset]
    call puts
    ret


; Uses handle-based open/create/read/write. 512-byte buffer copybuf.
copy_file:
    ; open source read-only (AH=3Dh, AL=0)
    mov ax,3D00h
    mov dx,srcpath
    int 21h
    jc cf_fail
    mov [srchand],ax
    ; create dest (AH=3Ch, CX=0 normal attr) - truncates/creates
    mov ah,3Ch
    mov cx,0
    mov dx,dstpath
    int 21h
    jc cf_closesrc
    mov [dsthand],ax
cf_loop:
    ; read up to 512 bytes from source
    mov ah,3Fh
    mov bx,[srchand]
    mov cx,512
    mov dx,copybuf
    int 21h
    jc cf_closeboth
    ; AX = bytes read; 0 => EOF, done
    cmp ax,0
    je cf_done
    ; write AX bytes to dest
    mov cx,ax
    mov ah,40h
    mov bx,[dsthand]
    mov dx,copybuf
    int 21h
    jc cf_closeboth
    ; short write? (AX != CX) => disk full
    cmp ax,cx
    jne cf_closeboth
    jmp cf_loop
cf_done:
    mov ah,3Eh                ; close dest
    mov bx,[dsthand]
    int 21h
    mov ah,3Eh                ; close source
    mov bx,[srchand]
    int 21h
    clc
    ret
cf_closeboth:
    mov ah,3Eh
    mov bx,[dsthand]
    int 21h
cf_closesrc:
    mov ah,3Eh
    mov bx,[srchand]
    int 21h
cf_fail:
    stc
    ret

; copy_status_ok / _err: brief status line feedback in the status row
copy_status_ok:
    push dx
    mov word [outrow],23
    mov word [outcol],2
    call gotoxy
    mov dx,[esc_dir]
    call puts
    mov dx,msg_copyok
    call puts
    mov dx,[esc_reset]
    call puts
    pop dx
    ret
copy_status_err:
    push dx
    mov word [outrow],23
    mov word [outcol],2
    call gotoxy
    mov dx,[esc_sys]
    call puts
    mov dx,msg_copyerr
    call puts
    mov dx,[esc_reset]
    call puts
    pop dx
    ret

; ============================================================================
;  panel_load_bx
; ============================================================================
panel_load_bx:
    mov word [bx+P_CNT],0
    mov word [bx+P_SEL],0
    mov word [bx+P_TOP],0
    ; select this panel's drive as the DOS default
    mov ah,0Eh
    mov dl,[bx+P_DRIVE]
    int 21h
    ; make the DOS cwd match THIS panel's own cwd (panels on the same drive keep
    ; independent directories; DOS has only one cwd per drive, so we set it here)
    call sync_cwd
    mov ah,1Ah
    mov dx,dta
    int 21h
    ; clear the critical-error flag, then findfirst. If a not-ready disk trips
    ; INT 24h, our handler sets int24hit and returns IGNORE (no crash); we spot
    ; the flag and bail out, marking the drive not ready. This also caps any
    ; INT 24h recurrence at a single hit since we never loop after it fires.
    mov word [int24hit],0
    mov ah,4Eh
    mov cx,17h
    mov dx,allfiles
    int 21h
    jc pl_ff_carry           ; carry FIRST - before any cmp destroys it
    ; no carry: but a not-ready trip may have fired and returned IGNORE-success
    cmp word [int24hit],0
    jne pl_notready
    ; got a valid first entry - store it and continue
pl_next:
    call store_entry
    mov word [int24hit],0
    mov ah,4Fh
    int 21h
    jc pl_stop               ; carry = no more entries (check BEFORE any cmp)
    cmp word [int24hit],0    ; guard: did a not-ready trip fire mid-scan?
    jne pl_stop
    jmp pl_next
pl_ff_carry:
    ; findfirst carry: empty-but-ready dir, OR not-ready drive. Tell apart via flag.
    cmp word [int24hit],0
    jne pl_notready
    jmp pl_ready_empty
pl_stop:
    ; scan ended by carry. If flag fired mid-scan -> not ready, else ready.
    cmp word [int24hit],0
    jne pl_notready
pl_ready_empty:
    ; drive is ready (possibly empty dir). Mark READY.
    push ax
    mov al,[bx+P_DRIVE]
    mov ah,0
    mov si,drvstat
    add si,ax
    mov byte [si],DS_READY
    pop ax
    call sort_panel_bx       ; NC-Reihenfolge: ".." , Verzeichnisse, dann Dateien
    ret
pl_notready:
    ; INT 24h fired: drive not ready. Empty the panel, mark NOTRDY, re-stabilise
    ; DOS with a harmless high call, and let draw show the "(not ready)" banner.
    mov word [bx+P_CNT],0
    push ax
    mov al,[bx+P_DRIVE]
    mov ah,0
    mov si,drvstat
    add si,ax
    mov byte [si],DS_NOTRDY
    pop ax
    mov ah,19h               ; get current drive (>0Ch) - re-stabilise DOS
    int 21h
pl_done:
    ret
    ret

store_entry:
    mov si,dtaname
    mov al,[si]
    cmp al,'.'
    jne se_go
    mov al,[si+1]
    cmp al,0
    je se_ret
se_go:
    mov ax,[bx+P_CNT]
    cmp ax,MAXENT
    jae se_ret
    mov cx,ENTSZ
    mul cx
    mov di,ax
    add di,bx
    add di,P_DATA             ; DI = entry base
    push di
    mov si,dtaname
    mov cx,13
se_cl:
    mov al,[si]
    mov [di],al
    or al,al
    jz se_attr
    inc si
    inc di
    dec cx
    jnz se_cl
se_attr:
    pop di                    ; DI = entry base again
    mov al,[dtaattr]
    mov [di+E_ATTR],al        ; attr
    ; copy dword size (DTA_SIZE..+3) to entry E_SIZE
    mov ax,[dtasize]
    mov [di+E_SIZE],ax
    mov ax,[dtasize+2]
    mov [di+E_SIZE+2],ax
    ; copy word date to entry E_DATE
    mov ax,[dtadate]
    mov [di+E_DATE],ax
    mov ax,[bx+P_CNT]
    inc ax
    mov [bx+P_CNT],ax
se_ret:
    ret

; ============================================================================
;  sort_panel_bx - Eintraege in Panel BX in NC-Reihenfolge bringen:
;  zuerst ".." , dann Verzeichnisse (alphabetisch), dann Dateien (alphabetisch).
;  Einfacher Insertion-Sort direkt auf dem 20-Byte-Eintragsfeld; bei bis zu
;  128 Eintraegen voellig ausreichend und leicht korrekt zu halten.
;  BX = Panel-Basis. Erhaelt BX.
; ============================================================================
sort_panel_bx:
    push bx
    push si
    push di
    mov cx,[bx+P_CNT]
    cmp cx,2
    jb sp_done               ; 0 oder 1 Eintrag -> nichts zu tun
    ; DI laeuft von Eintrag 1 bis N-1 (der "einzusortierende")
    mov word [sp_i],1
sp_outer:
    mov ax,[sp_i]
    cmp ax,[bx+P_CNT]
    jae sp_done
    ; aktuellen Eintrag i nach sortbuf kopieren (der "Schluessel")
    mov ax,[sp_i]
    call ent_addr            ; SI = Adresse Eintrag i
    mov di,sortbuf
    mov cx,ENTSZ
    call copy20
    ; j = i-1; solange j>=0 und entry[j] > key: entry[j+1]=entry[j]; j--
    mov ax,[sp_i]
    dec ax
    mov [sp_j],ax
sp_inner:
    cmp word [sp_j],0
    jl sp_place              ; j < 0 -> Platz gefunden
    ; vergleiche entry[j] (SI) mit key (sortbuf)
    mov ax,[sp_j]
    call ent_addr            ; SI = entry[j]
    mov di,sortbuf
    call entry_gt            ; CF=1 wenn entry[j] > key
    jnc sp_place
    ; entry[j] > key -> nach entry[j+1] schieben
    mov ax,[sp_j]
    call ent_addr            ; SI = entry[j] (Quelle)
    mov ax,[sp_j]
    inc ax
    call ent_addr_di         ; DI = entry[j+1] (Ziel)
    mov cx,ENTSZ
    call copy20
    dec word [sp_j]
    jmp sp_inner
sp_place:
    ; key nach entry[j+1]
    mov ax,[sp_j]
    inc ax
    call ent_addr_di         ; DI = entry[j+1]
    mov si,sortbuf
    mov cx,ENTSZ
    call copy20
    inc word [sp_i]
    jmp sp_outer
sp_done:
    pop di
    pop si
    pop bx
    ret

; ent_addr: SI = Adresse von Eintrag AX in Panel BX
ent_addr:
    push ax
    push dx
    mov dx,ENTSZ
    mul dx
    mov si,ax
    add si,bx
    add si,P_DATA
    pop dx
    pop ax
    ret

; ent_addr_di: DI = Adresse von Eintrag AX in Panel BX
ent_addr_di:
    push ax
    push dx
    mov dx,ENTSZ
    mul dx
    mov di,ax
    add di,bx
    add di,P_DATA
    pop dx
    pop ax
    ret

; copy20: CX Bytes von DS:SI nach DS:DI. Erhaelt nichts ausser Flags egal.
copy20:
    push ax
cp20_l:
    mov al,[si]
    mov [di],al
    inc si
    inc di
    dec cx
    jnz cp20_l
    pop ax
    ret

; entry_gt: vergleicht Eintrag bei SI ("A") mit Eintrag bei DI ("B").
; Setzt CF=1, wenn A > B in NC-Reihenfolge (A gehoert HINTER B), sonst CF=0.
; Ordnung: Rang 0=".." , 1=Verzeichnis, 2=Datei. Bei gleichem Rang: Name
; alphabetisch (grossschrift-normalisiert). Erhaelt SI/DI nicht noetig.
entry_gt:
    push ax
    push bx
    push cx
    push si
    push di
    ; Rang von A nach BL, Rang von B nach BH
    call entry_rank          ; AL = Rang(SI)
    mov bl,al
    xchg si,di
    call entry_rank          ; AL = Rang(di jetzt in SI)
    mov bh,al
    xchg si,di               ; SI=A, DI=B wiederherstellen
    cmp bl,bh
    ja eg_true               ; Rang(A) > Rang(B) -> A hinter B
    jb eg_false              ; Rang(A) < Rang(B) -> A vor B
    ; gleicher Rang -> Namen vergleichen (SI=A-Name, DI=B-Name, ASCIIZ)
eg_cmp:
    mov al,[si]
    mov ah,[di]
    call upcase_al
    xchg al,ah
    call upcase_al
    xchg al,ah               ; AL=upper(A-Zeichen), AH=upper(B-Zeichen)
    cmp al,ah
    ja eg_true               ; A-Zeichen groesser -> A hinter B
    jb eg_false
    ; gleich: Ende erreicht?
    or al,al
    jz eg_false              ; beide zu Ende, gleich -> nicht ">" (stabil)
    inc si
    inc di
    jmp eg_cmp
eg_true:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    stc
    ret
eg_false:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    clc
    ret

; entry_rank: AL = Sortierrang des Eintrags bei SI.
;   0 = ".."  1 = Verzeichnis  2 = Datei
entry_rank:
    push bx
    ; ".."? Name[0]='.' und Name[1]='.'
    mov al,[si]
    cmp al,'.'
    jne er_notdd
    mov al,[si+1]
    cmp al,'.'
    jne er_notdd
    mov al,0
    jmp er_done
er_notdd:
    mov al,[si+E_ATTR]
    test al,10h
    jz er_file
    mov al,1                 ; Verzeichnis
    jmp er_done
er_file:
    mov al,2                 ; Datei
er_done:
    pop bx
    ret

; upcase_al: AL -> Grossbuchstabe, falls a-z
upcase_al:
    cmp al,'a'
    jb uc_ret
    cmp al,'z'
    ja uc_ret
    sub al,20h
uc_ret:
    ret

; ============================================================================
;  drawing
; ============================================================================
draw_all:
    call cls
    call draw_title
    mov bx,LEFT
    call draw_frame_bx
    call draw_panel_bx
    mov bx,RIGHT
    call draw_frame_bx
    call draw_panel_bx
    call draw_status
    ret

draw_title:
    mov word [outrow],1
    mov word [outcol],1
    call gotoxy
    mov dx,[esc_titlecol]
    call puts
    mov dx,titletxt
    call puts
    mov dx,[esc_reset]
    call puts
    ret

; draw the box frame for panel BX (border + path header + count footer)
draw_frame_bx:
    push bx
    ; choose left/right border columns
    mov ax,bx
    cmp ax,LEFT
    jne df_r
    mov word [blcol],LBORD
    mov word [brcol],LBORDR
    jmp df_cs
df_r:
    mov word [blcol],RBORD
    mov word [brcol],RBORDR
df_cs:
    ; --- top border row: + ---- ... ---- + ---
    mov ax,TOPROW
    mov [outrow],ax
    mov ax,[blcol]
    mov [outcol],ax
    call gotoxy
    call frame_color
    mov al,'+'
    call putc
    ; horizontal dashes across interior width (brcol-blcol-1)
    mov cx,[brcol]
    sub cx,[blcol]
    dec cx
    call put_dashes
    mov al,'+'
    call putc
    ; --- side borders for each list row ---
    mov word [rowi],0
df_side:
    mov ax,[rowi]
    cmp ax,LISTROWS
    jae df_sidedone
    mov ax,[rowi]
    add ax,TOPROW
    inc ax                  ; first list row = TOPROW+1
    mov [outrow],ax
    ; left border char
    mov ax,[blcol]
    mov [outcol],ax
    call gotoxy
    mov al,'|'
    call putc
    ; right border char
    mov ax,[brcol]
    mov [outcol],ax
    call gotoxy
    mov al,'|'
    call putc
    mov ax,[rowi]
    inc ax
    mov [rowi],ax
    jmp df_side
df_sidedone:
    ; --- bottom border row ---
    mov ax,BOTROW
    mov [outrow],ax
    mov ax,[blcol]
    mov [outcol],ax
    call gotoxy
    mov al,'+'
    call putc
    mov cx,[brcol]
    sub cx,[blcol]
    dec cx
    call put_dashes
    mov al,'+'
    call putc
    ; --- path header in top border: overwrite at blcol+2 ---
    mov ax,TOPROW
    mov [outrow],ax
    mov ax,[blcol]
    add ax,2
    mov [outcol],ax
    call gotoxy
    mov al,' '
    call putc
    ; current drive+dir
    call print_cwd
    mov al,' '
    call putc
    mov dx,[esc_reset]
    call puts
    ; --- count footer in bottom border at blcol+2 ---
    mov ax,BOTROW
    mov [outrow],ax
    mov ax,[blcol]
    add ax,2
    mov [outcol],ax
    call gotoxy
    call frame_color
    mov al,' '
    call putc
    mov ax,[bx+P_CNT]
    call put_dec
    mov dx,ftfiles
    call puts
    mov dx,[esc_reset]
    call puts
    pop bx
    ret

; print CX dashes
put_dashes:
    mov al,'-'
    call putc
    loop put_dashes
    ret

; frame color: dim-ish (use file color / normal)
frame_color:
    mov dx,[esc_file]
    call puts
    ret

; print current working directory (drive-relative) into the frame header
print_cwd:
    ; BX = panel base. Print drive letter (white) + ":\" + this panel's own dir.
    push bx
    ; drive letter in white
    mov dx,esc_white
    call puts
    mov al,[bx+P_DRIVE]
    add al,'A'
    call putc
    mov dx,[esc_reset]
    call puts
    mov al,':'
    call putc
    mov al,92                ; backslash
    call putc
    ; print this panel's own cwd string
    mov si,[bx+P_CWDPTR]
pc_l:
    mov al,[si]
    or al,al
    jz pc_done
    call putc
    inc si
    jmp pc_l
pc_done:
    pop bx
    ret

draw_panel_bx:
    push bx
    mov ax,bx
    cmp ax,LEFT
    jne dp_r
    mov word [curcol],LCOL
    jmp dp_cs
dp_r:
    mov word [curcol],RCOL
dp_cs:
    mov word [bannershown],0
    ; if panel is empty AND its drive is not ready, show a banner
    cmp word [bx+P_CNT],0
    jne dp_loopstart
    mov al,[bx+P_DRIVE]
    mov ah,0
    mov si,drvstat
    add si,ax
    mov al,[si]
    cmp al,DS_READY
    je dp_loopstart
    ; draw "(drive not ready)" on the first list row
    mov ax,TOPROW
    inc ax
    mov [outrow],ax
    mov ax,[curcol]
    mov [outcol],ax
    call gotoxy
    mov dx,[esc_sys]
    call puts
    mov dx,notrdytxt
    call puts
    mov dx,[esc_reset]
    call puts
    mov word [bannershown],1
dp_loopstart:
    mov word [rowi],0
dp_row:
    mov ax,[rowi]
    cmp ax,LISTROWS
    jae dp_done
    mov ax,[rowi]
    add ax,TOPROW
    inc ax                  ; first list row = TOPROW+1 = 3
    mov [outrow],ax
    mov ax,[curcol]
    mov [outcol],ax
    call gotoxy
    mov ax,[bx+P_TOP]
    add ax,[rowi]
    mov [entidx],ax
    cmp ax,[bx+P_CNT]
    jae dp_blank
    mov ax,[entidx]
    cmp ax,[bx+P_SEL]
    jne dp_norm
    call is_active_bx
    jc dp_norm
    mov word [selflag],1
    mov dx,[esc_sel]
    call puts
    call print_entry
    mov word [selflag],0
    mov dx,[esc_reset]
    call puts
    jmp dp_re
dp_norm:
    mov word [selflag],0
    call print_entry
    jmp dp_re
dp_blank:
    ; don't overwrite the not-ready banner on row 0
    cmp word [bannershown],0
    je dp_dopad
    cmp word [rowi],0
    je dp_re
dp_dopad:
    call print_pad
dp_re:
    mov ax,[rowi]
    inc ax
    mov [rowi],ax
    jmp dp_row
dp_done:
    pop bx
    ret

; print entry [entidx] of panel BX padded to PANW.
; Directories: name UPPERCASE. Files: name lowercase. System files: '*' before ext.
print_entry:
    push bx
    mov ax,[entidx]
    mov cx,ENTSZ
    mul cx
    mov si,ax
    add si,bx
    add si,P_DATA
    ; attr in [si+13]
    mov al,[si+13]
    mov [curattr],al
    ; if this is the selected row, DON'T emit a per-type color (use sel colors)
    cmp word [selflag],0
    jne pe_colordone
    test al,10h
    jz pe_isfile
    ; directory: bold/bright + uppercase
    push si
    mov dx,[esc_dir]
    call puts
    pop si
    jmp pe_colordone
pe_isfile:
    ; system or hidden file? mark it
    push si
    mov al,[curattr]
    test al,06h              ; system(4)|hidden(2)
    jz pe_filecol
    mov dx,[esc_sys]
    call puts
    jmp pe_start2
pe_filecol:
    mov dx,[esc_file]
    call puts
pe_start2:
    pop si
pe_colordone:
    ; set isdir flag regardless (needed for case + slash)
    mov al,[curattr]
    test al,10h
    jz pe_notdir2
    mov word [isdir],1
    jmp pe_start
pe_notdir2:
    mov word [isdir],0
pe_start:
    mov word [pcount],0
    ; copy name, applying case transform, and detect '.' for sysmarker
pe_ch:
    mov al,[si]
    or al,al
    jz pe_dirslash
    ; case transform
    cmp word [isdir],0
    je pe_lower
    ; dir: uppercase A-Z (already usually upper from DOS; force)
    call toupper
    jmp pe_emit
pe_lower:
    call tolower
pe_emit:
    ; system-file marker: put '*' just before the extension dot
    cmp word [isdir],0
    jne pe_putc
    mov ah,[curattr]
    test ah,06h
    jz pe_putc
    cmp al,'.'
    jne pe_putc
    ; about to print '.', prefix with '*'
    push ax
    mov al,'*'
    call putc
    mov ax,[pcount]
    inc ax
    mov [pcount],ax
    pop ax
pe_putc:
    ; stop copying the name once we've filled the name column
    push ax                  ; preserve the char in AL
    mov ax,[pcount]
    cmp ax,NAMEW
    pop ax
    jae pe_namedone
    call putc                 ; AL still holds the char
    inc si
    push ax
    mov ax,[pcount]
    inc ax
    mov [pcount],ax
    pop ax
    jmp pe_ch
pe_dirslash:
    cmp word [isdir],0
    je pe_padname
    mov ax,[pcount]
    cmp ax,NAMEW
    jae pe_padname
    mov al,92                ; backslash marks a dir
    call putc
    mov ax,[pcount]
    inc ax
    mov [pcount],ax
pe_padname:
    ; pad name field out to NAMEW
    mov ax,[pcount]
    cmp ax,NAMEW
    jae pe_cols
    mov al,' '
    call putc
    mov ax,[pcount]
    inc ax
    mov [pcount],ax
    jmp pe_padname
pe_namedone:
    ; name longer than column: swallow the rest of the name bytes
    mov al,[si]
    or al,al
    jz pe_cols
    inc si
    jmp pe_namedone
pe_cols:
    ; --- size column (9 wide, right aligned) : <DIR> or decimal bytes ---
    call print_size_col
    mov al,' '
    call putc
    ; --- date column (8 wide: MM-DD-YY) ---
    call print_date_col
    ; pad remaining cells out to PANW (NAMEW+1+9+1+8 = 35 -> pad 2)
    mov cx,PANW
    sub cx,NAMEW
    sub cx,19                ; 9 size +1 sp +8 date +1 sp already emitted
pe_tailpad:
    cmp cx,0
    jle pe_end
    mov al,' '
    call putc
    dec cx
    jmp pe_tailpad
pe_end:
    mov dx,[esc_reset]
    call puts
    pop bx
    ret

; print the size column, 9 chars wide, right-aligned.
; SI still points into the entry name; use [entidx] entry base for fields.
print_size_col:
    push si
    mov cx,[isdir]
    or cx,cx
    jz psc_file
    ; directory -> "    <DIR>"
    mov dx,txt_dir
    call puts
    pop si
    ret
psc_file:
    ; load dword size from entry
    call entry_base_si       ; SI = entry base
    mov ax,[si+E_SIZE]
    mov dx,[si+E_SIZE+2]
    ; convert DX:AX to decimal into numbuf (right side), get length
    call udword_to_dec       ; fills numbuf, sets numlen
    ; right-align in 9 cols: print (9-numlen) spaces then the number
    mov cx,9
    sub cx,[numlen]
    jbe psc_print
psc_sp:
    mov al,' '
    call putc
    dec cx
    jnz psc_sp
psc_print:
    mov si,numbuf
    mov cx,[numlen]
psc_pl:
    mov al,[si]
    call putc
    inc si
    dec cx
    jnz psc_pl
    pop si
    ret

; print the date column MM-DD-YY from entry E_DATE
print_date_col:
    push si
    call entry_base_si
    mov ax,[si+E_DATE]
    ; day = bits 0-4, month = bits 5-8, year = 1980 + bits 9-15
    mov bx,ax
    ; month:
    mov ax,bx
    mov cl,5
    shr ax,cl
    and ax,0Fh
    call put2
    mov al,'-'
    call putc
    ; day:
    mov ax,bx
    and ax,1Fh
    call put2
    mov al,'-'
    call putc
    ; year (mod 100):
    mov ax,bx
    mov cl,9
    shr ax,cl
    and ax,7Fh               ; years since 1980
    add ax,80                ; -> 2-digit yy (1980->80, 2000->100)
pd_ymod:
    cmp ax,100
    jb pd_yok
    sub ax,100
    jmp pd_ymod
pd_yok:
    call put2
    pop si
    ret

; SI <- base address of entry [entidx] in panel BX
entry_base_si:
    push ax
    push cx
    mov ax,[entidx]
    mov cx,ENTSZ
    mul cx
    mov si,ax
    add si,bx
    add si,P_DATA
    pop cx
    pop ax
    ret

; print AL (0..99) as two decimal digits
put2:
    push ax
    push bx
    mov ah,0
    mov bl,10
    div bl                   ; AL=tens, AH=ones
    push ax
    add al,'0'
    call putc
    pop ax
    mov al,ah
    add al,'0'
    call putc
    pop bx
    pop ax
    ret

; convert DX:AX (unsigned 32-bit) to decimal string in numbuf, length in numlen
udword_to_dec:
    push bx
    push cx
    push si
    push di
    mov di,numtmp            ; build reversed here
    mov cx,0                 ; digit count
    ; if value is zero, emit '0'
    mov bx,ax
    or bx,dx
    jnz ud_loop
    mov byte [di],'0'
    mov cx,1
    jmp ud_copy
ud_loop:
    ; divide DX:AX by 10 -> quotient DX:AX, remainder in BX
    call div32_10
    add bl,'0'
    mov [di],bl
    inc di
    inc cx
    mov bx,ax
    or bx,dx
    jnz ud_loop
ud_copy:
    ; reverse numtmp (cx digits) into numbuf
    mov [numlen],cx
    mov si,di
    dec si                   ; last written
    mov di,numbuf
    ; if zero case, di already has '0' at numtmp; handle uniformly:
    cmp cx,0
    je ud_done
ud_rev:
    mov al,[si]
    mov [di],al
    dec si
    inc di
    dec cx
    jnz ud_rev
ud_done:
    pop di
    pop si
    pop cx
    pop bx
    ret

; DX:AX / 10 -> quotient in DX:AX, remainder in BX (0..9)
div32_10:
    push cx
    push ax                  ; save low word
    mov ax,dx                ; AX = high word
    xor dx,dx
    mov cx,10
    div cx                   ; AX = high/10, DX = rem_high
    mov bx,ax                ; BX = quotient high
    pop ax                   ; AX = original low word
    ; DX:AX = rem_high:low ; divide by 10
    div cx                   ; AX = low quotient, DX = remainder
    mov cx,dx                ; CX = final remainder
    mov dx,bx                ; DX = quotient high
    mov bx,cx                ; BX = remainder
    pop cx
    ret

print_pad:
    mov cx,PANW
pp_l:
    mov al,' '
    call putc
    loop pp_l
    ret

draw_status:
    mov word [outrow],24
    mov word [outcol],1
    call gotoxy
    mov dx,[esc_titlecol]
    call puts
    mov dx,statustxt
    call puts
    mov dx,[esc_reset]
    call puts
    ret

; ============================================================================
;  color control
; ============================================================================
; setcolor: choose palette strings based on monoflag.
; Color mode: title/status = bright yellow on blue; sel = black on cyan;
;   dir = bright white(bold); file = green; sys = bright red.
; Mono mode (half-intensity trick): everything green; dir=bold(full),
;   file=normal, sys=blink, sel=reverse. We just switch the pointer table.
setcolor:
    cmp word [monoflag],0
    je sc_color
    ; mono palette
    mov word [esc_reset],esc_monodef
    mov word [esc_titlecol],mono_title
    mov word [esc_sel],mono_sel
    mov word [esc_dir],mono_dir
    mov word [esc_file],mono_file
    mov word [esc_sys],mono_sys
    ret
sc_color:
    mov word [esc_reset],esc_defcol
    mov word [esc_titlecol],col_title
    mov word [esc_sel],col_sel
    mov word [esc_dir],col_dir
    mov word [esc_file],col_file
    mov word [esc_sys],col_sys
    ret

setnormal:
    mov dx,[esc_reset]
    call puts
    ret

; ============================================================================
;  helpers
; ============================================================================
toupper:
    cmp al,'a'
    jb tu_ret
    cmp al,'z'
    ja tu_ret
    sub al,20h
tu_ret:
    ret
tolower:
    cmp al,'A'
    jb tl_ret
    cmp al,'Z'
    ja tl_ret
    add al,20h
tl_ret:
    ret

is_active_bx:
    push ax
    push cx
    mov ax,bx
    mov cx,LEFT
    cmp word [actpanel],0
    je iab_c
    mov cx,RIGHT
iab_c:
    cmp ax,cx
    jne iab_no
    clc
    jmp iab_e
iab_no:
    stc
iab_e:
    pop cx
    pop ax
    ret

cur_panel_ptr:
    mov bx,LEFT
    cmp word [actpanel],0
    je cpp_e
    mov bx,RIGHT
cpp_e:
    ret

sel_entry_ptr:
    call cur_panel_ptr
    mov ax,[bx+P_SEL]
    mov cx,ENTSZ
    mul cx
    mov si,ax
    add si,bx
    add si,P_DATA
    ret

do_chdir:
    ; select active panel's drive so chdir affects the right drive
    push ax
    push bx
    push dx
    call cur_panel_ptr
    mov ah,0Eh
    mov dl,[bx+P_DRIVE]
    int 21h
    pop dx
    pop bx
    pop ax
    mov ah,3Bh
    int 21h
    ret

; ============================================================================
;  critical-error (INT 24h) handling  +  drive probing
; ============================================================================
; Our INT 24h handler: DOS calls this when a drive is not ready / has an I/O
; error, INSTEAD of any application code. It runs on the DOS stack with the
; failing request in registers. We record that it fired and return AL=2
; (ABORT) which, on DOS 2.x, returns control to DOS right after the INT 21h
; that faulted, with carry set - no "Abort, Retry, Ignore?" prompt, no screen
; corruption. (DOS 2.11 has no FAIL=3 option, so ABORT is the safe choice.)
; Our INT 24h handler. The v8.1 stack-unwinding version crashed on the real
; DMV (its saved-register frame differs from the documented layout), so we use
; the only crash-proof option: return AL=0 (IGNORE). IGNORE never terminates
; the program (unlike ABORT=2) and never loops (unlike RETRY=1) - DOS simply
; proceeds as if the failed I/O had succeeded. On its own that would give a
; garbage/empty result, so IGNORE is paired with the rule that we never issue
; a media access on a drive we haven't already confirmed is ready. The handler
; just records that it fired (so callers can tell), preserves everything, and
; returns IGNORE. It touches no registers except AL and does no DOS calls.
my_int24:
    mov word [cs:int24hit],1
    xor al,al                ; AL=0 = IGNORE (crash-proof on DOS 2.x)
    iret

install_int24:
    push ax
    push bx
    push dx
    push es
    ; save current INT 24h vector
    mov ax,3524h
    int 21h                  ; ES:BX = old vector
    mov [oldint24off],bx
    mov [oldint24seg],es
    ; set our vector (DS already = CS for a .COM)
    mov ax,2524h
    mov dx,my_int24
    int 21h
    pop es
    pop dx
    pop bx
    pop ax
    ret

restore_int24:
    push ax
    push dx
    push ds
    mov dx,[oldint24off]
    mov ax,[oldint24seg]
    mov ds,ax
    mov ax,2524h
    int 21h
    pop ds
    pop dx
    pop ax
    ret

; probe_one: test drive AL (0=A). Returns AL = DS_ABSENT/READY/NOTRDY.
; Uses AH=36h (Get Disk Free Space) first: this validates the drive letter
; WITHOUT touching the media (returns AX=FFFF for an invalid/unassigned drive).
; If valid, we try a findfirst with our INT24 handler armed; a not-ready disk
; trips INT24 -> handler sets int24hit and aborts -> we report NOTRDY, with no
; DOS prompt shown.
probe_one:
    push bx
    push cx
    push dx
    push si
    push di
    mov [probedrv],al
    ; AH=36h wants DL = 1-based drive (1=A)
    mov dl,[probedrv]
    inc dl
    mov ah,36h
    int 21h
    cmp ax,0FFFFh
    jne po_valid
    mov al,DS_ABSENT
    jmp po_done
po_valid:
    ; drive letter exists. Now check media via findfirst, handler armed.
    ; select it as default so findfirst uses it
    mov dl,[probedrv]
    mov ah,0Eh
    int 21h
    mov ah,1Ah
    mov dx,probedta
    int 21h
    mov word [int24hit],0
    mov ah,4Eh
    mov cx,16h               ; include dir/system/hidden so even an empty-ish disk matches
    mov dx,allfiles
    int 21h
    ; if our handler fired, DOS is mildly unstable until a fn > 0Ch runs.
    ; Issue AH=19h (get current drive) to re-stabilise before anything else.
    mov ah,19h
    int 21h
    ; either carry set (nothing found / aborted) or int24hit set => decide
    mov al,[int24hit+0]      ; low byte of the word flag
    or al,al
    jz po_ready              ; handler never fired -> media present
    mov al,DS_NOTRDY
    jmp po_done
po_ready:
    mov al,DS_READY
po_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

; probe_drives (startup): determine how many logical drives exist WITHOUT
; any media access. INT 21h AH=0Eh (Select Default Drive) returns AL = number
; of logical drives - no disk is touched. We mark each existing drive UNKNOWN
; (media probed lazily when the user actually opens the drive menu) and restore
; the original default drive. This keeps startup safe: the only drive we ever
; read at boot is the default one, which is ready by definition (we booted).
probe_drives:
    push ax
    push bx
    push cx
    ; remember current default drive
    mov ah,19h
    int 21h
    mov [savedrv],al
    ; AH=0Eh with the current drive returns AL = number of logical drives
    mov dl,[savedrv]
    mov ah,0Eh
    int 21h                  ; AL = drive count
    mov ah,0
    ; clamp to MAXPROBE (DOS 2.x may report LASTDRIVE=5 by default)
    cmp al,MAXPROBE
    jbe pd_okcnt
    mov al,MAXPROBE
pd_okcnt:
    mov [drivecount],ax
    ; mark drives 0..count-1 UNKNOWN, rest ABSENT
    mov bx,0
pd_loop:
    mov si,drvstat
    add si,bx
    cmp bx,[drivecount]
    jae pd_absent
    mov byte [si],DS_UNKNOWN
    jmp pd_next
pd_absent:
    mov byte [si],DS_ABSENT
pd_next:
    inc bx
    cmp bx,MAXPROBE
    jb pd_loop
    ; the default drive is certainly ready
    mov al,[savedrv]
    mov ah,0
    mov si,drvstat
    add si,ax
    mov byte [si],DS_READY
    ; restore default drive (AH=0Eh already left it selected; ensure it)
    mov dl,[savedrv]
    mov ah,0Eh
    int 21h
    pop cx
    pop bx
    pop ax
    ret

; ============================================================================
;  drive submenu (NC-style)  -> returns AL = chosen ready drive, or 0FFh
; ============================================================================
; Draws a centered box listing every present drive (A.. up to MAXPROBE),
; ready drives in normal color, not-ready dimmed. j/k move, ENTER selects,
; ESC/q cancels. Choosing a not-ready drive raises the not-ready prompt.
drive_menu:
    ; build a list of present drive numbers into menudrv[], count in menucnt.
    ; We do NOT probe media here - touching an empty drive risks an INT 24h
    ; storm. Drives are shown by existence only; readiness is discovered when
    ; the user actually selects one and panel_load_bx tries to read it.
    mov word [menucnt],0
    mov bx,0
dm_build:
    cmp bx,MAXPROBE
    jae dm_built
    mov si,drvstat
    add si,bx
    mov al,[si]
    cmp al,DS_ABSENT
    je dm_bnext
    mov di,menudrv
    add di,[menucnt]
    mov [di],bl              ; store drive number
    inc word [menucnt]
dm_bnext:
    inc bx
    jmp dm_build
dm_built:
    cmp word [menucnt],0
    jne dm_have
    mov al,0FFh              ; no drives at all - cancel
    ret
dm_have:
    mov word [menusel],0
dm_redraw:
    call draw_drive_menu
dm_key:
    call read_key
    cmp al,'k'
    je dm_up
    cmp al,05h               ; ^E up
    je dm_up
    cmp al,'j'
    je dm_down
    cmp al,18h               ; ^X down
    je dm_down
    cmp al,13
    je dm_enter
    cmp al,27                ; ESC
    je dm_esc
    cmp al,'q'
    je dm_esc
    jmp dm_key
dm_up:
    mov ax,[menusel]
    or ax,ax
    jz dm_key
    dec ax
    mov [menusel],ax
    jmp dm_redraw
dm_down:
    mov ax,[menusel]
    inc ax
    cmp ax,[menucnt]
    jae dm_key
    mov [menusel],ax
    jmp dm_redraw
dm_esc:
    mov al,0FFh
    ret
dm_enter:
    ; return the selected drive number. We do NOT pre-probe it here (that would
    ; touch possibly-empty media). panel_load_bx will try to read it and fall
    ; back to the "(drive not ready)" banner if it turns out empty.
    mov di,menudrv
    add di,[menusel]
    mov al,[di]
    ret

; draw the drive menu box centered-ish (rows 8..) over the panels
draw_drive_menu:
    ; frame at row 8, col 28, width ~22
    mov word [outrow],8
    mov word [outcol],28
    call gotoxy
    mov dx,[esc_titlecol]
    call puts
    mov dx,dmtop
    call puts
    mov dx,[esc_reset]
    call puts
    ; one row per drive
    mov word [rowi],0
ddm_row:
    mov ax,[rowi]
    cmp ax,[menucnt]
    jae ddm_done
    mov ax,[rowi]
    add ax,9
    mov [outrow],ax
    mov word [outcol],28
    call gotoxy
    ; selected?
    mov ax,[rowi]
    cmp ax,[menusel]
    jne ddm_norm
    mov dx,[esc_sel]
    call puts
    jmp ddm_body
ddm_norm:
    mov dx,[esc_reset]
    call puts
ddm_body:
    mov al,'|'
    call putc
    mov al,' '
    call putc
    ; drive letter
    mov si,menudrv
    add si,[rowi]
    mov al,[si]
    push ax
    add al,'A'
    call putc
    mov al,':'
    call putc
    mov al,' '
    call putc
    ; status text
    pop ax                    ; AL = drive number
    mov ah,0
    mov si,drvstat
    add si,ax
    mov al,[si]
    cmp al,DS_READY
    jne ddm_notready_q
    mov dx,dmready
    call puts
    jmp ddm_pad
ddm_notready_q:
    cmp al,DS_NOTRDY
    jne ddm_unknown
    mov dx,dmnotrdy
    call puts
    jmp ddm_pad
ddm_unknown:
    mov dx,dmunknown
    call puts
ddm_pad:
    mov al,'|'
    call putc
    mov dx,[esc_reset]
    call puts
    mov ax,[rowi]
    inc ax
    mov [rowi],ax
    jmp ddm_row
ddm_done:
    ; bottom border + hint
    mov ax,[menucnt]
    add ax,9
    mov [outrow],ax
    mov word [outcol],28
    call gotoxy
    mov dx,[esc_titlecol]
    call puts
    mov dx,dmbot
    call puts
    mov dx,[esc_reset]
    call puts
    ret

; NC-style "disk not ready" prompt. Returns AL=1 (retry) or AL=0 (cancel).
notready_prompt:
    mov word [outrow],22
    mov word [outcol],10
    call gotoxy
    mov dx,[esc_sys]
    call puts
    mov dx,nrmsg1
    call puts
    ; insert drive letter
    mov al,[menupick]
    add al,'A'
    call putc
    mov dx,nrmsg2
    call puts
    mov dx,[esc_reset]
    call puts
nrp_key:
    call read_key
    cmp al,'r'
    je nrp_retry
    cmp al,'R'
    je nrp_retry
    cmp al,'s'
    je nrp_sel
    cmp al,'S'
    je nrp_sel
    cmp al,27
    je nrp_sel
    jmp nrp_key
nrp_retry:
    mov al,1
    ret
nrp_sel:
    mov al,0
    ret

gotoxy:
    push bx
    mov dx,esc_lb
    call puts
    mov ax,[outrow]
    call put_dec
    mov al,';'
    call putc
    mov ax,[outcol]
    call put_dec
    mov al,'H'
    call putc
    pop bx
    ret

put_dec:
    mov cx,ax
    mov ax,cx
    mov bl,100
    div bl
    mov dh,ah
    mov bh,al
    cmp bh,0
    je pd_t
    mov al,bh
    add al,'0'
    call putc
pd_t:
    mov al,dh
    mov ah,0
    mov bl,10
    div bl
    mov bl,al
    cmp bh,0
    jne pd_pt
    cmp bl,0
    je pd_u
pd_pt:
    mov al,bl
    add al,'0'
    call putc
pd_u:
    mov al,ah
    add al,'0'
    call putc
    ret

cls:
    mov dx,esc_cls
    call puts
    ret

puts:
    mov ah,9
    int 21h
    ret

; putz: print an ASCIIZ string at DS:SI (used for the built path strings)
putz:
    push ax
putz_l:
    mov al,[si]
    or al,al
    jz putz_done
    call putc
    inc si
    jmp putz_l
putz_done:
    pop ax
    ret

putc:
    push ax
    push dx
    mov dl,al
    mov ah,2
    int 21h
    pop dx
    pop ax
    ret

read_key:
    mov ah,7
    int 21h
    ret

; ============================================================================
;  data
; ============================================================================
esc_cls:   db 27,'[2J',27,'[H$'
esc_lb:    db 27,'[$'
esc_norm:  db 27,'[0m$'
esc_white: db 27,'[1;37m$'           ; bright white (drive letter)
esc_defcol: db 27,'[0;32;40m$'      ; explicit default: normal, green fg, black bg
esc_monodef: db 27,'[0m$'           ; mono default (no color)

; palette pointer variables (patched by setcolor). Each holds a $-string addr.
esc_titlecol: dw col_title
esc_sel:      dw col_sel
esc_dir:      dw col_dir
esc_file:     dw col_file
esc_sys:      dw col_sys
esc_reset:    dw esc_defcol

; --- COLOR palette ($-terminated ANSI SGR strings) ---
col_title: db 27,'[1;33;44m$'     ; bright yellow on blue
col_sel:   db 27,'[1;30;46m$'     ; bright black on cyan (selection bar)
col_dir:   db 27,'[1;37m$'        ; bright white (directories)
col_file:  db 27,'[0;32m$'        ; green (normal files)
col_sys:   db 27,'[1;31m$'        ; bright red (system/hidden files)

; --- MONO palette (half-intensity display) ---
mono_title: db 27,'[7m$'          ; reverse
mono_sel:   db 27,'[7m$'          ; reverse
mono_dir:   db 27,'[1m$'          ; bold/full intensity
mono_file:  db 27,'[0m$'          ; normal (half on mono screen)
mono_sys:   db 27,'[7m$'          ; reverse (was blink, too distracting)

titletxt:  db ' DMVCMD v1.0  dual-panel file manager','$'
statustxt: db ' jk/arrows  TAB swap  ENTER dir  c copy  d drive  m mono  t top  q quit','$'
allfiles:  db '*.*',0
dotdot:    db '..',0
rootstr:   db 92,0
ftfiles:   db ' files ','$'
notrdytxt: db '(drive not ready)$'

; --- drive menu strings ---
dmtop:     db '+-- Select drive ---+$'
dmbot:     db '+ jk ENTER  ESC back +$'
dmready:   db 'ready       $'
dmnotrdy:  db 'not ready   $'
dmunknown: db '            $'
nrmsg1:    db ' Disk in drive $'
nrmsg2:    db ': not ready.  R=Retry  S=Select another $'

; --- int24 / probe / menu state ---
oldint24off: dw 0
oldint24seg: dw 0
int24hit:    dw 0
drivecount:  dw 0
savedrv:     db 0
probedrv:    db 0
menucnt:     dw 0
menusel:     dw 0
menupick:    db 0
           db 0
drvstat:   db MAXPROBE dup(0)
menudrv:   db MAXPROBE dup(0)
probedta:  db 43 dup(0)


actpanel:  dw 0
monoflag:  dw 0
curcol:    dw 0
rowi:      dw 0
entidx:    dw 0
outrow:    dw 0
outcol:    dw 0
pcount:    dw 0
isdir:     dw 0
selflag:   dw 0
bannershown: dw 0
blcol:     dw 0
brcol:     dw 0
numlen:    dw 0
numbuf:    db 12 dup(0)
numtmp:    db 12 dup(0)
sp_i:      dw 0
sp_j:      dw 0
sortbuf:   db 20 dup(0)
txt_dir:   db '    <DIR>$'
cwdbuf:    db 64 dup(0)
curattr:   db 0
           db 0
copyname:  dw 0
srchand:   dw 0
dsthand:   dw 0
srcpath:   db 80 dup(0)
dstpath:   db 80 dup(0)
copybuf:   db 512 dup(0)
msg_copyok:  db ' File copied.        $'
msg_copyerr: db ' Copy failed.        $'
cc_top:    db '+-- Copy file ----------------------------+$'
cc_l1:     db '| Copy  ',0
cc_l2:     db '| from  ',0
cc_l3:     db '| to    ',0
cc_prompt: db '|   ENTER = OK      ESC = Cancel          |$'
cc_bot:    db '+-----------------------------------------+$'
dlgbuf:    db 48 dup(0)

dta:       db 21 dup(0)     ; DTA bytes 0..20
dtaattr:   db 0             ; 21: attribute
dtatime:   dw 0             ; 22-23: packed time
dtadate:   dw 0             ; 24-25: packed date
dtasize:   dw 0             ; 26-27: size low word
           dw 0             ; 28-29: size high word
dtaname:   db 13 dup(0)     ; 30: ASCIIZ name

LEFT:      db 10 dup(0)
           db MAXENT*ENTSZ dup(0)
RIGHT:     db 10 dup(0)
           db MAXENT*ENTSZ dup(0)
leftcwd:   db 64 dup(0)
rightcwd:  db 64 dup(0)
