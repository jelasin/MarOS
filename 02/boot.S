jmp near start                    ; 第一条指令：跳转到start标号
                                  ; 这条指令占用3字节，位于0x7c00-0x7c02

message db '1+2+3+...+100='       ; 定义要显示的字符串
                                  ; 位于0x7c03开始的位置

start:
	mov ax,0x7c0                  ; 设置DS段基地址为0x7c00
	mov ds,ax                     ; DS指向整个引导扇区的起始位置
	                              ; 这样DS:SI可以访问扇区内的所有数据

	mov ax,0xb800                 ; 设置附加段基地址为0xb8000（文本模式显存起始地址）
	mov es,ax

	; 以下显示字符串到屏幕
	mov si,message                ; SI指向message字符串的偏移地址
	mov di,0                      ; DI指向显存起始位置（屏幕左上角）
	mov cx,(start-message)        ; CX = 字符串长度（start标号位置 - message标号位置）
@g:
	mov al,[si]                   ; 从DS:SI读取一个字符到AL
	mov [es:di],al                ; 将字符写入显存ES:DI位置
	inc di                        ; 移动到下一个显存位置
	mov byte [es:di],0x07         ; 设置字符属性（白色字体，黑色背景）
	inc di                        ; 移动到下一个字符位置（跳过属性字节）
	inc si                        ; 指向下一个源字符
	loop @g                       ; 循环直到所有字符显示完毕

	; 以下计算1到100的累加和
	xor ax,ax                     ; 清零AX寄存器，用作累加器
	mov cx,1                      ; CX作为循环计数器，从1开始
@f:
	add ax,cx                     ; AX += CX（累加当前数值）
	inc cx                        ; CX++（下一个数）
	cmp cx,100                    ; 比较CX是否超过100
	jle @f                        ; 如果CX <= 100则继续循环

	; 以下设置栈并准备数位转换
	xor cx,cx                     ; 清零CX寄存器
	mov ss,cx                     ; 设置堆栈段基地址为0
	mov sp,cx                     ; 设置栈指针为0

	mov bx,10                     ; BX = 10，用作除数进行十进制转换
	xor cx,cx                     ; 清零CX，用作数位计数器
@d:
	inc cx                        ; 数位计数器加1
	xor dx,dx                     ; 清零DX寄存器（除法操作需要）
	div bx                        ; AX除以10，商在AX，余数在DX
	or dl,0x30                    ; 将余数转换为ASCII字符（0-9对应0x30-0x39）
	push dx                       ; 将数位字符压入栈中（从低位到高位）
	cmp ax,0                      ; 检查商是否为0
	jne @d                        ; 如果商不为0，继续提取下一位

	; 以下从栈中取出数位并显示（从高位到低位）
@a:
	pop dx                        ; 从栈中弹出一个数位字符
	mov [es:di],dl                ; 将数位字符写入显存
	inc di                        ; 移动到下一个显存位置
	mov byte [es:di],0x07         ; 设置字符属性（白色字体，黑色背景）
	inc di                        ; 移动到下一个字符位置
	loop @a                       ; 循环直到所有数位显示完毕

	jmp near $                    ; 无限循环，程序停止在此

; 填充引导扇区剩余空间为0
times 510-($-$$) db 0
db 0x55,0xaa                      ; 引导扇区标志（主引导记录签名）
