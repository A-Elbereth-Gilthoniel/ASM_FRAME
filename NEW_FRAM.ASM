.model tiny
.286
.code
org 100h
										; cx - the number of the line being processed (counting from above)
										; ax - the absolute index of the last cell of the frame in this line
										; bx - the current index of the cell of the frame in this line
										; 1 SYMBOL == 2 BYTES (!!!)
CMD_PTR equ 81h
VIDEO_PTR equ 0b800h
cnsl_width equ 80d					; maximum number of symbol per line (in symbols)
top_ind equ 4					; number of symbols from above from the outloop frame (in symbols)
left_ind equ 3					; number of symbols on the left of the outloop frame (in symbols)
rel_top_ind equ 2			; number of symbol from upper outloop side to upper inside side (in symbols)
shadow_colour equ 72d

Start:	jmp main

;==========================================================
; PURPOSE: It is main procedure. Is engaged in calling functions and exiting program
; ENTRY: -
; ASSUMES: ES = 0b8000h
; DESTR: -
;==========================================================
MAIN proc
    call COMMAND_LINE
    call GET_FRAME_SIZE
	mov bx, VIDEO_PTR						; The procedure for writing an
	mov dl, 32d							; address to a video memory segment
	mov es, bx
	mov cx, min_cx					; cx - the number of the line being processed (counting from above)
    mov Bx, start_bx

outer_loop:
    inc cx
	add bx, 2 * cnsl_width		; bx - the current index of the cell of the frame in this line
	cmp cx, max_cx
	jae make_shadow_line
										; Internal loop cycxes through columns
    									; incresing argument 'bx'
	call FILL_LINE					; checking what symbol should be next
    jmp outer_loop
make_shadow_line:
    call MAKE_SHADOW
exit_dos:								; completing the program
	MOV AX, 4C13H
	INT 21H
MAIN endp
;=======================================================================================
; PURPOSE: WRITES COMMAND LINE ARGUMENTS
; ENTRY: arguments of command line(FROM LEFT TO RIGHT):
;          1) fr_len - width of outloop frame  (in symbols)
;          2) fr_high - height of outloop frame (in symbols)
;          3) frame_colour - code of frame's background (decimal)
;          4) frame_kind - kind of frame's (top_symb, middle_symb, lower_symb)
;          5) heading - heading text of the frame
;          6) text - the text that will be inside the frame
; ASSUMES: SI = 81h
; DESTR:
; CMD line. FORMAT: new_fram.com <fr_len> <fr_high> <frame_colour> <frame_kind> <heading>:<text>
;=======================================================================================
COMMAND_LINE    proc
    mov si, CMD_PTR
	MOV cl, byte ptr [si-1]                 ; cx - number of symbols in CMD line
    xor ch, ch
    mov di, si
    ADD di, cx
    sub di, 2
    mov al, ':'                     ; the separator between the text and the heading
    LEA dx, text

    call GET_STR                    ; get the text inside the line
    mov dx, heading_len             ; argument 6 - frame's text
    add text_len, dx                ; length of text

    mov al, ' '                     ; reading up to 'space'
    Lea dx, heading
    dec di

    call GET_STR                    ; argument 5 - frame's heading
    mov dx, text_len                ; length of heading
    sub heading_len, dx
    xor dx, dx

    call GET_VALUE                  ; argument 4 - kind of frame's
    sub dx, 1
    add frame_kind, dx
    add frame_kind, dx
    add frame_kind, dx

    call GET_VALUE
    add frame_colour, dx                ; argument 3 - frame's colour

    call GET_VALUE
    add fr_high, dx                     ; argument 2 - frame's height

    call GET_VALUE
    add fr_len, dx                     ; argument 1 - frame's length

    ret


COMMAND_LINE    endp
;=======================================================================
; PURPOSE: Reading decimal value from CMD line and put into 'dl'
; ENTRY: di - index of last digit of value
;        al - SEPARATOR between other value
; ASSUMES: SI = 81h
; OUTPUT: DL - the read value (DECIMAL)
; DESTR: AX
;=======================================================================
GET_VALUE proc
        std
        mov dl, 1               ; multiplier of value
        get_next_digit: scasb
        je final_value          ; if current symbol equ space, we finish procedure
        push ax
        mov al, [di+1]

        sub al, '0'             ; GETTING THE VALUE OF A DIGIT. WE TAKE AWAY THE SHIFT BETWEEN THE VALUE AND THE ASCII-CODE
        cmp al, 9
        ja undefined_symb
        mul dl                  ; multiplying a digit by 10 to the power of a digit
        add dh, al
        mov al, dl
        mul N
        mov dl, al

        pop ax
        loop get_next_digit
        cmp cx, 0
        je lack2
        final_value:
            mov dl, dh
            xor dh, dh         ; dh - result of the reading
        ret
        lack2:
            MOV DX, OFFSET Lack_argue
	        call ERROR_MENTION
        undefined_symb:
            mov dx, offset nondigit
            call ERROR_MENTION
    GET_VALUE endp
;======================================================================
; PURPOSE: Reading string from CMD line and put into link 'dx'
; ENTRY: DX - link where read information is put
;        AL - SEPARATOR between other strings
;        DI - ADRESS of last symbol of string
; ASSUMES: SI = 81h, DI = DX
; DESTR: BX, DF
;=======================================================================
GET_STR proc
        std
        mov bx, cx
        REPNE scasb                 ; search for the number of characters and
        cmp cx, 0
        je lack
        push cx                     ; the index of occurrence of the first character
        sub bx, cx
        mov cx, bx
        add heading_len, cx
        push si
        push di
        add di, 2
        cld
        mov si, di
        mov di, dx
        rep movsb                   ; writing characters from the command line to an address in 'dx'
        pop di
        pop si
        pop cx
        ret
    lack:
	    MOV DX, OFFSET Lack_argue
	    call ERROR_MENTION
    GET_STR endp
;=======================================================================
; PURPOSE: Calculate data about frame: frame_width, frame_colour, top_str, lower_str,
;                                      max_cx, middle_str.
; ENTRY: fr_len, fr_width, frame_kind, frame_colour, text, heading
; DESTR: BX, AX, DI, CX
;=======================================================================
GET_FRAME_SIZE proc
    cld
    mov bx, fr_len
    add bx, fr_len
    add frame_width, bx
    mov bx, fr_high
    add max_cx, bx
    add in_frame_lower, bx
    sub in_frame_lower, 2
    push ds
    pop es
    ret
GET_FRAME_SIZE endp
;=======================================================
; PURPOSE: FILLS IN A ROW FROM 'BX' TO FILLING THE FRAME AFTER
; ENTRY: BX - POINTER TO FILLING CHARACTERS
;        DI - POINTER TO THE LINE TO BE FILLED IN
; ASSUMES: -
; DESTR: AX, BX
;=======================================================
FILLING proc
        xor ah, ah
        push cx
        add bx, frame_kind
        mov ax, ' '          ; AL - current filling symbol
        mov cx, 2            ; indent from left outloop frame side to left inside frame side
        call POPULATING
        mov cx, 1
        mov al, [bx]
        call POPULATING
        mov cx, fr_len
        sub cx, 6
        mov al, [bx+1]
        call POPULATING
        mov cx, 1
        mov al, [bx+2]
        call POPULATING
        mov cx, 1           ; indent from right outloop frame side to right inside frame side
        mov ax, ' '
        call POPULATING
        mov byte ptr es:[di+1], dl
        pop cx
        ret
FILLING endp
;============================================================
; PURPOSE: multiplies the character specified in al by the index di
; ENTRY: CX - number of filled symbols
;        dl - code of frame colour
;        di - index of first symbol
; ASSUMES: ES = 0b8000h
; DESTR: CX, DI
;============================================================
POPULATING proc
    next: stosw
        mov byte ptr es:[di-1], dl
    loop next
    RET
POPULATING endp
;============================================================
; Checking what symbol should be next
; ENTRY: cx - number of current line
; 		 bx - the current index of the cell of the frame in this line
;		 dl - code of current symbol
; ASSUMES: ES = 0b800h
; DESTR: NOTHING
; CHANGE: dl, SI, AX
;============================================================
FILL_LINE	proc
    push bx
    mov di, bx
    mov dl, byte ptr frame_colour
	cmp cx, in_frame_upper
	je upper
	jb other

	cmp cx, in_frame_lower
	je lower
	ja other

    inside:
        lea bx, middle_symb
        jmp continue
    upper:
        lea bx, top_symb
        jmp continue
    lower:
        lea bx, lower_symb
        jmp continue
    other:
        lea bx, other_symb

    continue:
        call FILLING
        pop bx
        cmp cx, mm_cx
        jne shadow
        ret
    shadow:
        mov byte ptr es:[di+3], shadow_colour

        cmp cx, in_frame_upper
        je put_heading
        cmp cx, in_frame_with_text
        je put_text
        ret

    put_heading:                            ; put the heading in the middle ot top frame
        push cx
        lea si, heading
        mov di, bx
        mov ax, fr_len
        sub ax, heading_len
        add di, ax
        div hui
        mov al, ah
        xor ah, ah
        add di, ax                          ; let's make sure that 'di' are even
        mov cx, heading_len
        put_title_symb: movsb
            inc di
        loop put_title_symb
        pop cx
        ret

    put_text:                               ; put the text inside the frame
        push cx
        lea si, text
        mov di, bx
        add di, 8
        mov cx, text_len
        put_text_symb: movsb
            inc di
        loop put_text_symb
        pop cx
        ret
FILL_LINE	endp
;===============================================================
; Puts the shadow effect in the right places
; ENTRY: cx - counter of lines
;		 bx - absolute counter of cell
; ASSUMES: ES = 0b800h
; DESTR: bx
;===============================================================
MAKE_SHADOW proc
    add bx, 2
    push cx
    cld
    mov cx, fr_len
    mov di, bx
    mov al, ' '
    next33: stosw
            mov byte ptr es:[di-1], shadow_colour
        loop next33
	pop cx
    ret
MAKE_SHADOW endp
;================================================================
; PURPOSE: outputs the error text (link in 'dx') and terminates the program
; ENTRY: dx - link of the text with error
; ASSUMES: CS
; DESTR: pohui. Otsuda ne vozvraschaytsa.
;================================================================
ERROR_MENTION proc
    MOV AH, 09H
	INT 21H
	MOV AX, 4C13H
	INT 21H
ERROR_MENTION endp
;================================================================
top_symb db '+-+...111'
middle_symb db '| |. .1 1'
lower_symb db '+-+...111'
other_symb db '         '
;=================================================================
frame_width dw 0				        ; width of the frame (in bytes)
fr_high dw 0                            ; outloop frame's height (in symbols)
fr_len dw 0                            ; outloop frame's width (in symbols)
frame_colour dw 0                       ; code of colour of the frame
frame_kind dw 0                         ; a configuration of inside frame (array '...symb')
N db 10
;=================================================================
mm_cx dw top_ind + 1        ; first line where the shadow is painted
min_cx dw top_ind		 	; start value of 'cx'
max_cx dw top_ind + 2		; finish 'cx' value
in_frame_upper dw top_ind + rel_top_ind ; number of symbol from upper console side to inside frame upper side
in_frame_with_text dw top_ind + rel_top_ind + 1
in_frame_lower dw top_ind + rel_top_ind ; number of symbol from upper console side to inside frame lower side
start_bx dw (top_ind * cnsl_width + left_ind) * 2	; start value of 'ax'
text db cnsl_width DUP(?)
text_len dw 0
heading_len dw 0
heading db cnsl_width DUP(?)
hui db 2
lack_argue db 'Lack of arguments of CMD line. I remind format:', 0DH, 0AH, 'new_fram.com <fr_len> <fr_high> <frame_colour> <frame_kind> <heading>:<text>.', 0DH, 0AH, 'Buye!!!' , 0DH, 0AH, '$'
nondigit DB 'THE NUMERIC VALUE CONTAINS A CHARACTER THAT IS NOT A DIGIT', 0DH, 0AH, '$'
;=================================================================
end Start
