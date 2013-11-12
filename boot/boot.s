!
! boot.s
!
! I'm loaded at 0x7c00 by the bios-startup routines, and moves myself to address
! 0x90000, and jump there.
!
! I then load setup at 0x90200, and the system at 0x10000, using int 0x13.
!
! Last, I choose which root-device to use, and jump to setup.

.global begtext, endtext, begdata, enddata, begbss, endbss

.text
begtext:
.data
begdata:
.bss
begbss:

SYSSIZE     = 0x3000            ! number of clicks (16 bytes)
SETUPLEN    = 4                 ! nr of setup sectors (512 bytes)
BOOTSEG     = 0x07c0            ! original address of boot
INITSEG     = 0x9000            ! move boot here
SETUPSEG    = 0x9020            ! move setup here
SYSSEG      = 0x1000            ! move system here
ENDSEG      = SYSSEG+SYSSIZE    ! here to stop
ROOT_DEV    = 0x306             ! first partition on second drive

entry start
start:
! move myself to address 0x90000.
    mov     ax, #BOOTSEG
    mov     ds, ax
    xor     si, si              ! ds:si (07c0:0000)
    mov     ax, #INITSEG
    mov     es, ax
    xor     di, di              ! es:di (9000:0000)
    mov     cx, #0x100
    rep
    movw
    jmpi    go,INITSEG
go:
    mov     ax, cs
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, #0xFF00

! load setup after me.
! NOTE!!! read errs will result in a unbreakable loop, reboot by hand.
load_setup:
    mov     ah, #2              ! ah=2: read sectors
    mov     al, #SETUPLEN       ! al=4: nr of sectors
    mov     cx, #2              ! ch=0: track; cl=2: sector
    xor     dx, dx              ! dh=0: drive letter; dl=0: head number
    mov     bx, #0x0200         ! es:bx (9000:0200)
    int     0x13
    jnc     ok_load_setup
    xor     ax, ax              ! ah=0: reset the diskette
    xor     dx, dx
    int     0x13
    j       load_setup

ok_load_setup:

! get drive parameters, specifically nr of sectors/track
    mov     ax, #0x0800         ! ah=8: get drive parameters
    xor     dl, dl              ! dl=0: drive letter
    int     0x13
    and     cx, #0x001F
    seg     cs
    mov     sectors, cx
    mov     ax, #INITSEG
    mov     es, ax              ! restore the value of es

! print some inane message
    mov     ah, #3              ! read cursor pos
    xor     bh, bh              ! page number
    int     0x10

    mov     ah, #0x13           ! write string
    mov     al, #1              ! move cursor
    mov     bp, #msg1
    mov     cx, #0x18
    mov     bx, 7               ! ah=0: page, al=7: attribute
    int     0x10

! load the system at 0x10000 and kill motor.
    mov     ax, #SYSSEG
    mov     es, ax
    call    read_sys
    call    kill_motor

! Last, I choose which root-device to use, then jump to setup.
! If the root_dev is defined, use it directly.
! Otherwise, use /dev/ps0 or /dev/PS0 according to the numbers of sectors
    seg     cs
    mov     ax, root_dev
    cmp     ax, #0
    jne     root_defined
    seg     cs
    mov     bx, sectors
    mov     ax, 0x0208
    cmp     bx, #15             ! 1.2M - dev/ps0
    je      root_defined
    mov     ax, 0x021c          ! else - dev/PS0
root_defined:
    seg     cs
    mov     root_dev, ax
    jmpi    0,SETUPSEG

! I load whole track if I can, making sure no 64kB boundaries are crossed.
sread:  .word   1+SETUPLEN      ! have read such sectors of current track
head:   .word   0               ! current head
track:  .word   0               ! current track

read_sys:
    mov     ax, es
    test    ax, #0x0fff         ! if es isn't at 64KB boundary, I will die！！！
die:
    jne     die
    xor     bx, bx              ! the starting address within segment.
rp_read:
    mov     ax, es
    cmp     ax, #ENDSEG         ! have I loaded all yet?
    jb      ok1_read
    ret
ok1_read:
    seg     cs
    mov     ax, sectors
    sub     ax, sread           ! how many sectors left in current track?
    mov     cx, ax
    shl     cx, #9
    add     cx, bx              ! the current address after read.
    jnc     ok2_read            ! if(cx<(1<<16))
    je      ok2_read            ! if(cx==(1<<16))
    xor     ax, ax
    sub     ax, bx
    shr     ax, #9              ! if out off 64KB boundary, only fill segment.
ok2_read:
    call    read_track
    mov     cx, ax
    add     ax, sread
    seg     cs
    cmp     ax, sectors         ! have read all the track?
    jne     ok3_read
    mov     ax, #1
    sub     ax, head
    jne     ok4_read
    inc     track
ok4_read:
    mov     head, ax
    xor     ax, ax
ok3_read:
    mov     sread, ax
    shl     cx, #9
    add     bx, cx
    jnc     rp_read             ! if((bx+cx)<(1<<16))
    mov     ax, es
    add     ax, #0x1000
    mov     es, ax
    xor     bx, bx
    jmp     rp_read
! read (ax) sectors to es:bx.
read_track:
    push    ax
    push    bx
    push    cx
    push    dx
st_rt:
    mov     ah, #2
    mov     dx, track
    mov     cx, sread
    inc     cx
    mov     ch, dl
    mov     dx, head
    mov     dh, dl
    xor     dl, dl
    and     dh, #1
    int     0x13
    jnc     ok_rt
    xor     ax, ax
    xor     dx, dx
    int     0x13
    jmp     st_rt
ok_rt:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

! Turn off the floppy drive motor, so that you enter the kernel in a known
! start, and don't have to worry about it later.
kill_motor:
    push    dx
    mov     dx, #0x3f2
    xor     al, al
    outb
    pop     dx
    ret

sectors:
    .word   0
msg1:
    .byte   13, 10
    .ascii  "Loading system ..."
    .byte   13, 10, 13, 10
root_dev:
    .word   ROOT_DEV
.org    510
boot_flag:
    .word   0xAA55

.text
endtext:
.data
enddata:
.bss
endbss:
