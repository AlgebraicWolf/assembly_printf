all:
	nasm -f ELF64 printf.asm -o printf.o
	ld printf.o -o printf
	rm printf.o
