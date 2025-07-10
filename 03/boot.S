; 主引导记录(MBR) - 操作系统启动引导程序
; 功能：从硬盘加载用户程序到内存并执行
; 编译：nasm -f bin -o boot.bin boot.S

app_lba_start equ 100           ; 用户程序在硬盘上的起始逻辑扇区号(LBA)
                                ; 扇区100相当于硬盘上第51200字节处(100*512)
							
SECTION mbr align=16 vstart=0x7c00  ; MBR段，16字节对齐，虚拟起始地址0x7c00
                                    ; BIOS会将MBR加载到物理地址0x7c00处

	; === 初始化堆栈环境 ===
	; 设置堆栈段寄存器SS和栈指针SP
	mov ax,0        ; AX = 0
	mov ss,ax       ; SS = 0，堆栈段基址为0
	mov sp,ax       ; SP = 0，栈顶指针为0（栈向下增长）

	; === 计算用户程序加载地址 ===
	; 根据物理基址计算16位段地址，用于加载用户程序
	mov ax,[cs:phy_base]            ; 取物理基址低16位(0x10000的低16位=0)
	mov dx,[cs:phy_base+0x02]       ; 取物理基址高16位(0x10000的高16位=1)
	mov bx,16                       ; 除数16（段地址计算需要除以16）
	div bx                          ; DX:AX / 16 = 段地址
	mov ds,ax                       ; DS指向用户程序加载段(0x1000)
	mov es,ax                       ; ES也指向同一段

	; === 读取用户程序第一个扇区 ===
	xor di,di                       ; DI = 0，与SI组成32位LBA地址的高16位
	mov si,app_lba_start            ; SI = 100，LBA地址的低16位
	xor bx,bx                       ; BX = 0，目标偏移地址(DS:0x0000)
	call read_hard_disk_0           ; 读取第一个扇区到内存

	; === 分析用户程序大小 ===
	; 用户程序头部前4字节存储程序总长度
	mov dx,[2]                      ; 取程序长度的高16位
	mov ax,[0]                      ; 取程序长度的低16位
	mov bx,512                      ; 每扇区512字节
	div bx                          ; DX:AX / 512 = 需要的扇区数
	cmp dx,0                        ; 检查余数是否为0
	jnz @1                          ; 有余数说明需要额外一个扇区
	dec ax                          ; 无余数时，结果减1（已读了一个扇区）
@1:
	cmp ax,0                        ; 检查是否还需要读取更多扇区
	jz direct                       ; 不需要，直接跳转到处理入口点
	
	; === 读取剩余扇区 ===
	push ds                         ; 保存当前DS值

	mov cx,ax                       ; CX = 剩余扇区数（循环计数器）
@2:
	mov ax,ds                       ; 获取当前段地址
	add ax,0x20                     ; 段地址+0x20 = 下一个512字节边界段
	mov ds,ax                       ; 更新段地址
						
	xor bx,bx                       ; 偏移地址始终为0
	inc si                          ; 下一个逻辑扇区号
	call read_hard_disk_0           ; 读取扇区
	loop @2                         ; 循环直到读完所有扇区

	pop ds                          ; 恢复DS到用户程序头部段

	; === 处理程序入口点 ===
direct:
	; 修正程序入口点的段地址（从相对地址转换为绝对地址）
	mov dx,[0x08]                   ; 取入口点段地址高16位
	mov ax,[0x06]                   ; 取入口点段地址低16位  
	call calc_segment_base          ; 计算实际段基址
	mov [0x06],ax                   ; 回填修正后的段地址

	; === 处理段重定位表 ===
	; 将程序中所有段的相对地址转换为绝对地址
	mov cx,[0x0a]                   ; 取重定位表项数
	mov bx,0x0c                     ; 重定位表起始地址
	
realloc:
	mov dx,[bx+0x02]                ; 取段地址高16位
	mov ax,[bx]                     ; 取段地址低16位
	call calc_segment_base          ; 计算实际段基址
	mov [bx],ax                     ; 回填修正后的段地址
	add bx,4                        ; 指向下一个重定位项（每项4字节）
	loop realloc                    ; 处理所有重定位项

	jmp far [0x04]                  ; 远跳转到用户程序入口点执行

;-------------------------------------------------------------------------------
; 函数：read_hard_disk_0
; 功能：使用LBA28模式从主硬盘读取一个扇区
; 输入：DI:SI = 32位LBA扇区号，DS:BX = 目标缓冲区地址
; 说明：使用ATA/IDE接口的端口I/O方式访问硬盘
read_hard_disk_0:
	push ax
	push bx
	push cx
	push dx

	; 设置读取扇区数
	mov dx,0x1f2                    ; 扇区数寄存器
	mov al,1                        ; 读取1个扇区
	out dx,al

	; 设置LBA地址（28位）
	inc dx                          ; 0x1f3 - LBA地址位7-0
	mov ax,si
	out dx,al

	inc dx                          ; 0x1f4 - LBA地址位15-8
	mov al,ah
	out dx,al

	inc dx                          ; 0x1f5 - LBA地址位23-16
	mov ax,di
	out dx,al

	inc dx                          ; 0x1f6 - 驱动器/磁头寄存器
	mov al,0xe0                     ; 1110 0000B: LBA模式,主盘
	or al,ah                        ; 加入LBA地址位27-24
	out dx,al

	inc dx                          ; 0x1f7 - 状态/命令寄存器
	mov al,0x20                     ; 发送读扇区命令
	out dx,al

	; 等待硬盘准备好数据
.waits:
	in al,dx                        ; 读取状态寄存器
	and al,0x88                     ; 检查忙位(bit7)和数据请求位(bit3)
	cmp al,0x08                     ; 不忙且数据准备好？
	jnz .waits                      ; 否则继续等待

	; 读取数据
	mov cx,256                      ; 读取256个字(512字节)
	mov dx,0x1f0                    ; 数据寄存器

.readw:
	in ax,dx                        ; 读取一个字
	mov [bx],ax                     ; 存储到缓冲区
	add bx,2                        ; 指向下一个字位置
	loop .readw                     ; 读取完整扇区

	pop dx
	pop cx
	pop bx
	pop ax

	ret

;-------------------------------------------------------------------------------
; 函数：calc_segment_base
; 功能：将32位物理地址转换为16位段基址
; 输入：DX:AX = 32位物理地址
; 返回：AX = 16位段基址
; 原理：段地址 = 物理地址 / 16
calc_segment_base:
	push dx
	
	; 将输入地址加上程序加载基址
	add ax,[cs:phy_base]            ; 低16位相加
	adc dx,[cs:phy_base+0x02]       ; 高16位相加(带进位)
	
	; 除以16得到段地址
	shr ax,4                        ; 低16位右移4位
	ror dx,4                        ; 高16位循环右移4位
	and dx,0xf000                   ; 保留高4位
	or ax,dx                        ; 合并得到最终段地址
	
	pop dx
	
	ret

;-------------------------------------------------------------------------------
phy_base dd 0x10000                     ; 用户程序加载的物理基址(64KB处)
                                        ; 选择64KB是为了避免与BIOS和DOS占用的内存冲突
	
times 510-($-$$) db 0                   ; 填充到510字节
db 0x55,0xaa                            ; MBR结束标志（引导扇区签名）
