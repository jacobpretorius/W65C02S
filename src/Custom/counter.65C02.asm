PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

value = $0200 // 2 bytes
mod10 = $0202 // 2 bytes
message = $0204 // 6 bytes
counter = $020a // 2 bytes
dcount = $0210 // 2 bytes

E  = %10000000
RW = %01000000
RS = %00100000

  .org $8000

reset:
  ldx #$ff
  txs

  lda #%11111111 // Set all pins on port B to output
  sta DDRB
  lda #%11100000 // Set top 3 pins on port A to output
  sta DDRA

  lda #%00111000 // Set 8-bit mode// 2-line display// 5x8 font
  jsr lcd_instruction
  lda #%00001110 // Display on// cursor on// blink off
  jsr lcd_instruction
  lda #%00000110 // Increment and shift cursor// don't shift display
  jsr lcd_instruction
  lda #$00000001 // Clear display
  jsr lcd_instruction

  // Init counter to 0
  lda #0
  sta counter
  sta counter + 1

loop:
  lda #%00000010 // Put LCD cursor at start
  jsr lcd_instruction

  // Delay
  jsr delay


inc_count:
  inc counter // updates fZ with status of increment result
  bne no_overfl // jump to loc if fZ is not set
  inc counter + 1 

no_overfl:
  lda #0
  sta message

  // Init value to be the counter to convert
  lda counter
  sta value
  lda counter + 1
  sta value + 1
  

divide:
  lda #0
  sta mod10
  sta mod10 + 1
  clc

  ldx #16
divloop:
  // Rotate quotient and remainder
  rol value
  rol value + 1
  rol mod10
  rol mod10 + 1

  // a,y = divident - divisor
  sec
  lda mod10
  sbc #10
  tay // Save low byte in Y
  lda mod10 + 1
  sbc #0
  bcc ignore_result // Branch if divident < divisor
  sty mod10
  sta mod10 + 1
ignore_result
  dex
  bne divloop
  rol value // Shift in the last bit of the quotient
  rol value + 1

  lda mod10
  clc
  adc #"0"
  jsr push_char

  // If value != 0 then continue
  lda value
  ora value + 1
  bne divide // Branch if value not zero

  ldx #0

print:
  lda message,x
  beq loop
  jsr print_char
  inx
  jmp print

// Add the char in A reg to the begining of null-term
// string 'message'
push_char:
  pha // Push new first char to stack
  ldy #0

char_loop:
  lda message,y // Get char on string and put into X
  tax
  pla
  sta message,y // Pull char off stack and add to string
  iny
  txa
  pha // Push char from string onto stack
  bne char_loop

  pla
  sta message,y // Pull null off stack and add to end of string
  rts

lcd_wait:
  pha
  lda #%00000000  // Port B is input
  sta DDRB

lcdbusy:
  lda #RW
  sta PORTA
  lda #(RW | E)
  sta PORTA
  lda PORTB
  and #%10000000
  bne lcdbusy

  lda #RW
  sta PORTA
  lda #%11111111  // Port B is output
  sta DDRB
  pla
  rts

lcd_instruction:
  jsr lcd_wait
  sta PORTB
  lda #0         // Clear RS/RW/E bits
  sta PORTA
  lda #E         // Set E bit to send instruction
  sta PORTA
  lda #0         // Clear RS/RW/E bits
  sta PORTA
  rts

print_char:
  jsr lcd_wait
  sta PORTB
  lda #RS         // Set RS// Clear RW/E bits
  sta PORTA
  lda #(RS | E)   // Set E bit to send instruction
  sta PORTA
  lda #RS         // Clear E bits
  sta PORTA
  rts

delay
  inc dcount        // updates fZ with status of increment result
  bne delay         // jump to loc if fZ is not set
  inc dcount + 1 
  bne delay         // jump to loc if fZ is not set for second bit
  rts               // we can only reach this once both bits have overflowed

  .org $fffc
  .word reset
  .word $0000
