jmp near start                    ; 跳转到程序开始执行点
	
; 定义要显示的文本数据，每个字符后跟颜色属性0x07（白色字体，黑色背景）
mytext db 'C',0x07,'i',0x07,'a',0x07,'l',0x07,'l',0x07,'o',0x07,'~',0x07,\
	'^',0x07,'~',0x07
number db 0,0,0,0,0               ; 用于存储数字各位的缓冲区

start:
	mov ax,0x7c0                  ; 设置数据段基地址为0x7c00（引导扇区加载位置）
	mov ds,ax
	
	mov ax,0xb800                 ; 设置附加段基地址为0xb8000（文本模式显存起始地址）
	mov es,ax
	
	cld                           ; CLD = Clear Direction Flag（清除方向标志）
	                              ; 设置DF标志位为0，使字符串操作指令从低地址向高地址进行
	                              ; 与STD（Set Direction Flag）指令相对
	mov si,mytext                 ; 源地址指向mytext数据（DS:SI = 数据段中的文本）
	mov di,0                      ; 目标地址指向显存起始位置（ES:DI = 显存段0xB8000开始）
	mov cx,(number-mytext)        ; 计算要复制的字符串长度
	                              ; CX = 字符串长度（number标号位置 - mytext标号位置）
	                              ; 这里计算的是mytext的长度，包含所有字符和属性字节
	                              ; 注意：mytext和number之间的距离是字节数，所以直接相减即可
	                              ; 如果需要复制的字节数是偶数，则可以直接使用
	rep movsb                     ; rep movsb详解：
	                              ; - movsb指令从DS:SI复制一个字节到ES:DI
	                              ; - 复制后SI和DI自动递增1（因为cld清除了方向标志）
	                              ; - rep前缀使movsb重复执行CX次
	                              ; - 所以总共复制CX个字，即将mytext的所有数据复制到显存

	; 获取number标号的偏移地址用于数字转换演示
	mov ax,number
	
	; 将数字转换为各个数位并存储
	mov bx,ax                     ; bx指向number缓冲区
	mov cx,5                      ; 设置循环5次（处理5位数字）
	mov si,10                     ; 设置除数为10（十进制转换）
digit: 
	xor dx,dx                     ; 清除dx寄存器（除法操作需要）
	div si                        ; ax除以10，商存入ax，余数存入dx
	mov [bx],dl                   ; 将余数（当前数位）保存到缓冲区
	inc bx                        ; 指针移向下一个存储位置
	loop digit                    ; 循环处理下一位数字
	
	; 将数位转换为ASCII字符并显示到屏幕
	mov bx,number                 ; bx指向数位缓冲区起始位置
	mov si,4                      ; 从最高位开始显示（索引4到0）
show:
	mov al,[bx+si]                ; 读取当前数位
	add al,0x30                   ; 转换为ASCII字符（数字0-9对应0x30-0x39）
	mov ah,0x04                   ; 设置字符属性（红色字体，黑色背景）
	mov [es:di],ax                ; 将字符和属性写入显存
	add di,2                      ; 移动到下一个字符位置（每个字符占2字节）
	dec si                        ; 处理下一位数字
	jns show                      ; 如果si≥0则继续循环
	
	mov word [es:di],0x0744       ; 在数字后显示一个红色的字符'D'

	jmp near $                    ; 无限循环，程序停止在此

; 填充引导扇区剩余空间为0
times 510-($-$$) db 0
db 0x55,0xaa                      ; 引导扇区标志（主引导记录签名）
