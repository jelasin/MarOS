; 用户程序 - 多段程序结构示例
; 功能：演示段间跳转、字符串显示、多数据段使用
; 特点：使用自定义程序头部格式，支持段重定位

; === 程序头部段 ===
; 包含程序元信息和重定位表，供加载器使用
SECTION header vstart=0
program_length  dd program_end          ; [0x00] 程序总长度（字节数）

; 程序入口点信息
code_entry      dw start                ; [0x04] 入口点偏移地址
                dd section.code_1.start ; [0x06] 入口点段地址（加载时会被修正）

realloc_tbl_len dw (header_end-code_1_segment)/4  ; [0x0a] 重定位表项目数

; 段重定位表 - 记录所有需要重定位的段地址
; 加载器会将这些相对地址转换为绝对地址
code_1_segment  dd section.code_1.start ; [0x0c] 代码段1基址
code_2_segment  dd section.code_2.start ; [0x10] 代码段2基址  
data_1_segment  dd section.data_1.start ; [0x14] 数据段1基址
data_2_segment  dd section.data_2.start ; [0x18] 数据段2基址
stack_segment   dd section.stack.start  ; [0x1c] 堆栈段基址

header_end:

; === 代码段1 ===
; 包含字符显示函数和主程序逻辑
SECTION code_1 align=16 vstart=0

; 函数：put_string
; 功能：显示以0结尾的字符串
; 输入：DS:BX = 字符串地址
; 说明：逐字符调用put_char函数显示
put_string:
    mov cl,[bx]                     ; 取当前字符
    or cl,cl                        ; 测试是否为0
    jz .exit                        ; 是0则结束
    call put_char                   ; 显示字符
    inc bx                          ; 指向下一个字符
    jmp put_string                  ; 继续处理

.exit:
    ret

;-------------------------------------------------------------------------------
; 函数：put_char  
; 功能：在屏幕上显示一个字符
; 输入：CL = 字符ASCII码
; 说明：直接操作显卡内存(0xB8000)和CRT控制器
put_char:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es

    ; === 获取当前光标位置 ===
    ; 从CRT控制器读取光标位置（16位值）
    mov dx,0x3d4                    ; CRT控制器索引寄存器
    mov al,0x0e                     ; 光标位置高8位寄存器
    out dx,al
    mov dx,0x3d5                    ; CRT控制器数据寄存器
    in al,dx                        ; 读取高8位
    mov ah,al

    mov dx,0x3d4
    mov al,0x0f                     ; 光标位置低8位寄存器
    out dx,al
    mov dx,0x3d5                    ; CRT控制器数据寄存器
    in al,dx                        ; 读取低8位
    mov bx,ax                       ; BX = 光标位置（字符数）

    ; === 处理特殊字符 ===
    cmp cl,0x0d                     ; 回车符？
    jnz .put_0a
    ; 处理回车：移动到当前行开始
    mov ax,bx
    mov bl,80                       ; 每行80个字符
    div bl                          ; 除法得到行号
    mul bl                          ; 乘法得到行首位置
    mov bx,ax
    jmp .set_cursor

.put_0a:
    cmp cl,0x0a                     ; 换行符？
    jnz .put_other
    ; 处理换行：移动到下一行开始
    add bx,80
    jmp .roll_screen

.put_other:
    ; === 显示普通字符 ===
    ; 在显存中写入字符（字符+属性）
    mov ax,0xb800                   ; 显存段基址
    mov es,ax
    shl bx,1                        ; 转换为字节偏移（每字符2字节）
    mov [es:bx],cl                  ; 写入字符（属性字节保持不变）

    ; 光标前进一个位置
    shr bx,1
    add bx,1

.roll_screen:
    ; === 检查是否需要滚屏 ===
    cmp bx,2000                     ; 超过屏幕范围？(25行*80列=2000)
    jl .set_cursor

    ; 执行滚屏操作
    push bx

    mov ax,0xb800                   ; 显存段
    mov ds,ax
    mov es,ax
    cld                             ; 方向标志清零（向前复制）
    mov si,0xa0                     ; 源地址：第二行开始(80*2=160=0xa0)
    mov di,0x00                     ; 目标地址：第一行开始
    mov cx,1920                     ; 复制字数(24行*80列=1920)
    rep movsw                       ; 复制24行内容上移

    ; 清空最后一行
    mov bx,3840                     ; 最后一行起始位置(24*80*2=3840)
    mov cx,80                       ; 80个字符
.cls:
    mov word[es:bx],0x0720          ; 空格字符+正常属性
    add bx,2
    loop .cls

    pop bx
    sub bx,80                       ; 光标上移一行

.set_cursor:
    ; === 设置新的光标位置 ===
    mov dx,0x3d4
    mov al,0x0e                     ; 光标位置高8位
    out dx,al
    mov dx,0x3d5
    mov al,bh
    out dx,al
    
    mov dx,0x3d4
    mov al,0x0f                     ; 光标位置低8位
    out dx,al
    mov dx,0x3d5
    mov al,bl
    out dx,al

    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax

    ret

;-------------------------------------------------------------------------------
; 主程序入口点
; 功能：初始化环境，显示信息，演示段间跳转
start:
    ; === 初始化程序运行环境 ===
    ; 此时DS和ES指向程序头部段
    mov ax,[stack_segment]          ; 获取堆栈段地址
    mov ss,ax                       ; 设置堆栈段寄存器
    mov sp,stack_end                ; 设置栈顶指针
    
    mov ax,[data_1_segment]         ; 获取数据段1地址
    mov ds,ax                       ; 设置数据段寄存器

    ; === 显示第一段信息 ===
    mov bx,msg0                     ; 指向第一个消息字符串
    call put_string                 ; 显示字符串

    ; === 跳转到代码段2 ===
    ; 使用远返回指令实现段间跳转
    push word [es:code_2_segment]   ; 压入目标段地址
    mov ax,begin                    ; 目标偏移地址
    push ax                         ; 压入偏移地址
    
    retf                            ; 远返回跳转到代码段2

; 从代码段2返回后的继续执行点    
continue:
    ; === 切换到数据段2 ===
    mov ax,[es:data_2_segment]      ; 获取数据段2地址
    mov ds,ax                       ; 切换数据段
    
    mov bx,msg1                     ; 指向第二个消息字符串
    call put_string                 ; 显示字符串

    jmp $                           ; 无限循环（程序结束）

; === 代码段2 ===
; 演示段间跳转的目标代码段
SECTION code_2 align=16 vstart=0

; 代码段2的执行入口
; 功能：跳转回代码段1继续执行
begin:
    ; === 跳转回代码段1 ===
    push word [es:code_1_segment]   ; 压入代码段1地址
    mov ax,continue                 ; 返回点偏移地址
    push ax                         ; 压入偏移地址
    
    retf                            ; 远返回跳转到代码段1

; === 数据段1 ===
; 包含第一段要显示的信息
SECTION data_1 align=16 vstart=0

msg0 db '  This is NASM - the famous Netwide Assembler. '
    db 'Back at SourceForge and in intensive development! '
    db 'Get the current versions from http://www.nasm.us/.'
    db 0x0d,0x0a,0x0d,0x0a
    db '  Fun Facts about Assembly:',0x0d,0x0a
    db '  - Assembly was first used in 1947 on EDSAC computer',0x0d,0x0a
    db '  - One assembly instruction = one machine code',0x0d,0x0a
    db '  - x86 has over 1000 different instructions!',0x0d,0x0a
    db '  - The fastest code is often written in Assembly',0x0d,0x0a,0x0d,0x0a
    db '  Did you know? The Intel 8086 (1978) had:',0x0d,0x0a
    db '  - 29,000 transistors  - 16-bit registers',0x0d,0x0a
    db '  - 1MB memory limit   - 5-10 MHz clock speed',0x0d,0x0a,0x0d,0x0a
    db '  Example code for calculate 1+2+...+1000:',0x0d,0x0a,0x0d,0x0a
    db '     ; Ciallo~ ',0x0d,0x0a
    db '     xor ax,ax      ; Clear accumulator',0x0d,0x0a
    db '     xor cx,cx      ; Clear counter',0x0d,0x0a
    db '  @@:',0x0d,0x0a
    db '     inc cx         ; Increment counter',0x0d,0x0a
    db '     add ax,cx      ; Add to sum',0x0d,0x0a
    db '     adc dx,0       ; Add carry to high word',0x0d,0x0a
    db '     cmp cx,1000    ; Check if done',0x0d,0x0a
    db '     jle @@         ; Loop if not done',0x0d,0x0a
    db '  ASCII Art Time!',0x0d,0x0a
    db '     /\\_/\\  ',0x0d,0x0a
    db '    ( o.o ) <- Assembly Cat says: "Meow in hex!"',0x0d,0x0a
    db '     > ^ <  ',0x0d,0x0a,0x0d,0x0a
    db 0                                                      ; 字符串结束标志

; === 数据段2 ===
; 包含第二段要显示的信息
SECTION data_2 align=16 vstart=0

msg1 db '  The above contents is written by jelasin. '
    db '2025-07-10'
    db 0                                                      ; 字符串结束标志

; === 堆栈段 ===
; 程序的运行时堆栈空间
SECTION stack align=16 vstart=0
    
    resb 256                        ; 预留256字节堆栈空间

stack_end:                          ; 堆栈段结束（栈顶位置）

; === 程序结束标记段 ===
; 用于计算程序总长度
SECTION trail align=16
program_end:                        ; 程序结束位置标记
