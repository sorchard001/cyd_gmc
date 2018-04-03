; Cân y Ddraig
; ... or "Dragon's Song"
; ... or "There's Good CyD"

; Copyright 2013-2015 Ciaran Anscomb
;
; Adapted for Game Master Cartridge by S.Orchard 2018
; -----------------------------------------------------------------------

		include	"dragonhw.s"

; -----------------------------------------------------------------------
		org	$e00

ftable		include	"ftable.s"

; -----------------------------------------------------------------------

; The playback core (and most of the tune processing) fits within one page
; of memory.  Keep DP pointed at this page, and everything should stay
; fast.

player_dp	equ	*>>8
		setdp	player_dp

; Many of the per-channel variables are (self-)modified directly in the
; code.  Here are the ones that aren't:

chan_vars	macro
c\1ctimer	fcb	1
c\1etimer	fcb	1
c\1arptimer	fcb	1
c\1loop		fcb	0
		endm

		chan_vars	1
		chan_vars	2
		chan_vars	3

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

play_frag

; Envelope processing.  Once the envelope counter (cXetimer) decrements to
; zero, start again from env_r.  Note that if this loops round (256
; fragments) before a new note is played, env_r will restart.

chan_env	macro
c\1env_ptr	equ	*+1
		ldx	#$0000
		dec	c\1etimer
		bne	1F
c\1env_r	equ	*+1
		ldx	#$0000
1		lda	,x+
		beq	2F
		sta	c\1wavevol
		stx	c\1env_ptr
2
		endm

		chan_env	1
		chan_env	2
		chan_env	3

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

chan_write_hw	macro
c\1freq		equ	*+1
		ldd	#1
		lsrb
		lsrb
		lsrb
		lsrb
		orb	#\2
		stb	$ff41
		anda	#$3f
		ldb	#16
		sta	$ff41
c\1wavevol	equ	*+1
		subb	#1
		andb	#15
		orb	#\3
		stb	$ff41
		endm

		chan_write_hw	1,$80,$90
		chan_write_hw	2,$a0,$b0
		chan_write_hw	3,$c0,$f0

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Add portamento

chan_port	macro
		ldd	c\1freq
c\1port		equ	*+1
		addd	#0
		std	c\1freq
		endm

		chan_port	1
		chan_port	2
		chan_port	3

; Tune processing.  Decrement the command timer and when it reaches zero,
; fetch & process the next command.

process_tune

chan_handle	macro

		; arpeggio
		dec	c\1arptimer
		bne	20F
		inc	c\1wantnote	; any non-zero
c\1arpptr	equ	*+1
		ldx	#null_arp
		lda	,x+
		bne	10F
		ldx	c\1arpbase
10		stx	c\1arpptr
		sta	c\1arp
20

		dec	c\1ctimer
		bne	c\1checknote
c\1tuneptr	equ	*+1
		ldu	#$0000
c\1nextbyte	lda	,u+
		bmi	30F

		; jump to command handler
c\1cmd		ldx	#jumptable_c\1
		jmp	[a,x]

		; a=note (0-127)
30
c\1newnote
c\1ads_time	equ	*+1
		ldb	#$00
		stb	c\1etimer
c\1env_ads	equ	*+1
		ldx	#$0000
		stx	c\1env_ptr
		pulu	b	; b=time
c\1setnote	stb	c\1ctimer
		sta	c\1note
c\1done		stu	c\1tuneptr
c\1arpbase	equ	*+1
		ldx	#null_arp
		stx	c\1arpptr
		bra	c\1donote

c\1checknote
c\1wantnote	equ	*+1
		lda	#$00
		beq	c\1nonote
c\1donote
		clr	c\1wantnote
c\1note		equ	*+1
		lda	#$00
c\1tp		equ	*+1
		adda	#$00
c\1arp		equ	*+1
		adda	#$00
c\1arptime	equ	*+1
		ldb	#$00
		stb	c\1arptimer
		lsla
		ldx	#ftable+128
		ldd	a,x
		std	c\1freq
c\1nonote

		endm

		chan_handle	1
		chan_handle	2
		chan_handle	3


		rts

; -----------------------------------------------------------------------

; Command handlers

rest_c		macro
silence_c\1
		ldd	#envelope_0
		std	c\1env_ptr
xrest_c\1	clr	c\1etimer
rest_c\1	pulu	a	; a=time
		sta	c\1ctimer
		jmp	c\1done
		endm

setnote_c	macro
setnote_c\1	pulu	a,b	; a=note, b=time
		jmp	c\1setnote
		endm

setpatch_c	macro
setpatch_c\1	ldx	#patch_table
		pulu	b
		lda	#5
		mul
		leax	d,x
		lda	,x
		sta	c\1ads_time
		ldd	1,x
		std	c\1env_ads
		ldd	3,x
		std	c\1env_r
		jmp	c\1nextbyte
		endm

setport_c	macro
setport_c\1	pulu	b	; b=port
		sex
		std	c\1port
		jmp	c\1nextbyte
		endm

setport16_c	macro
setport16_c\1	pulu	d	; d=port
		std	c\1port
		jmp	c\1nextbyte
		endm


settp_c		macro
settp_c\1	pulu	a	; a=tp
		sta	c\1tp
		jmp	c\1nextbyte
		endm

loop_c		macro
loop_c\1	pulu	a
		sta	c\1loop
		stu	c\1next
		jmp	c\1nextbyte
		endm

next_c		macro
next_c\1	dec	c\1loop
		beq	1F
c\1next		equ	*+1
		ldu	#$0000
1		jmp	c\1nextbyte
		endm

jump_c		macro
jump_c\1	ldu	,u
		jmp	c\1nextbyte
		endm

call_c		macro
calltp_c\1	pulu	a
		sta	c\1tp
call_c\1	pulu	x
		stu	c\1_ret_addr
		leau	,x
		jmp	c\1nextbyte
		endm

return_c	macro
c\1_ret_addr	equ	*+1
return_c\1	ldu	#$0000
		jmp	c\1nextbyte
		endm

setarp_c	macro
clrarp_c\1	ldx	#null_arp
		clra
		bra	10F
setarp_c\1	pulu	a,x
10		sta	c\1arptime
		sta	c\1arptimer
		stx	c\1arpbase
		stx	c\1arpptr
		jmp	c\1nextbyte
		endm


		rest_c		1
		rest_c		2
		rest_c		3
		setnote_c	1
		setnote_c	2
		setnote_c	3
		setpatch_c	1
		setpatch_c	2
		setpatch_c	3
		setport_c	1
		setport_c	2
		setport_c	3
		settp_c		1
		settp_c		2
		settp_c		3
		loop_c		1
		loop_c		2
		loop_c		3
		next_c		1
		next_c		2
		next_c		3
		jump_c		1
		jump_c		2
		jump_c		3
		call_c		1
		call_c		2
		call_c		3
		return_c	1
		return_c	2
		return_c	3
		setarp_c	1
		setarp_c	2
		setarp_c	3
		setport16_c	1
		setport16_c	2
		setport16_c	3


silence		equ	$00
rest		equ	$02
xrest		equ	$04
setnote		equ	$06
setpatch	equ	$08
setport		equ	$0a
settp		equ	$0c
loop		equ	$0e
next		equ	$10
jump		equ	$12
call		equ	$14
calltp		equ	$16
return		equ	$18
setarp		equ	$1a
clrarp		equ	$1c
setport16	equ	$1e


jumptable_c	macro
jumptable_c\1
		fdb	silence_c\1
		fdb	rest_c\1
		fdb	xrest_c\1
		fdb	setnote_c\1
		fdb	setpatch_c\1
		fdb	setport_c\1
		fdb	settp_c\1
		fdb	loop_c\1
		fdb	next_c\1
		fdb	jump_c\1
		fdb	call_c\1
		fdb	calltp_c\1
		fdb	return_c\1
		fdb	setarp_c\1
		fdb	clrarp_c\1
		fdb	setport16_c\1
		endm

		jumptable_c	1
		jumptable_c	2
		jumptable_c	3



; -----------------------------------------------------------------------

select_tune
		ldx	#tune_table
		ldb	#6
		mul
		leax	d,x
		ldd	,x++
		std	c1tuneptr
		ldd	,x++
		std	c2tuneptr
		ldd	,x++
		std	c3tuneptr
		lda	#1
		sta	c1ctimer
		sta	c2ctimer
		sta	c3ctimer
		jmp	process_tune

; -----------------------------------------------------------------------

; Test harness

start
		orcc	#$50

		lda	#player_dp
		tfr	a,dp

		ldu	#$ff41
		lda	#$9f
		sta	,u
		nop
		nop
		lda	#$bf
		sta	,u
		nop
		nop
		lda	#$df
		sta	,u
		nop
		nop
		lda	#$ff
		sta	,u
		nop
		nop
		lda	#$e7
		sta	,u	

		lda	#$3d		;
		sta	reg_pia0_crb	; FS enabled hi->lo
		lda	#$34		;
		sta	reg_pia0_cra	; HS disabled
		ldb	#$3c		;
		stb	reg_pia1_crb	; enable sound

		lda	#0
		jsr	select_tune


1		jsr	play_frag
		sync
		lda	$ff02
		bra	1B

null_arp	fcb	0

; Test tune

		include	"music.s"

tune_table	fdb tune0_c1,tune0_c2,tune0_c3	; tune 0

		end	start
