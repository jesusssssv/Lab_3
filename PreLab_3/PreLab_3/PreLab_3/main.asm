;***********************************************
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; PreLab_3.asm
;
; Autor     : José de Jesus Valenzuela Velásquez
; Proyecto  : Laboratorio No. 3
; Hardware  : ATmega328PB
; Creado    : 10/02/2025
; Modificado: 11/02/2025
; Descripción: Este programa un contador binario de 4 bits en donde se utilizan interrupciones
;			   con un bóton se incrementa y con otro se decrementa.
;***********************************************

.include "m328pbdef.inc"    ; Incluye definiciones específicas del ATmega328PB



;***********************************************
; VECTORES DE INTERRUPCIÓN
;***********************************************
.org 0x0000                  ; Define el origen del código en la dirección 0x0000 (vector de reset)
    rjmp SETUP              ; Cuando el micro se resetea, salta a la etiqueta SETUP
.org PCINT0addr             ; Define la dirección de la interrupción PCINT0
    rjmp ISR_PCINT0         ; Cuando ocurre la interrupción PCINT0, salta a ISR_PCINT0

;***********************************************
; DEFINICIÓN DE REGISTROS
;***********************************************
.def counter = r16          ; Asigna el registro r16 para usar como contador
.def temp = r17             ; Asigna el registro r17 para operaciones temporales
.def state_change = r18     ; Asigna el registro r18 para el estado de los botones

;************************************************
; RUTINA DE CONFIGURACIÓN
;************************************************
SETUP:
    ; Configuración del Stack Pointer
    ldi temp, high(RAMEND)  ; Carga en temp el byte alto de la última dirección de RAM
    out SPH, temp           ; Configura el Stack Pointer High
    ldi temp, low(RAMEND)   ; Carga en temp el byte bajo de la última dirección de RAM
    out SPL, temp           ; Configura el Stack Pointer Low

    ; Configuración de PORTB (Botones)
    ldi temp, 0x00          ; Carga 0x00 en temp
    out DDRB, temp          ; Configura PORTB como entradas (0 = entrada)
    ldi temp, 0x03          ; Carga 0x03 (0b00000011) en temp
    out PORTB, temp         ; Activa resistencias pull-up en PORTB0 y PORTB1

    ; Configuración de PORTC (LEDs)
    ldi temp, 0x0F          ; Carga 0x0F (0b00001111) en temp
    out DDRC, temp          ; Configura PORTC0-3 como salidas (1 = salida)
    ldi temp, 0x00          ; Carga 0x00 en temp
    out PORTC, temp         ; Inicializa todos los LEDs apagados

    ; Configuración de interrupciones
    ldi temp, 0x03          ; Carga 0x03 en temp
    sts PCMSK0, temp        ; Habilita interrupciones en PCINT0 y PCINT1
    ldi temp, 0x01          ; Carga 0x01 en temp
    sts PCICR, temp         ; Habilita el grupo de interrupciones PCIE0

    clr counter             ; Limpia (pone a 0) el registro contador
    in state_change, PINB   ; Lee el estado inicial de los botones
    sei                     ; Habilita las interrupciones globales

;***********************************************
; LOOP PRINCIPAL
;***********************************************
MAIN:
    out PORTC, counter      ; Muestra el valor del contador en los LEDs
    rjmp MAIN              ; Salta al inicio del loop principal


;***********************************************
; RUTINA DE INTERRUPCIÓN
;***********************************************
ISR_PCINT0:
    push temp              ; Guarda el valor de temp en la pila
    in temp, SREG          ; Lee el registro de estado
    push temp              ; Guarda el registro de estado en la pila

    in temp, PINB          ; Lee el estado actual de los botones
    eor temp, state_change ; XOR para detectar cambios (1 donde hubo cambio)
    andi temp, 0x03        ; Mantiene solo los bits de PORTB0 y PORTB1

    breq NO_CHANGE         ; Si no hay cambios (temp = 0), salta a no_change

    ; Manejo del botón de incremento
    sbic PINB, 0           ; Salta la siguiente instrucción si PINB0 = 0
    rjmp CHECK_DEC         ; Si PINB0 = 1, salta a verificar el otro botón
    inc counter            ; Incrementa el contador

CHECK_DEC:
    ; Manejo del botón de decremento
    sbic PINB, 1				; Salta la siguiente instrucción si PINB1 = 0
    rjmp ACTUALIZAR_ESTADO      ; Si PINB1 = 1, salta a actualizar estado
    dec counter					; Decrementa el contador

ACTUALIZAR_ESTADO:
    andi counter, 0x0F     ; Mantiene el contador en el rango 0-15
    in state_change, PINB  ; Actualiza el estado de los botones

NO_CHANGE:
    pop temp               ; Recupera el registro de estado
    out SREG, temp         ; Restaura el registro de estado
    pop temp               ; Recupera el valor original de temp
    reti                   ; Retorna de la interrupción