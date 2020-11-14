	errorlevel -302	
	PROCESSOR PIC16F877
	#include<P16F877.inc>
	org 0x00
	clrf STATUS
	movlw 0x00
	movwf PCLATH

INDF			equ 0x00
Mode 			equ 0x20
MirrorCounter 	equ 0x21 
MirrorReg		equ 0x22
ShiftB			equ 0x24
ShiftD			equ 0x25
ShiftC 			equ 0x23
RowTime 		equ 0x26
ColTime 		equ 0x27
ErrorTime 		equ 0x28
SpeakerTime 	equ 0x29
AdressHitachi 	equ 0x2A
CharHitachi		equ 0x2B
ComRecieve		equ 0x2C
VoltageReg		equ 0x2D
ButtonCode		equ 0x2E
SCheck			equ 0x2F
fCOUNTER		equ 0x30
ADCTime			equ 0x31
NumPressKey		equ 0x32
PreKey			equ 0x33

	goto begin

begin	
	clrf PORTC
	movlw 0x00
	movwf PORTB
	movwf PORTD	
	bcf STATUS,RP1
	bsf STATUS,RP0
	movlw 0x87
	movwf OPTION_REG
	clrwdt
	movlw b'10100000'	
	movwf TRISC
	movlw 0x00	
	movwf TRISB
	movlw 0x00	
	movwf TRISD
	movlw b'00111000'	
	movwf TRISA
	bcf STATUS,RP0

	call init_com
	call scan_com
	
	
	
scan_com:
	btfsc PIR1, RCIF
	goto mode_select
	return

mode_select
	bcf STATUS,Z
	btfsc PIR1,RCIF
	call read_com
	bcf STATUS,0x00

	movlw 0x67
	xorwf ComRecieve,0
	btfsc STATUS,Z
	call ADC
	
	movlw 0x44
	xorwf ComRecieve,0
	btfsc STATUS,Z
	call draw_hitachi

	movlw 0x33
	xorwf ComRecieve,0
	btfsc STATUS,Z
	call row
	
	movlw 0x22
	xorwf ComRecieve,0
	btfsc STATUS,Z
	call column

	goto mode_select
	

col_delay:
	clrf TMR0
col_c1
	clrwdt	
	movlw 0xf4
	subwf TMR0,0
	btfss STATUS,0x02
	goto col_c1
	return


column
	call speaker
col_start
	call scan_com
	clrwdt
	bsf STATUS,RP0
	movlw 0x00	
	movwf TRISB
	movlw 0x00	
	movwf TRISD
	bcf STATUS,RP0
	bcf STATUS,RP1
	bcf STATUS,C
	movlw 0xff
	movwf PORTB
	movwf PORTD
	movlw 0xff
	movwf ShiftD
	movwf ShiftB
	movlw 0x00
	movwf FSR
	
col_loop
	clrwdt
	rlf ShiftB,F
	rlf ShiftD,F
	movlw 0xff
	movwf PORTB
	movwf PORTD
	movlw 0x1f
	movwf PORTC
	movf ShiftB,W
	movwf PORTB
	movf ShiftD,W
	movwf PORTD
	call col_delay
	incf FSR,F
	movf FSR,W
	xorlw 0x10
	btfss STATUS,Z
	goto col_loop
	rlf ShiftD,F
	goto col_start
	
row_delay:
	clrwdt
	movlw 0x03
	movwf RowTime
	clrf TMR0
row_c2
	clrwdt	
	movlw 0xff
	subwf TMR0,0
	btfss STATUS,0x02
	goto row_c2
	goto row_d2
row_d2
	clrf TMR0
	bcf STATUS,0x02
	clrwdt	
	decfsz RowTime,1
	goto row_c2
	return

row
	call speaker
row_start
	call scan_com
	movlw 0xff
	movwf PORTB
	movwf PORTD
	movlw 0x01
	movwf ShiftC
	movwf PORTC
	movlw 0x00
	movwf PORTB
	movwf PORTD
	movlw 0x00
	movwf FSR
row_loop
	clrwdt
	call row_delay
	bcf STATUS,0x00
	movlw 0x00
	movwf PORTC
	rlf ShiftC,F
	movf ShiftC,W
	movwf PORTC
	incf FSR,F
	movf FSR,W
	xorlw 0x05
	btfss STATUS,Z
	goto row_loop
	rlf ShiftC,F
	goto row_start


read_char:
	call read_com
	movf ComRecieve,w
	movwf CharHitachi
	return
read_adress:
	call read_com
	movf ComRecieve,w
	bsf ComRecieve,0x06
	movf ComRecieve,W
	movwf AdressHitachi
	call adress_check
	return


write:						;Код записи в Hitachi
	bcf STATUS,RP1
	bcf STATUS,RP0
	clrf PORTD
	movwf PORTB
	bsf PORTC,0x02			;Считывание Hitachi
	call delay_write
	bcf PORTC,0x02
	call delay_write
	return
	
delay_write:				;Задержка для записи
	clrf TMR0
write_c2
	clrwdt	
	movlw 0x15
	subwf TMR0,0
	btfss STATUS,0x02
	goto write_c2
	return


adress_check:
more0
	bsf STATUS,C
	movlw 0x40
	subwf AdressHitachi,0
	btfss STATUS,C
	goto write_error
	goto less20
less20
	movlw 0x60
	subwf AdressHitachi,0
	btfsc STATUS,C
	goto write_error
	return
	

write_error			;Код ERROR
	bcf PORTC,0x00
	movlw 0x01
	call write
	clrwdt
	movlw 0x38
	call write
	movlw 0x06
	call write
	movlw 0x0c
	call write
	bsf PORTC,0x00

	movlw 0x45			;Слово "ERROR"
	call write
	movlw 0x52
	call write
	movlw 0x52
	call write
	movlw 0x4F
	call write
	movlw 0x52
	call write

	movlw 0x00
	movwf PORTB
	movlw 0x00
	movwf PORTC
	clrwdt
	call error_delay
	call redraw
	goto mode_select
error_delay:			;Задержка для ERROR
	clrwdt
	movlw 0x3D
	movwf ErrorTime
	clrf TMR0
error_c
	clrwdt	
	movlw 0xff
	subwf TMR0,0
	btfss STATUS,0x02
	goto error_c
	goto error_d
error_d
	clrf TMR0
	bcf STATUS,0x02
	clrwdt	
	decfsz ErrorTime,1
	goto error_c
	return




speaker:					;Пищалка
	bsf PORTC,0x01
	call speaker_delay
	bcf PORTC,0x01
	call speaker_delay
	bsf PORTC,0x01
	call speaker_delay
	bcf PORTC,0x01
	call speaker_delay
	bsf PORTC,0x01
	call speaker_delay
	bcf PORTC,0x01
	return
speaker_delay:			;Задержка для пищалки
	clrwdt
	movlw 0x0B
	movwf SpeakerTime
	call s_segment
	clrf FSR
	clrf TMR0
speaker_c
	clrwdt	
	movlw 0xff
	subwf TMR0,0
	btfss STATUS,0x02
	goto speaker_c
	goto speaker_d
speaker_d
	clrf TMR0
	bcf STATUS,0x02
	clrwdt	
	decfsz SpeakerTime,1
	goto speaker_c
	return




init_com:
 	bsf STATUS, RP0
 	bcf STATUS, RP1
 	bsf TRISC, 7
 	bsf TRISC, 6
 	bsf TXSTA, BRGH
 	movlw .25
 	movwf SPBRG
 	bcf TXSTA, SYNC
 	bcf TXSTA, TX9
 	bcf STATUS, RP0
 	bcf RCSTA, RX9
 	bsf RCSTA, SPEN
	bsf RCSTA, CREN
 	return

read_com:
 	bcf STATUS, RP0
READ
	clrwdt
	btfss PIR1, RCIF
	goto READ  
 	btfsc RCSTA, OERR
 	goto error1
 	btfsc RCSTA, FERR
 	goto error2
 	movf RCREG,0x00
	movwf ComRecieve
 	return
error1
 	goto STOP
error2 
 	goto STOP
	return

write_com:
	bsf STATUS, RP0
 	bcf STATUS, RP1
 	bsf TXSTA, TXEN
 	bcf STATUS, RP0
 	movwf TXREG
 	bsf STATUS, RP0
write_check
 	btfss TXSTA, TRMT
 	goto write_check
 	bcf TXSTA, TXEN
 	return

draw_hitachi:
	call speaker

	bcf PORTC,0x00
	movlw 0x01
	call write
	movlw 0x02
	call write
	clrwdt
	movlw 0x38
	call write
	movlw 0x06
	call write
	movlw 0x0c
	call write
	bsf PORTC,0x00
	movlw 0x40
	movwf FSR
	bcf STATUS,Z
	clrf PORTB
	

wait_char
	clrwdt
	call delay_write
	btfss PIR1, RCIF
	goto wait_char	
	call read_char
wait_adress
	clrwdt
	call delay_write
	btfss PIR1, RCIF
	goto wait_adress	
	call read_adress

	movf AdressHitachi,w
	movwf FSR	
	movf CharHitachi,w
	movwf INDF
	movlw 0x40
	movwf FSR
draw_loop
	movf INDF,W
	call write

	incf FSR,F
	movf FSR,W
	xorlw 0x50
	btfsc STATUS,Z
	call draw_next
	movf FSR,W
	xorlw 0x60
	btfss STATUS,Z
	goto draw_loop
	bcf STATUS,Z
	clrf PORTB
	clrf PORTD
	clrf PORTC
	clrwdt
	call delay_write
	return
draw_next:				;переход на 2 строку
	clrwdt
	bcf PORTC, 0
	movlw b'11000000'
	call write
	bsf PORTC,0 
	return

redraw:
	bcf PORTC,0x00
	movlw 0x01
	call write
	movlw 0x02
	call write
	clrwdt
	movlw 0x38
	call write
	movlw 0x06
	call write
	movlw 0x0c
	call write
	bsf PORTC,0x00
	movlw 0x40
	movwf FSR
	bcf STATUS,Z
	movlw 0x40
	movwf FSR
redraw_loop
	movf INDF,W
	call write

	incf FSR,F
	movf FSR,W
	xorlw 0x50
	btfsc STATUS,Z
	call redraw_next
	movf FSR,W
	xorlw 0x60
	btfss STATUS,Z
	goto redraw_loop
	bcf STATUS,Z
	clrf PORTB
	clrf PORTD
	clrf PORTC
	clrwdt
	call delay_write
	goto STOP
	return
redraw_next:				;переход на 2 строку
	clrwdt
	bcf PORTC, 0
	movlw b'11000000'
	call write
	bsf PORTC,0 
	return


test_chars:
	movlw 0x40
	movwf FSR
test_loop
	movf FSR,W
	movwf INDF
	incf FSR,F
	movf FSR,W
	xorlw 0x60
	btfss STATUS,Z
	goto test_loop
	return


s_segment:
	movlw 0x00
	movwf FSR

	bsf STATUS,RP0
	bcf STATUS,RP1
	movlw 0x00	
	movwf TRISB
	movlw 0x00	
	movwf TRISD
	bcf STATUS,RP0
	bcf STATUS,RP1

	bcf STATUS,C
	movlw 0xff
	movwf PORTD
s_segment_loop
	rrf PORTD,0
	movwf PORTD

	movf ComRecieve,w
	movwf SCheck

	bsf MirrorCounter,0x03
mirror_loop
	rrf SCheck
	rlf MirrorReg
	decfsz MirrorCounter
	goto mirror_loop

	comf PORTD,0
	andwf MirrorReg,1
	xorwf MirrorReg,0
	
	btfsc STATUS,Z
	goto s_segment_1
	goto s_segment_0
s_segment_inc
	incf FSR,F
	movf FSR,W
	xorlw 0x08
	btfss STATUS,Z
	goto s_segment_loop
	return

s_segment_0
	movlw 0x3f
	movwf PORTB
	goto s_segment_delay
s_segment_1
	movlw 0x06
	movwf PORTB
	goto s_segment_delay

s_segment_delay
	clrf TMR0
s_segment_c
	clrwdt	
	movlw 0x3A
	subwf TMR0,0
	btfss STATUS,0x02
	goto s_segment_c
	goto s_segment_inc


ADC
	call speaker
	clrf PORTB
	clrf PORTD
	bcf STATUS, RP1
	bsf STATUS, RP0
	movlw 0x04
	movwf TRISE
	movlw 0x80
	movwf ADCON1
	bcf STATUS, RP0
	movlw b'01111000'
	movwf ADCON0
ADC_start
	call scan_com
	bsf ADCON0, ADON
	bcf STATUS, RP1
	bsf STATUS, RP0
	movlw 0x04
	movwf TRISE
	movlw 0x80
	movwf ADCON1
	bcf STATUS, RP0
	movlw .5
	call Small_delay
	bsf ADCON0,GO_DONE
ADC_Loop 
	btfsc ADCON0,GO_DONE
	goto ADC_Loop
		
		;передача значения регуляятора
	movf ADRESH,w
	call write_com
	bsf STATUS,RP0
	movf ADRESL,w
	call write_com
	bcf STATUS,RP0
	bcf STATUS,RP1
		
		;передача кода нажатой кнопки
	call key_det
	movlw 0x00
write_key
	call write_com
	call ADC_delay
	goto ADC_start

ADC_delay:			;Задержка для пищалки
	bcf STATUS,RP0
	bcf STATUS,RP1
	bcf STATUS,Z
	clrwdt
	movlw 0x10
	movwf ADCTime
	clrf TMR0
ADC_c
	clrwdt	
	movlw 0xff
	subwf TMR0,0
	btfss STATUS,0x02
	goto ADC_c
	goto ADC_d
ADC_d
	clrf TMR0
	bcf STATUS,0x02
	clrwdt	
	decfsz ADCTime,1
	goto ADC_c
	return
	goto ADC_start

Small_delay:
	bcf STATUS, RP1
	bcf STATUS, RP0
	movwf fCOUNTER
SD_Loop:
	clrwdt
	decfsz fCOUNTER,f
	goto SD_Loop
	return
key_det:
	bcf STATUS,RP1
	bsf STATUS,RP0
	movlw b'00111000'	
	movwf TRISA
	movlw 0x07
	movwf ADCON1
	bcf STATUS,RP0
	bcf STATUS,RP1
	bcf STATUS,Z
	clrf NumPressKey
	movlw 0xff
	movwf PreKey
col1 
	bsf PORTA,0
	bcf PORTA,1
	bcf PORTA,2
	movlw .255
	call Small_delay
	movlw .255
	call Small_delay
	movlw .255
	call Small_delay
	nop
	movf PORTA,w
	andlw 0x38
	movlw 0xff
	btfsc STATUS,Z
	goto col2
	movlw .250
	call Small_delay
	movlw 0xff
	btfsc PORTA,3
	movlw .1
	btfsc PORTA,4
	movlw .4
	btfsc PORTA,5
	movlw .7
col2
	xorwf PreKey,1
	btfss STATUS,Z
	goto write_key
	bcf STATUS,Z
	movlw 0xff
	movwf PreKey
	bcf PORTA,0
	bsf PORTA,1
	bcf PORTA,2
	movlw .255
	call Small_delay
	movlw .255
	call Small_delay
	movlw .255
	call Small_delay
	nop
	movf PORTA,w
	andlw 0x38
	movlw 0xff
	btfsc STATUS,Z
	goto col3
	movlw .250
	call Small_delay
	movlw 0xff
	btfsc PORTA,3
	movlw .2
	btfsc PORTA,4
	movlw .5
	btfsc PORTA,5
	movlw .8

col3
	xorwf PreKey,1
	btfss STATUS,Z
	goto write_key
	bcf STATUS,Z
	movlw 0xff
	movwf PreKey
	bcf PORTA,0
	bcf PORTA,1
	bsf PORTA,2
	movlw .255
	call Small_delay
	movlw .255
	call Small_delay
	movlw .255
	call Small_delay
	nop
	movf PORTA,w
	andlw 0x38
	movlw 0xff
	btfsc STATUS,Z
	goto cnt
	movlw .250
	call Small_delay
	movlw 0xff
	btfsc PORTA,3
	movlw .3
	btfsc PORTA,4
	movlw .6
	btfsc PORTA,5
	movlw .9
cnt
	xorwf PreKey,1
	btfss STATUS,Z
	goto write_key
	return

STOP

	end
