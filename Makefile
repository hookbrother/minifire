AS86	=as86
LD86	=ld86

AS	 	=as
LD 		=ld

img: boot/boot boot/setup
	cat boot/boot boot/setup > minifire.img

boot/boot:	boot/boot.s
	$(AS86) -o boot/boot.o boot/boot.s
	$(LD86) -d -o boot/boot boot/boot.o

boot/setup:	boot/setup.s
	$(AS86) -o boot/setup.o boot/setup.s
	$(LD86) -d -o boot/setup boot/setup.o

boot/head:	boot/head.s
	$(AS) -o boot/head.o boot/head.s
	$(LD) -d -o boot/setup boot/setup.o
