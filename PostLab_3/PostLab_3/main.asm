;***********************************************
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; PostLab_3.asm
;
; Autor     : José de Jesus Valenzuela Velásquez
; Proyecto  : Laboratorio No. 3
; Hardware  : ATmega328PB
; Creado    : 19/02/2025
; Modificado: 19/02/2025
; 
; Descripción: Este programa implementa dos funcionalidades:
;   1. Un contador binario de 4 bits controlado por dos botones (incremento/decremento)
;   2. Un contador de segundos (0-59) usando Timer0, mostrado en dos displays de 7 segmentos
;      - Display 1: Unidades de segundos (0-9)
;      - Display 2: Decenas de segundos (0-5)
;***********************************************

; Incluye definiciones del microcontrolador ATmega328PB
.include "m328pbdef.inc"

;***********************************************
; VECTORES DE INTERRUPCIÓN
;***********************************************
.org 0x0000                  ; Vector de reset - Primera instrucción al encender
    rjmp SETUP              ; Salta a la configuración inicial
.org PCINT0addr             ; Vector de interrupción para cambios en PORTB (botones)
    rjmp ISR_PCINT0         ; Salta a la rutina de manejo de botones
.org TIMER0_OVFaddr         ; Vector de interrupción para desbordamiento del Timer0
    rjmp TMR0_ISR           ; Salta a la rutina del contador de segundos

;***********************************************
; DEFINICIÓN DE REGISTROS
;***********************************************
.def counter = r16          ; R16: Contador de 4 bits controlado por botones
.def temp = r17             ; R17: Registro temporal para operaciones
.def timer_counter = r19    ; R19: Contador auxiliar para el timer
.def ms_counter = r20       ; R20: Contador de milisegundos
.def display_val = r21      ; R21: Valor de unidades (0-9) para display
.def decenas = r22          ; R22: Valor de decenas (0-5) para display
.def display_select = r23   ; R23: Selector de display (0=unidades, 1=decenas)

;***********************************************
; TABLA DE VALORES PARA DISPLAY 7 SEGMENTOS
;***********************************************
TABLA7SEG:                  ; Patrones para mostrar números 0-9 en display cátodo común
    .db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F

;***********************************************
; RUTINA DE CONFIGURACIÓN INICIAL
;***********************************************
SETUP:
    cli                     ; Deshabilita interrupciones durante configuración

    ; Configuración del Stack Pointer al final de la RAM
    ldi temp, high(RAMEND)  ; Carga byte alto de última dirección RAM
    out SPH, temp           ; Configura Stack Pointer High
    ldi temp, low(RAMEND)   ; Carga byte bajo de última dirección RAM
    out SPL, temp           ; Configura Stack Pointer Low

    ; Deshabilita UART para usar PD0 y PD1 como GPIO
    ldi temp, 0x00
    sts UCSR0B, temp        ; Deshabilita TX y RX
    sts UCSR0C, temp        ; Limpia configuración UART

    ; Configura PORTB para botones
    ldi temp, 0x00          
    out DDRB, temp          ; Todo PORTB como entrada
    ldi temp, 0x03          
    out PORTB, temp         ; Activa pull-ups en PB0 y PB1

    ; Configura PORTC para LEDs y control de displays
    ldi temp, 0x3F          ; PC0-PC3: LEDs, PC4-PC5: control de displays
    out DDRC, temp          ; Configura como salidas
    ldi temp, 0x00          
    out PORTC, temp         ; Inicializa todo en bajo

    ; Configura PORTD para segmentos del display
    ldi temp, 0xFF          
    out DDRD, temp          ; Todo PORTD como salida
    ldi temp, 0xFF          
    out PORTD, temp         ; Inicializa display apagado

    ; Configura Timer0 para generar base de tiempo de 1 segundo
    ldi temp, 0x00          
    out TCCR0A, temp        ; Modo normal
    ldi temp, 0x05          
    out TCCR0B, temp        ; Prescaler 1024
    ldi temp, 0x01          
    sts TIMSK0, temp        ; Habilita interrupción por overflow

    ; Configura interrupciones para botones
    ldi temp, 0x03          
    sts PCMSK0, temp        ; Habilita PCINT en PB0 y PB1
    ldi temp, 0x01          
    sts PCICR, temp         ; Habilita grupo PCIE0

    ; Inicializa variables
    clr counter             ; Limpia contador de botones
    clr timer_counter       ; Limpia contador del timer
    clr ms_counter          ; Limpia contador de milisegundos
    clr display_val         ; Limpia valor de unidades
    clr decenas             ; Limpia valor de decenas
    clr display_select      ; Inicia mostrando unidades


    sei                     ; Habilita interrupciones globales

;***********************************************
; LOOP PRINCIPAL
;***********************************************
MAIN:
    out PORTC, counter      ; Muestra contador de botones en LEDs

    ; Sistema de multiplexación para displays
    sbrc display_select, 0  ; Salta siguiente instrucción si bit 0 es 0
    rjmp SHOW_DECENAS       ; Si display_select es 1, muestra decenas

SHOW_UNIDADES:
    ; Obtiene patrón para unidades desde tabla
    ldi ZH, high(TABLA7SEG*2)
    ldi ZL, low(TABLA7SEG*2)
    add ZL, display_val     ; Suma offset para número correcto
    lpm temp, Z             ; Lee patrón de la tabla
    out PORTD, temp         ; Muestra patrón en display
    sbi PORTC, 4           ; Activa transistor de unidades
    cbi PORTC, 5           ; Desactiva transistor de decenas
    ldi temp, 0x01
    mov display_select, temp ; Próxima vez muestra decenas
    rjmp MAIN_END

SHOW_DECENAS:
    ; Obtiene patrón para decenas desde tabla
    ldi ZH, high(TABLA7SEG*2)
    ldi ZL, low(TABLA7SEG*2)
    add ZL, decenas         ; Suma offset para número correcto
    lpm temp, Z             ; Lee patrón de la tabla
    out PORTD, temp         ; Muestra patrón en display
    cbi PORTC, 4           ; Desactiva transistor de unidades
    sbi PORTC, 5           ; Activa transistor de decenas
    clr display_select      ; Próxima vez muestra unidades

MAIN_END:
    rjmp MAIN              ; Repite el loop principal

;***********************************************
; RUTINA DE INTERRUPCIÓN PARA BOTONES
;***********************************************
ISR_PCINT0:
    ; Guarda contexto
    push temp
    in temp, SREG
    push temp

    in temp, PINB           ; Lee estado actual de botones
    
    sbic PINB, 0           ; Si PB0 está presionado (incremento)
    rjmp CHECK_DEC
    inc counter            ; Incrementa contador

CHECK_DEC:
    sbic PINB, 1           ; Si PB1 está presionado (decremento)
    rjmp ACTUALIZAR_ESTADO
    dec counter            ; Decrementa contador

ACTUALIZAR_ESTADO:
    andi counter, 0x0F     ; Mantiene contador en 4 bits (0-15)

    ; Restaura contexto
    pop temp
    out SREG, temp
    pop temp
    reti                   ; Retorna de la interrupción

;***********************************************
; RUTINA DE INTERRUPCIÓN DEL TIMER0
;***********************************************
TMR0_ISR:
    ; Guarda contexto
    push temp
    in temp, SREG
    push temp

    inc ms_counter         ; Incrementa contador de milisegundos
    cpi ms_counter, 50     ; Compara con 50 (~1000ms)
    brne TMR0_EXIT         ; Si no es igual, sale

    clr ms_counter         ; Reinicia contador de milisegundos
    inc display_val        ; Incrementa unidades

    cpi display_val, 10    ; Compara unidades con 10
    brne TMR0_EXIT         ; Si no es 10, sale
    
    clr display_val        ; Reinicia unidades a 0
    inc decenas           ; Incrementa decenas
    
    cpi decenas, 6        ; Compara decenas con 6 (60 segundos)
    brne TMR0_EXIT         ; Si no es 6, sale
    clr decenas           ; Reinicia decenas a 0
    clr display_val       ; Reinicia unidades a 0

TMR0_EXIT:
    ; Restaura contexto
    pop temp
    out SREG, temp
    pop temp
    reti                   ; Retorna de la interrupción
