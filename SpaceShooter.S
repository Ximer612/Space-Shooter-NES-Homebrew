.db "NES", $1A, 2, %00000001, %00000001, 0, 0, 0, 0, 0, 0, 0, 0, 0

;made by ximer

.org $8000

.define PLAYER_NUM_SPRITES #14

;ZERO PAGE
.define BACKUP_REG_A    $01
.define BACKUP_REG_X    $02
.define BACKUP_REG_Y    $03
.define BUTTONS         $04
.define ROCKET_TIMER    $05
.define CHECK_PRESSED   $06
.define OLD_SCROLL   $07
.define ROCKET_MAX_TIME #$FF

;CPU VRAM PAGE
.define PLAYERY $0200
.define PLAYERX $0203

.define MISSILEY $0238
.define MISSILEX $023B

;KEYS
.define UP      #$08
.define DOWN    #$04
.define LEFT    #$02
.define RIGHT   #$01
.define FIRE    #$80

;NES ADDRESSES
.define PPUCTRL             $2000
.define PPUMASK             $2001
.define PPUSTATUS           $2002
.define OAMADDR             $2003
.define OAMDATA             $2004
.define PPUSCROLL           $2005
.define PPUADDR             $2006 ; set where to write in PPU Ram
.define PPUDATA             $2007 ; set what to write at PPUADDR, this will increment current PPUADDR too
.define PALETTE             $3F00
.define OAMDMA              $4014 ; dma address
.define APUFRAMECOUNTER     $4017 ; frame counter
.define JOYPAD1             $4016
.define JOYPAD2             $4017

start:
    ;standard start of a cartridge
    SEI
    CLD

    ;reset stack pointer
    LDX #$FF
    TXS

    LDX #0
    STX PPUCTRL
    STX PPUMASK

wait_for_vblank0:
    LDA PPUSTATUS
    AND #%10000000
    BEQ wait_for_vblank0

    ; PPUADDR  = $3F00  
    LDA #>PALETTE
    STA PPUADDR
    LDA #<PALETTE
    STA PPUADDR

	LDX #$00
LOADPALETTES:
	LDA PALETTEDATA,X
	STA PPUDATA
	INX
	CPX #$20
	BNE LOADPALETTES

    LDX #$00
LOADSPRITES:
   LDA SPRITEDATA,X
   STA $0200,X
   INX
   CPX #23*4 ; num sprites x 4 (bytes)
   BNE LOADSPRITES

LOADBACKGROUND:
	LDA PPUSTATUS		;read PPU status to reset high/low latch
	LDA #$20
	STA PPUADDR
	LDA #$00
	STA PPUADDR
	LDX #$00
LOADBACKGROUNDP1:
	LDA BACKGROUNDDATA,X
	STA PPUDATA
	INX
	CPX #$00
	BNE LOADBACKGROUNDP1
LOADBACKGROUNDP2:
	LDA BACKGROUNDDATA+256,X
	STA PPUDATA
	INX
	CPX #$00
	BNE LOADBACKGROUNDP2
LOADBACKGROUNDP3:
	LDA BACKGROUNDDATA,X
	STA PPUDATA
	INX
	CPX #$00
	BNE LOADBACKGROUNDP3
LOADBACKGROUNDP4:
	LDA BACKGROUNDDATA+256,X
	STA PPUDATA
	INX
	CPX #$00
	BNE LOADBACKGROUNDP4

wait_for_vblank_reset:
    LDA PPUSTATUS
    AND #%10000000
    BEQ wait_for_vblank_reset

;Generate an NMI at the start of the vertical blanking interval, background uses second table
    LDA #%10010000 
    STA PPUCTRL

; show sprites, background and remove crt 8 pixel offset
    LDA #%00011000
    STA PPUMASK

    LDA #$00
    STA PPUSCROLL
    STA PPUSCROLL

    STA CHECK_PRESSED

;end setup game

gameloop:

INC ROCKET_TIMER

JSR check_projectile

JMP gameloop

check_projectile:
    LDA ROCKET_TIMER
    CMP ROCKET_MAX_TIME
    BEQ add_velocity
    JMP end_projectile

add_velocity:
    LDA MISSILEY+8
    CMP #$FF
    BEQ destroy_projectile
    DEC MISSILEY
    DEC MISSILEY+4
    DEC MISSILEY+8
    DEC MISSILEY+12
    LDX #0
    STX ROCKET_TIMER
end_projectile:
RTS

destroy_projectile:
    LDA #0
    STA MISSILEX
    STA MISSILEX+4
    STA MISSILEX+8
    STA MISSILEX+12
    STA MISSILEY
    STA MISSILEY+4
    STA MISSILEY+8
    STA MISSILEY+12
RTS

move_UP:
    LDA PLAYERY
    CMP #$04
    BCC after_move_up

    LDX #0
    LDY #0
up_loop:
    DEC PLAYERY,X
    INX
    INX
    INX
    INX
    INY
    CPY PLAYER_NUM_SPRITES
    BNE up_loop

    INC CHECK_PRESSED
JMP after_move_up

move_DOWN:
    LDA $0230 ; player y + 30 => bottom sprite for a bottom collision check
    CMP #$E8
    BCS after_move_down

    LDX #0
    LDY #0
down_loop:
    INC PLAYERY,X
    INX
    INX
    INX
    INX
    INY
    CPY PLAYER_NUM_SPRITES
    BNE down_loop

    INC CHECK_PRESSED
JMP after_move_down

buttons_check:
    STA BACKUP_REG_A

    LDA BUTTONS
    CMP #$00
    BEQ no_key_pressed

    LDA BUTTONS    
    AND UP
    BNE move_UP
after_move_up:

    LDA BUTTONS
    AND DOWN
    BNE move_DOWN
after_move_down:

    LDA BUTTONS
    AND LEFT
    BNE move_LEFT
after_move_left:

    LDA BUTTONS
    AND RIGHT
    BNE move_RIGHT
after_move_right:

    LDA BUTTONS
    AND FIRE
    BNE fire_projectile
after_fire_projectile:

end_buttons:

    LDA BACKUP_REG_A
RTS

move_LEFT:
    LDX #0
    LDY #0
left_loop:
    DEC PLAYERX,X
    INX
    INX
    INX
    INX
    INY
    CPY PLAYER_NUM_SPRITES
    BNE left_loop

    INC CHECK_PRESSED
JMP after_move_left

move_RIGHT:
    LDX #0
    LDY #0
right_loop:
    INC PLAYERX,X
    INX
    INX
    INX
    INX
    INY
    CPY PLAYER_NUM_SPRITES
    BNE right_loop

    INC CHECK_PRESSED
JMP after_move_right

no_key_pressed:
    LDX #0
    STX CHECK_PRESSED
JMP end_buttons



fire_projectile:

    LDA MISSILEY+8
    CMP #$FF
    BNE after_fire_projectile

    LDX #0
    LDY #0

    STX ROCKET_TIMER

    LDA PLAYERX
    STA MISSILEX
    STA MISSILEX+4

    ADC #7
    STA MISSILEX+8
    STA MISSILEX+12

    LDA PLAYERY
    SBC #8
    STA MISSILEY
    STA MISSILEY+4+4

    ADC #7
    STA MISSILEY+4
    STA MISSILEY+4+4+4

    INC CHECK_PRESSED
JMP after_fire_projectile

; At the same time that we strobe bit 0, we initialize the ring counter
; so we're hitting two birds with one stone here
read_joy:
    lda #01
    ; While the strobe bit is set, buttons will be continuously reloaded.
    ; This means that reading from JOYPAD1 will only return the state of the
    ; first button: button A.
    sta BUTTONS

    sta JOYPAD1
    LDA #0
    ; By storing 0 into JOYPAD1, the strobe bit is cleared and the reloading stops.
    ; This allows all 8 buttons (newly reloaded) to be read from JOYPAD1.
    sta JOYPAD1
read_joy_loop:
    lda JOYPAD1
    lsr A	       ; bit 0 -> Carry
    rol BUTTONS  ; Carry -> bit 0; bit 7 -> Carry
    bcc read_joy_loop
  rts

nmi:
    ;backups registers values
    STA BACKUP_REG_A
    STX BACKUP_REG_X
    STY BACKUP_REG_Y

    JSR read_joy
    JSR buttons_check
    ;uploads the CPU vram page to the PPU OAM
    LDA #$00
    STA OAMADDR
    LDA  #$02
    STA OAMDMA
    ;192 cycles to complete ^

    ;VERTICAL SCROLLING
    LDA #$00
    STA PPUSCROLL

    DEC OLD_SCROLL
    LDA OLD_SCROLL
    STA PPUSCROLL    

    ;restore registers values
    LDA BACKUP_REG_A
    LDX BACKUP_REG_X
    LDY BACKUP_REG_Y
RTI

irq:
RTI

PALETTEDATA:
	.db $01, $20, $27, $17, 	$00, $0A, $15, $01, 	$00, $29, $28, $27, 	$00, $34, $24, $14 	;first table
	.db $01, $0F, $15, $30, 	$0F, $0F, $26, $30, 	$00, $0F, $30, $27, 	$0F, $16, $18, $27 	;second table

SPRITEDATA:
    ; space ship
    .db $40, $01, %00000001, $50+$8
    .db $40, $01, %01000001, $50+$8+$8

    .db $40+$8, $10, %00000001, $50
    .db $40+$8, $11, %00000001, $50+$8
    .db $40+$8, $11, %01000001, $50+$8+$8
    .db $40+$8, $10, %01000001, $50+$8+$8+$8

    .db $40+$8+$8, $20, %00000001, $50
    .db $40+$8+$8, $21, %00000001, $50+$8
    .db $40+$8+$8, $21, %01000001, $50+$8+$8
    .db $40+$8+$8, $20, %01000001, $50+$8+$8+$8

    .db $40+$8+$8+$8, $30, %00000001, $50
    .db $40+$8+$8+$8, $31, %00000001, $50+$8
    .db $40+$8+$8+$8, $31, %01000001, $50+$8+$8
    .db $40+$8+$8+$8, $30, %01000001, $50+$8+$8+$8

    ; MISSILE
    .db $00, $02, %00000000, $00
    .db $00, $12, %00000000, $00

    .db $00, $02, %01000000, $00
    .db $00, $13, %00000000, $00

    ; 8 BIT PIXEL FACE
    .db $40, $03, %00000011, $40

    ; 16 BIT PIXEL FACE
    .db $D0, $04, %00000011,   $D5
    .db $D0, $05, %00000011,   $D5+8
    .db $D0+8, $14, %00000011, $D5
    .db $D0+8, $15, %00000011, $D5+8

BACKGROUNDDATA:
    .db $00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

.goto $FFFA

.dw nmi
.dw start
.dw irq

.incbin "space.chr"
.fill 4096 $00