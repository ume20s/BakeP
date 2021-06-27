name	bakep
title	文字化けシミュレーター
;
;	文字化けシミュレーター『ばけＰ君』　[ bakep.asm ]    Ver. 1.05
;

INT29H	equ	29h
LF	equ	0ah
CR	equ	0dh
;

CODE	segment
	assume	cs:CODE,ds:CODE
;
;	PSP領域 (0ch～0ffh)
;
	org	2ch
envseg	dw	?
	org	80h
argc	db	?
argv	db	127 dup (?)

stktop	label	word

;
;---------------------------------------------------------------------
;
	org	100h

start:	jmp	initial

;
;	表示割り込み処理（常駐本体）
;

ss_reg	dw	?
sp_reg	dw	?

shin	db	1
rate	db	4
b_flg	db	0
count	db	0
nebake	dw	40
filt	dw	0fffh


new29	proc
	sti
	mov	cs:[ss_reg],ss
	mov	cs:[sp_reg],sp
	push	cs
	pop	ss
	mov	sp,offset stktop
;
;化けるか？
;
	cmp	al,CR
	je	exit2
	cmp	al,LF
	je	exit2
	cmp	cs:[rate],0
	je	bake_hajime
	cmp	cs:[b_flg],0
	jne	bake_naka
	dec	cs:[nebake]
	jz	bake_hajime
	jmp	exit2
;
;化ける
;
bake_hajime:
	mov	ah,cs:[rate]
	mov	cs:[count],ah
	mov	cs:[b_flg],1
	in	al,73h
	jmp	exit
	
bake_naka:
	dec	cs:[count]
	jz	bake_owari
	in	al,73h
	jmp	exit
	
bake_owari:
	mov	cs:[b_flg],0
	mov	ah,0
	in	al,73h
	and	ax,cs:[filt]
	add	ax,04h
	mov	cs:[nebake],ax

exit:	cmp	cs:[shin],0
	je	exit2
	cmp	al,20h
	ja	exit2
	add	al,080h
exit2:	mov	sp,cs:[sp_reg]
	mov	ss,cs:[ss_reg]
	
jmpold:	db	0eah	;jmp far ってこった
old29h	dd	?
	
new29	endp

breakadr label	byte

;
;---------------------------------------------------------------------
;
;	初期化部分
;

initial:
	cmp	[argc],0
	jz	argend
	mov	si,offset argv
arglp:	call	getarg
	cmp	al,CR
	je	argend
	cmp	al,'R'		;常駐解除
	je	argr
	cmp	al,'S'
	je	args		;不親切モード
	cmp	al,'0'
	jb	unknown
	cmp	al,'7'
	ja	unknown
	jmp	argnum		;残りは数字だ
;知らぬオプション
unknown:
	mov	dx,offset unk$
	mov	ah,09h
	int	21h
	mov	ax,4c01h
	int	21h
;不親切モード
args:	mov	cs:[shin],0
	jmp	arglp
;文字化けレート
argnum:	sub	al,'0'
	mov	cs:[rate],al
	mov	cl,al
	shr	cs:[filt],cl
	jmp	arglp

argend:
	mov	ax,3500h+INT29H
	int	21h
	call	chkmem
	jz	exist
	mov	word ptr cs:[old29h],bx
	mov	word ptr cs:[old29h+2],es
	mov	ax,2500h+INT29H
	mov	dx,offset new29
	int	21h
;
;	環境変数の解放
;
	mov	es,[envseg]
	mov	ah,49h
	int	21h
	mov	[envseg],0
;
;	常駐処理
;
	mov	dx,offset reside$
	mov	ah,09h
	int	21h
	lea	dx,[breakadr+0fh]
	mov	cl,4
	shr	dx,cl
	mov	ax,3100h
	int	21h
;実は既に常駐していた
exist:	mov	dx,offset exist$
	mov	ah,09h
	int	21h
	mov	ax,4c01h
	int	21h
;
;	常駐解放
;
argr:
	mov	ax,3500h+INT29H
	int	21h
	call	chkmem
	jnz	notexist
	push	ds
	lds	dx,es:[old29h]
	mov	ax,2500h+INT29H
	int	21h
	pop	ds
	mov	ah,49h
	int	21h
	jc	relerr
	mov	dx,offset rel$
	mov	ah,09h
	int	21h
	mov	ax,4c00h
	int	21h
;解放失敗
relerr:
	mov	dx,offset relerr$
	mov	ah,09h
	int	21h
	mov	ax,4c01h
	int	21h
;実は常駐していなかった
notexist:
	mov	dx,offset notex$
	mov	ah,09h
	int	21h
	mov	ax,4c01h
	int	21h
;
;	メモリ常駐確認
;
chkmem	proc
	mov	si,offset new29
	mov	di,offset new29
	mov	cx,(offset jmpold - offset new29 + 3)
	cld
	repe	cmpsb
	ret
chkmem	endp

;
;	引数取得
;
getarg	proc
	lodsb
	cmp	al,' '
	jz	getarg
	cmp	al,09h
	jz	getarg
	cmp	al,','
	jz	getarg
	cmp	al,'-'
	jz	getarg
	cmp	al,'/'
	jz	getarg
	cmp	al,'a'
	jb	getarge
	cmp	al,'z'
	ja	getarge
	sub	al,'a'-'A'
getarge:
	ret
getarg	endp

unk$	db	"usage : bakep [-<1..7>] [-s] [-r]",CR,LF,"$"
reside$	db	"常駐した",CR,LF,"$"
exist$	db	"既に常駐している",CR,LF,"$"
rel$	db	"解除した",CR,LF,"$"
relerr$	db	"解除できない",CR,LF,"$"
notex$	db	"まだいない",CR,LF,"$"

CODE	ends
	end	start
