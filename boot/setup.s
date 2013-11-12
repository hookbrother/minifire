!
! setup.s
!
! When boot is finished loading me and system, it passes control to me.
!
! First I get the system data from the BIOS, and put them in a "safe" pace:
! 0x90000-0x901ff.
!
! I then move the system to 0x00000 from 0x10000, for making the address in
! system equal to the actual physical address, to facilitate the operation of
! the kernel code and data.
!
! Last I do some work for moving to protected mode and jump to system.
!

.global begtext, endtext, begdata, enddata, begbss, endbss

.text
begtext:
.data
begdata:
.bss
begbss:

INITSEG     = 0x9000            ! it is now used to store system data
SETUPSEG    = 0x9020            ! I start from here
SYSSEG      = 0x1000            ! system starts from here

entry   start
start:

! OK, control over in my hands now, so I ...

! get current cursor position
    mov     ax, #INITSEG
    mov     ds, ax
    mov     ah, #3
    xor     bh, bh
    int     0x10
    mov     [0], dx

! get memory size
    mov     ah, #0x88
    int     0x15
    mov     [2], ax

! get video-card data
	mov 	ah,#0x0f
	int	    0x10
	mov 	[4],bx          		! bh: display page
	mov	    [6],ax		            ! al: video mode, ah: window width

! check for EGA/VGA and get some config parameters
	mov	    ah,#0x12
	mov 	bl,#0x10
	int	    0x10
	mov 	[8],ax
	mov	    [10],bx
	mov 	[12],cx

! get hd0 data
	xor     ax, ax
	mov	    ds,ax
	lds 	si,[4*0x41]         ! get the value of int 0x41(start addr of hd0)
	mov	    ax,#INITSEG
	mov 	es,ax
	mov	    di,#0x80
	mov 	cx,#0x10
	rep
	movsb

! check that there is a hd1, if there, get its data
    mov     ah, #0x15
    mov     dl, #0x81
    int     0x13
    jc      no_disk1
    cmp     ah, #3
    jne     no_disk1
! get hd1 data
    xor     ax, ax
	mov	    ds,ax
	lds 	si,[4*0x46]
	mov	    ax,#INITSEG
	mov 	es,ax
	mov	    di,#0x80
	mov 	cx,#5
	rep
	movsw
no_disk1:

! now I move the system to it's rightful place
    cli                         ! no interrupts allowed !
    xor     ax, ax
    cld
do_move:
    mov     es, ax
    add     ax, #0x1000
    cmp     ax, #0x9000
    jz      end_move
    mov     ds, ax
    xor     di, di
    xor     si, si
    mov     cx, #0x8000
    rep
    movsw
    jmp     do_move
end_move:

! now I prepare to move protected mode ...

! first, I load the segment descriptors.
    mov     ax, #SETUPSEG
    mov     ds, ax
    lidt    idt_48
    lgdt    gdt_48

! enable A20.
    in      al, #0x92
    or      al, #2
    out     #0x92, al

! reprogram the interrupts.
	mov 	al, #0x11  		    ! initialization sequence
	out	    #0x20, al	   	    ! send it to 8259A-1
	.word	0x00eb, 0x00eb		! jmp $+2, jmp $+2
	out 	#0xA0, al  		    ! and to 8259A-2
	.word	0x00eb, 0x00eb
	mov	    al, #0x20        	! start of hardware int's (0x20)
	out	    #0x21, al
	.word	0x00eb, 0x00eb
	mov 	al, #0x28      		! start of hardware int's 2 (0x28)
	out 	#0xA1, al
	.word	0x00eb, 0x00eb
	mov	    al, #0x04	        ! 8259-1 is master, ir2 link to 8259-2
	out 	#0x21, al
	.word	0x00eb, 0x00eb
	mov	    al, #0x02        	! 8259-2 is slave, link to 8259-1's ir2
	out 	#0xA1, al
	.word	0x00eb, 0x00eb
	mov	    al, #0x01    	    ! 8086 mode for both
	out 	#0x21, al
	.word	0x00eb, 0x00eb
	out	    #0xA1, al
	.word	0x00eb, 0x00eb
	mov 	al, #0xFF      		! mask off all interrupts for now
	out	    #0x21, al
	.word	0x00eb, 0x00eb
	out 	#0xA1, al

! Jump to system, in 32-bit protected mode.
    mov     ax, #1
    lmsw    ax
    jmpi    0, 8

gdt:
	.word   0,0,0,0	            ! dummy

	.word	0x07FF  	    	! 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000  	    	! base address=0
	.word	0x9A00	    	    ! code read/exec
	.word	0x00C0  	    	! granularity=4096, 386

	.word	0x07FF  	    	! 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000	    	    ! base address=0
	.word	0x9200  	    	! data read/write
	.word	0x00C0	    	    ! granularity=4096, 386

idt_48:
	.word	0   			    ! idt limit=0
	.word	0,0     			! idt base=0L

gdt_48:
	.word	0x800       		! gdt limit=2048, 256 GDT entries
	.word	512+gdt, 9        	! gdt base = 0X9xxxx

.org    512*4 - 12
    .ascii  "setup ending"
sys_st:
    .ascii  "system start"

.text
endtext:
.data
enddata:
.bss
endbss:
