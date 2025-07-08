# 定义汇编器工具
NASM = nasm

# 定义虚拟机运行程序（QEMU模拟器）
RUN_VM = qemu-system-i386

# 定义最终生成的目标文件（软盘镜像文件）
TARGET = boot.img

# 声明伪目标（这些目标不生成同名文件）
.PHONY: all clean run

# 默认目标：生成引导镜像
all: $(TARGET)

# 生成软盘镜像文件的规则
$(TARGET): boot.bin
# 创建一个512字节的空镜像文件（软盘第一扇区大小）
	dd if=/dev/zero of=$(TARGET) bs=512 count=1
# 将引导程序写入镜像文件，不截断文件（保持512字节大小）
	dd if=boot.bin of=$(TARGET) conv=notrunc

# 编译汇编源文件生成二进制文件的规则
boot.bin: boot.S
# 使用NASM汇编器将.S文件编译成纯二进制格式
	$(NASM) -f bin -o boot.bin boot.S

# 运行目标：启动虚拟机测试引导程序
run: $(TARGET)
# 使用QEMU启动虚拟机，挂载软盘镜像并从软盘启动
	$(RUN_VM) -drive file=$(TARGET),if=floppy,format=raw -boot a

# 清理目标：删除所有生成的文件
clean:
# 删除目标文件、二进制文件和镜像文件
	rm -f boot.o boot.bin $(TARGET)

