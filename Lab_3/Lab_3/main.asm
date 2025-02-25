;***********************************************
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; Lab_3.asm
;
; Autor     : José de Jesus Valenzuela Velásquez
; Proyecto  : Laboratorio No. 3
; Hardware  : ATmega328PB
; Creado    : 18/02/2025
; Modificado: 18/02/2025
; Descripción: Este programa implementa dos contadores:
;              1. Un contador binario de 4 bits controlado por botones
;              2. Un contador decimal (0-9) controlado por Timer0 mostrado en display 7 segmentos
;***********************************************

; Incluye el archivo de definiciones del ATmega328PB
.include "m328pbdef.inc"

;***********************************************
; VECTORES DE INTERRUPCIÓN
;***********************************************
.org 0x0000                  ; Vector de reset
    rjmp SETUP              ; Salta a la rutina de configuración al iniciar
.org PCINT0addr             ; Vector de interrupción para cambios en PORTB
    rjmp ISR_PCINT0         ; Salta a la rutina de interrupción de botones
.org TIMER0_OVFaddr         ; Vector de interrupción para overflow del Timer0
    rjmp TMR0_ISR           ; Salta a la rutina de interrupción del timer

;***********************************************
; DEFINICIÓN DE REGISTROS
;***********************************************
.def counter = r16          ; R16: Almacena el valor del contador de botones
.def temp = r17             ; R17: Registro temporal para operaciones
.def state_change = r18     ; R18: Almacena el estado anterior de los botones
.def timer_counter = r19    ; R19: Contador para el timer
.def ms_counter = r20       ; R20: Contador de milisegundos
.def display_val = r21      ; R21: Valor actual mostrado en el display

; =================================================
; Tabla de valores para display 7 segmentos (0-9)
; =================================================
; Cada valor representa el patrón de segmentos para mostrar números del 0-9
TABLA7SEG:
    .db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F

;************************************************
; RUTINA DE CONFIGURACIÓN
;************************************************
SETUP:
	cli                    ; deshabilita interrupciones globales

    ; Inicialización del Stack Pointer
    ldi temp, high(RAMEND)  ; Carga el byte alto de la última dirección de RAM
    out SPH, temp           ; Configura Stack Pointer High
    ldi temp, low(RAMEND)   ; Carga el byte bajo de la última dirección de RAM
    out SPL, temp           ; Configura Stack Pointer Low

    ; Desactiva UART para usar PD0 y PD1 como GPIO
    ldi temp, 0x00          
    sts UCSR0B, temp        ; Desactiva TX y RX
    sts UCSR0C, temp        ; Limpia configuración UART

    ; Configuración de PORTB (Botones)
    ldi temp, 0x00          
    out DDRB, temp          ; Configura PORTB como entradas
    ldi temp, 0x03          
    out PORTB, temp         ; Activa pull-ups en PB0 y PB1

    ; Configuración de PORTC (LEDs)
    ldi temp, 0x0F          
    out DDRC, temp          ; PC0-PC3 como salidas
    ldi temp, 0x00          
    out PORTC, temp         ; Inicializa LEDs apagados

    ; Configuración de PORTD (Display 7 segmentos)
    ldi temp, 0xFF          
    out DDRD, temp          ; Todo PORTD como salida
    ldi temp, 0xFF          
    out PORTD, temp         ; Inicializa display apagado

    ; Configuración Timer0
    ldi temp, 0x00          
    out TCCR0A, temp        ; Modo normal del timer
    ldi temp, 0x05          
    out TCCR0B, temp        ; Prescaler 1024
    ldi temp, 0x01          
    sts TIMSK0, temp        ; Habilita interrupción por overflow

    ; Configuración interrupciones PCINT
    ldi temp, 0x03          
    sts PCMSK0, temp        ; Habilita PCINT en PB0 y PB1
    ldi temp, 0x01          
    sts PCICR, temp         ; Habilita grupo PCIE0

    ; Inicialización de variables
    clr counter             ; Limpia contador de botones
    clr timer_counter       ; Limpia contador del timer
    clr ms_counter          ; Limpia contador de milisegundos
    clr display_val         ; Limpia valor del display
    in state_change, PINB   ; Lee estado inicial de botones
	
	sei   ;Habilita interrupciones globales.


;***********************************************
; LOOP PRINCIPAL
;***********************************************
MAIN:
    out PORTC, counter      ; Muestra valor del contador en LEDs
    
    ; Actualización del display 7 segmentos
    ldi ZH, high(TABLA7SEG*2)  ; Carga byte alto de dirección de tabla
    ldi ZL, low(TABLA7SEG*2)   ; Carga byte bajo de dirección de tabla
    add ZL, display_val        ; Suma offset para obtener número correcto
    lpm temp, Z               ; Lee valor de la tabla
    out PORTD, temp           ; Actualiza display

    rjmp MAIN                 ; Repite el loop

;***********************************************
; RUTINA DE INTERRUPCIÓN DE BOTONES
;***********************************************
ISR_PCINT0:
    push temp                ; Guarda valor temporal
    in temp, SREG            ; Guarda registro de estado
    push temp

    in temp, PINB            ; Lee estado actual de botones
    
    sbic PINB, 0             ; Si PB0 está presionado
    rjmp CHECK_DEC           ; Revisa botón de decremento
    inc counter              ; Incrementa contador

CHECK_DEC:
    sbic PINB, 1             ; Si PB1 está presionado
    rjmp ACTUALIZAR_ESTADO   ; Salta a actualizar estado
    dec counter              ; Decrementa contador

ACTUALIZAR_ESTADO:
    andi counter, 0x0F       ; Mantiene contador en 4 bits

NO_CHANGE:
    pop temp                 ; Recupera registro de estado
    out SREG, temp
    pop temp                 ; Recupera valor temporal
    reti                     ; Retorna de interrupción

;***********************************************
; RUTINA DE INTERRUPCIÓN DEL TIMER0
;***********************************************
TMR0_ISR:
    push temp                ; Guarda valor temporal
    in temp, SREG           ; Guarda registro de estado
    push temp

    inc ms_counter          ; Incrementa contador de milisegundos
    cpi ms_counter, 50      ; Compara con 50 (~1000ms)
    brne TMR0_EXIT          ; Si no es igual, sale

    clr ms_counter          ; Reinicia contador de milisegundos
    inc display_val         ; Incrementa valor del display

    cpi display_val, 10     ; Compara con 10
    brne TMR0_EXIT          ; Si no es 10, sale
    clr display_val         ; Reinicia display a 0

TMR0_EXIT:
    pop temp                ; Recupera registro de estado
    out SREG, temp
    pop temp                ; Recupera valor temporal
    reti                    ; Retorna de interrupción