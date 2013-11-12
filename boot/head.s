/*
 * head.s
 */

/*
 * When setup have moved me to 0x00000 from 0x10000, and finished some work for
 * moving to protected mode, it passes control to me.
 *
 * My first work is setting all the segment registers and resetting idt, make
 * all entries pointing to a dummy only reported error interrupt routine.
 *
 * After then, I reset gdt, check a20 close or open, and test whether hosts
 * have math coprocessor or not, if yes, set the corresponding flag in cr0.
 *
 * Note that I will leave page directory at the address 0x00000, which is my
 * place, this means parts of me would be overwritten.
 *
 * Last I jump to main by using "ret".
 */

.text
.globl  _idt, _gdt, _pg_dir, _tmp_floppy_area
_pg_dir:
startup_32:

    movl    $0x10, %eax
    mov     %ax, %ds
    mov     %ax, %es
    mov     %ax, %fs
    mov     %ax, %gs
    lss     _stack_start, %esp
    call    setup_idt
    call    setup_gdt
    movl    $0x10, %eax
    mov     %ax, %ds
    mov     %ax, %es
    mov     %ax, %fs
    mov     %ax, %gs
    lss     _stack_start, %esp
    xorl    %eax, %eax
1:  # check that A20 really is enabled
    incl    %eax
    movl    %eax, 0x000000
    cmpl    %eax, 0x100000
    je      1b                  # if A20 is closed, I will check it forever!!!

# check math chip
    movl    %cr0, %eax
    andl    $0x80000011, %eax
    orl     $2, %eax
    movl    %eax, %cr0
    call    check_x87
    jmp     after_page_tables

# check for 287/387
check_x87:
    fninit
    fstsw   %ax
    cmpb    $0, %al
    je      1f                  # no coprocessor: have to set bits
    movl    %cr0, %eax
    xorl    $6, %eax
    movl    %eax, %cr0
    ret
.align  2
1:
    .byte   0xDB, 0xE4          # fsetpm for 287, ignored by 387
    ret
/*
 * setup_idt
 *
 * Sets up an idt with 256 entries pointing to ignore_int, interrupt gates, and
 * then loads it.
 */
setup_idt:
    lea     ignore_int, %edx    # offset(ignore_int) will be divided two parts
                                # and saved in right place.
	movl    $0x00080000, %eax   # selector = 0x0008 = cs
    movw    %dx, %ax
    movw    $0x8E00, %dx        # interrupt gate - dpl=0, present

    lea     _idt, %edi
    movw    $256, %ecx
rp_sidt:
    movl    %eax, (%edi)
    movl    %edx, 4(%edi)
    addl    $8, %edi
    dec     %ecx
    jne     rp_sidt
    lidt    idt_descr
    ret

/*
 * setup_gdt
 *
 * Sets up an gdt that only two entries are currently built, then loads it.
 */
setup_gdt:
    lgdt    gdt_descr
    ret
# all codes above here will be overwritten by page tables.


.org    0x1000
pg0:

.org    0x2000
pg1:

.org    0x3000
pg2:

.org    0x4000
pg3:

.org    0x5000
# _tmp_floppy_area is used by the floppy-driver, and it needs to be aligned.
_tmp_floppy_area:
    .fill   1024, 1, 0

after_page_tables:
    pushl   $0
    pushl   $0
    pushl   $0                  # parameters for main
    pushl   $L6                 # return address for main, if it decides to.
    pushl   $_main
    jmp     setup_paging
L6:
    jmp     L6                  # Actually, main should never return here.

# This is default interrupt "handler".
int_msg:
    .asciz  "Unknown interrupt\n\r"
.align  2
ignore_int:
    pushl   %eax
    pushl   %ecx
    pushl   %edx
    push    %ds
    push    %es
    push    %fs
    movl    $0x10, %eax
    mov     %ax, %ds
    mov     %ax, %es
    mov     %ax, %fs
    pushl   $int_msg
    call    _printk
    popl    %eax
    pop     %fs
    pop     %es
    pop     %ds
    popl    %edx
    popl    %ecx
    popl    %eax
    iret

/*
 * Setup_paging
 *
 * Note that it only used for 16Mb memory.
 */
.align  2
setup_paging:
    mov     $1024*5, %ecx
    xorl    %eax, %eax
    xorl    %edi, %edi
    cld
    rep
    stosl
    movl    $pg0+7, _pg_dir
    movl    $pg1+7, _pg_dir+4
    movl    $pg2+7, _pg_dir+8
    movl    $pg3+7, _pg_dir+12
    movl    $pg3+4096, %edi
    movl    $0xfff007, %eax
    std
1:
    stosl
    subl    $0x1000, %eax
    jge     1b
    xorl    %eax, %eax
    movl    %eax, %cr3
    movl    %cr0, %eax
    orl     $0x80000000, %eax
    movl    %eax, %cr0
    ret

.align  2
.word   0
idt_descr:
    .word   256*8-1
    .long   _idt
.align  2
.word   0
gdt_descr:
    .word   256*8-1
    .long   _gdt

.align  3
_idt:
    .fill   256, 8, 0
_gdt:
    .quad   0x0000000000000000  # NULL descriptor
    .quad   0x00c09a0000000fff  # kernel code's limit is 16Mb
    .quad   0x00c0920000000fff  # kernel data's limit is 16Mb
    .quad   0x0000000000000000  # syssegment descriptor, don't use
    .fill   252, 8, 0           # space for LDT's and TSS's etc
