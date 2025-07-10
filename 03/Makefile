# 定义汇编器工具
NASM = nasm

# 定义虚拟机运行程序（QEMU模拟器）
RUN_VM = qemu-system-i386

# 定义生成的文件
BOOT_BIN = boot.bin
LOADER_BIN = Loader.bin
TARGET = boot.img

# 定义常量
BOOT_SECTOR_SIZE = 512
DISK_SIZE = 10485760
LOADER_START_SECTOR = 100

# 声明伪目标（这些目标不生成同名文件）
.PHONY: all clean run debug info

# 默认目标：生成完整的硬盘镜像
all: $(TARGET)

# 生成硬盘镜像文件的规则
$(TARGET): $(BOOT_BIN) $(LOADER_BIN)
# 创建一个10MB的硬盘镜像文件
	dd if=/dev/zero of=$(TARGET) bs=512 count=20480
# 将引导扇区写入硬盘镜像的第一个扇区（LBA 0）
	dd if=$(BOOT_BIN) of=$(TARGET) conv=notrunc bs=512 count=1
# 将用户程序写入硬盘镜像的指定位置
	dd if=$(LOADER_BIN) of=$(TARGET) conv=notrunc bs=512 seek=$(LOADER_START_SECTOR)

# 编译主引导扇区
$(BOOT_BIN): boot.S
# 编译引导扇区代码为纯二进制格式
	$(NASM) -f bin -o $(BOOT_BIN) boot.S
# 验证引导扇区大小必须为512字节
	@if [ `stat -c%s $(BOOT_BIN)` -ne $(BOOT_SECTOR_SIZE) ]; then \
		echo "Error: Boot sector size is not 512 bytes"; \
		exit 1; \
	fi

# 编译用户程序
$(LOADER_BIN): Loader.S
# 编译用户程序为纯二进制格式
	$(NASM) -f bin -o $(LOADER_BIN) Loader.S

# 运行目标：启动虚拟机测试完整系统
run: $(TARGET)
# 使用QEMU启动虚拟机，挂载硬盘镜像
# -drive：指定硬盘镜像文件和格式
# -boot c：从硬盘启动
# -m 32：分配32MB内存
	$(RUN_VM) -drive file=$(TARGET),if=ide,format=raw -boot c -m 32

# 调试目标：启动虚拟机进行调试
debug: $(TARGET)
# 启动QEMU调试模式
# -s：启用GDB调试服务器（端口1234）
# -S：启动时暂停，等待调试器连接
	$(RUN_VM) -drive file=$(TARGET),if=ide,format=raw -boot c -m 32 -s -S

# 清理目标：删除所有生成的文件
clean:
# 删除所有生成的二进制文件和镜像文件
	rm -f $(BOOT_BIN) $(LOADER_BIN) $(TARGET)
	@echo "Clean completed"

