AS = as
LD = ld

RUN_VM = qemu-system-i386

TARGET = boot.img

.PHONY: all clean run

all: $(TARGET)

$(TARGET): boot.bin
	dd if=/dev/zero of=$(TARGET) bs=512 count=1
	dd if=boot.bin of=$(TARGET) conv=notrunc

boot.bin: boot.o
	$(LD) -m elf_i386 -Ttext 0x0 --oformat binary -o boot.bin boot.o

boot.o: boot.S
	$(AS) --32 -o boot.o boot.S

run: $(TARGET)
	$(RUN_VM) -drive file=$(TARGET),if=floppy,format=raw -boot a

clean:
	rm -f boot.o boot.bin $(TARGET)

