NASM = nasm

RUN_VM = qemu-system-i386

TARGET = boot.img

.PHONY: all clean run

all: $(TARGET)

$(TARGET): boot.bin
	dd if=/dev/zero of=$(TARGET) bs=512 count=1
	dd if=boot.bin of=$(TARGET) conv=notrunc

boot.bin: boot.S
	$(NASM) -f bin -o boot.bin boot.S

run: $(TARGET)
	$(RUN_VM) -drive file=$(TARGET),if=floppy,format=raw -boot a

clean:
	rm -f boot.o boot.bin $(TARGET)

