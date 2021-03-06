; helper macros for CyD music data

	if	!_cyd_macros_s

_cyd_macros_s	equ 1


_silence macro
	fcb	silence,\1
	endm


_rest	macro
	fcb	rest,\1
	endm


_setnote macro
	fcb	setnote,\1,\2
	endm


_setpatch macro
	fcb	setpatch,\1
	endm


_setport macro
    if ((\1 < -128) || (\1 > 127))
	fcb	setport16
	fdb	\1
    else
	fcb	setport,\1
    endif
	endm


;_setport16 macro
;	fcb	setport16
;	fdb	\1
;	endm

	
_settp	macro
	fcb	settp,\1
	endm


_loop 	macro
	fcb	loop,\1
	endm


_next	macro
	fcb	next
	endm


_jump	macro
	fcb	jump
	fdb	\1
	endm
	

_call	macro
	fcb	call
	fdb	\1
	endm


_calltp	macro
	fcb	calltp,\1
	fdb	\2
	endm


_return macro
	fcb	return
	endm


_setarp macro
	fcb	setarp,\1
	fdb	\2
	endm


_clrarp	macro
	fcb	clrarp
	endm


_startsmp macro
	fcb	startsmp,\1,\2
	endm


_setplscfg macro
	fcb	setplscfg,\1,\2,\3
	endm


_setplsduty macro
	fcb	setplsduty,\1,\2
	endm


_portamento	macro
	_setport	0.5+(\3-\2)/(\4)
	fcb		\1,\4
	_setport	0
	endm


	endif
