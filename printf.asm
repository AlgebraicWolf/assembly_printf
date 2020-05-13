SEGMENT .code

GLOBAL _start

%macro invoke 1-*
        %rep %0-1
                push %{-1:-1}
                %rotate %0-1
        %endrep
        %rotate %0-1
        call %1
%endmacro

%macro get_arg 1
        mov %1, qword [rbp+rbx]         ; Get QWORD value to %1 register
        add rbx, 8                      ; Proceed to the next argument
%endmacro

%macro print_uint 1
        push rsi                        ; Save current string pos
        push rbx                        ; Save current argument index 

        lea rsi, [itoa_buf]             ; Buffer for generated string
        mov rcx, %1                     ; Radix 
        call itoa                       ; Convert string 
        call printstr                   ; Print string
        
        pop rbx                         ; Restore cur argument
        pop rsi                         ; Restore string pos
%endmacro

%define UINT32_MASK r9
%define NEGATIVE_MASK r10

%macro uint32_parse_and_print 1
        get_arg r8                      ; Get integer to print 
        and r8, UINT32_MASK                      ; Cut to 32 bit integer
        print_uint %1                   ; Print unsigned integer in base %1
%endmacro

_start:
        invoke printf, msg, qword [character], qword [negative], qword [negative], qword [negative], qword [negative], qword [negative], qword [zero], qword [zero], qword [zero], qword [zero], qword [zero], qword [positive], qword [positive], qword [positive], qword [positive], qword [positive], msg, string
        invoke printf, string2, lovestr, qword 3802, qword 100, qword '!', qword 127

        mov rax, 60             ; sys_exit
        xor rdi, rdi            ; Exit code 0
        syscall

;================================================
; Formatted print function
; ARGS: |Through stack| 
;       Null-terminated string to print
;       <optional> Parameters to fill in the string
; Supported types:
;       %d - Signed decimal 32-bit integer
;       %o - Unsigned octal 32-bit integer
;       %u - Unsigned decimal 32-bit integer
;       %x - Unsigned hexadecimal integer
;       %c - Character
;       %s - Null-terminated string 
;       %p - Pointer
;       %% - % symbol
;================================================

printf:
        push rbp                        ; Save old RBP, as someone might be using it
        mov rbp, rsp                    ; New RBP

        mov rbx, 16                     ; RBP+RBX is pointer to current argument. Skip old RBP and RET address

        mov r9, 0xFFFFFFFF              ; Mask for 32 bit integer
        mov r10, 0x80000000             ; Mask for last bit

        mov rsi, [rbp + rbx]            ; Pointer to formatted string
        add rbx, 8                      ; Proceed to next argument

.loop:                                 ; Printing loop
        call formatlen
        call printstr                   ; Print part of the string
        cmp byte [rsi], '%'             ; Check whether an argument required
        jne .end                        ; If not, it's an end of string
        inc rsi                         ; Skip '%' symbol

.check_percent:
        cmp byte [rsi], '%'             
        jne .check_s                    ; Printing '%' symbol

        mov rdx, 1                      ; One symbol
        call printstr                   ; Print it     

        jmp .loop                      ; Proceed printf

.check_s:
        cmp byte [rsi], 's'             
        jne .check_c                    ; Printing string
        inc rsi                         ; Skip format symbol

        push rsi                        ; Save current string position

        get_arg rsi                     ; Get string to insert

        call strlen                     ; Get string length
        call printstr                   ; Print string

        pop rsi                         ; Restore string

        jmp .loop                      ; Proceed printf

.check_c:
        cmp byte [rsi], 'c'
        jne .check_d                    ; Printing char
        inc rsi                         ; Proceed to next symbol

        push rsi                        ; Save pointer to string

        mov rdx, 1                      ; Print single character
        lea rsi, [rbp+rbx]              ; Print from arglist
        add rbx, 8                      ; Proceed to next argument
        call printstr                   ; Print character

        pop rsi                         ; Restore pointer to string

        jmp .loop                      ; Proceed printf

.check_d:
        cmp byte [rsi], 'd'
        jne .check_u                    ; Printing signed int
        inc rsi                         ; Skip formatting symbol

        get_arg r8                      ; Get integer to print
        and r8, r9                      ; Cut to 32 bit integer
        cmp r8, r10                     ; Check whether an integer is negative
        jb .skip_neg                    ; If it isn't, don't add a sign

        push rsi                        ; Save RSI

        lea rsi, [itoa_buf]             ; Save buffer address to RSI
        mov byte [itoa_buf], '-'        ; Add sign if required
        mov rdx, 1                      ; Print one character
        call printstr

        pop rsi                         ; Restore RSI

        dec r8
        not r8                          ; Make integer positive
        and r8, r9                      ; Cut to 32 bits

.skip_neg:
        print_uint 10                   ; Print unsigned integer in base 10
        jmp .loop                      ; Proceed printf

.check_u:
        cmp byte [rsi], 'u'
        jne .check_o                    ; Printing unsigned int
        inc rsi                         ; Skip formatting symbol

        uint32_parse_and_print 10

        jmp .loop                      ; Proceed printf

.check_o:
        cmp byte [rsi], 'o'
        jne .check_x                    ; Printing unsigned oct
        inc rsi
        
        uint32_parse_and_print 8

        jmp .loop                      ; Proceed printf

.check_x:
        cmp byte [rsi], 'x'
        jne .check_b                    ; Printing unsigned hex
        inc rsi                         ; Skip formatting symbol

        uint32_parse_and_print 16

        jmp .loop                      ; Proceed printf

.check_b:
        cmp byte [rsi], 'b'
        jne .check_p                    ; Printing unsigned bin
        inc rsi                         ; Skip formatting symbol

        uint32_parse_and_print 2

        jmp .loop                      ; Proceed printf

.check_p:
        cmp byte [rsi], 'p'
        jne .endSwitch                  ; Printing pointer
        inc rsi                         ; Skip formatting symbol

        push rsi                        ; Save RSI

        mov dword [itoa_buf], 0x7830    ; Pointer prefix '0x'
        mov rdx, 2                      ; Length of prefix
        lea rsi, [itoa_buf]             ; Printing from itoa buffer
        call printstr                   ; Print dat prefix
        get_arg r8                      ; Get pointer
        print_uint 16                   ; Print pointer in hex

        pop rsi                         ; Restore RSI

        jmp .loop                      ; Proceed printf

.endSwitch:
        jmp .loop                      ; Proceed routine
        
.end:        
        pop rbp                         ; Restore old RBP
        ret                             ; Exit function


;================================================
; Function that prints string
; ARGS: rsi - String to print
;       rdx - length of string
; DESTR: rax, rdi
; EXIT: rsi - First unprinted symbol
;================================================

printstr:
        mov rax, 1                      
        mov rdi, 1
        syscall
        add rsi, rdx
        ret

;================================================
; Function that calculates the length till the \0
; or '%' symbols are encountered
; ARGS: rsi - String to look through
; EXIT: rdx - length of part that does not contains
;       symbol
;================================================

formatlen:    
        xor rdx, rdx
        push rsi

.count:
        lodsb
        cmp al, 0
        je .endcount
        cmp al, '%'
        je .endcount
        inc rdx
        loop .count

.endcount:
        pop rsi

        ret

;================================================
; Function that calculates the length till the \0
; is encountered
; ARGS: rsi - String to look through
; EXIT: rdx - length of part that does not contains
;       symbol
;================================================

strlen:    
        xor rdx, rdx
        push rsi

.count:
        lodsb
        cmp al, 0
        je .endcount
        inc rdx
        loop .count

.endcount:
        pop rsi

        ret

;================================================
; Function that turns unsigned 32-bit integer into
; radix 
;
; ARGS: RSI - String to save to
;       RCX - Radix
;       R8 - Unsigned integer to translate
; EXIT: RDX - Length of generated string
; DESTR: RAX, RBX, RDI, R8 
;================================================

itoa:   
        push rsi                        ; Save RSI
        mov rdi, rsi
        lea rbx, [alphabet]             ; Set RBX to table address

.translate:
        xor rdx, rdx
        mov rax, r8                     ; Prepare integer for division
        div rcx                         ; Divide by radix
        xchg rax, rdx                   ; Swap remainder and quotient
        
        xlat                            ; Translate remainder into symbol
        stosb                           ; Copy symbol to string
        mov r8, rdx                     ; Proceed with quotient
        cmp r8, 0                       ; Check wheter process is complete
        jne .translate                  ; If not, move on 

        mov byte [rdi], 0               ; Ensure string is null-terminated 

        mov rdx, rdi                    
        sub rdx, rsi                    ; Calculate length

        dec rdi

.reverse:        
        mov ch, byte [rdi]             ; Keep symbol
        mov cl, byte [rsi]      
        mov byte [rsi], ch             ; Swap symbs
        mov byte [rdi], cl

        inc rsi
        dec rdi
        
        cmp rsi, rdi                    ; Check wheter reversing is finished
        jb .reverse                     ; If not, continue

        pop rsi                         ; Restore RSI
        ret         

SEGMENT .data
        itoa_buf:       times 65 db 0
        alphabet db "0123456789abcdefghijklmnopqrstuvwxyz"

        msg db 'Character test: %c',0xA,'Negative integer test: %d %u %b %o %x', 0xA, "Zero test: %d %u %b %o %x", 0xA, "Positive integer test: %d %u %b %o %x", 0xA, "Pointer to this string: %p", 0xA, 'String test: %s', 0xA, '100%% works!', 0xA, 0
        character dq 'F'
        negative dq -4417
        zero dq 0
        positive dq 4417
        string2 db 'I %s %x %d%%%c%b', 0xA, 0
        lovestr db 'love', 0
        string db 'Meow!', 0
