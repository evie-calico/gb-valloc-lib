INCLUDE "hardware.inc"

SECTION "entry", ROM0[$100]
    jp Start
    DS $150 - @, 0

SECTION "main", ROM0
Start:
    ldh a, [rLY]
    cp a, SCRN_Y
    jr c, Start

    xor a, a
    ldh [rLCDC], a
    ld a, %11100100
    ldh [rBGP], a

    ; Before calling Valloc functions, you must call VallocPurge to prepare
    ; WRAM.
    call VallocPurge

    ; Now allocate a buncha VRAM...
    ; We'll loop 48 times, allocating 96 blocks.
    ld b, 48
.fillVRAM
        push bc
        ; This tile should be displayable on the background.
        ld hl, wVallocBackground
        ; Allocate one block. By default, this is 4 tiles.
        ld c, 1
        ; This will overflow into the shared area when needed.
        call VallocShared
        ; This tile should be displayable as an object.
        ld hl, wVallocObjects
        ld c, 1
        call VallocShared
        pop bc
        dec b
        jr nz, .fillVRAM

    ; ...and purge VRAM, effectively freeing every block!
    ; This is useful when closing a menu or unloading a map, and means you can
    ; forget about tile indices without worrying about a memory leak.
    call VallocPurge

    ; Valloc and VallocShared return the index of the tile they allocated.
    ld hl, wVallocBackground
    ; We'll allocate 24 blocks this time, which is 96 tiles.
    ld c, 24
    call VallocShared
    ; We need to store the resulting tile ID so that we can use it later.
    ld a, b ; The result is returned in the b register.
    ld [wLuvuiTileID], a

    ; Let's get the address of our tile so that we can load graphics to it!
    ; VallocGetAddr expects a tile ID in the a register, so we can just tell it
    ; which area of memory we expect ($8000 for background, $9000 for objects)
    ; and it'll give us the address.
    ld hl, $9000
    call VallocGetAddr
    ; Now we can copy a spritesheet into VRAM!
    ld de, LuvuiGraphics
    ld bc, LuvuiGraphics.end - LuvuiGraphics
    call MemCopy

    ; I also want a blank tile, to fill up the parts of the screen I'm not
    ; using.
    ld hl, wVallocBackground
    ; Here I'm allocating 1 block, which is 4 tiles, even though I only need
    ; one. While being able to allocate single tiles would be useful, it would
    ; also be a bit slower and use much more RAM. For this reason, the default
    ; block size is 4 tiles, but you can change this in valloc_lib.asm to fit
    ; your needs.
    ld c, 1
    call VallocShared
    ld a, b
    ld [wBlankTileID], a

    ld hl, $9000
    call VallocGetAddr
    xor a, a
    ld bc, 16
    call MemSet ; Make sure the tile is clear

    ; Finally, let's draw our graphics on the screen!
    ; First, clear the screen...
    ld a, [wBlankTileID]
    ld hl, $9800
    ld bc, 32 * 32
    call MemSet

    ; Then draw Luvui in the corner, facing towards us!
    ld a, [wLuvuiTileID]
    add a, 34
    ld [$9821], a
    inc a
    ld [$9822], a
    add a, 7
    ld [$9841], a
    inc a
    ld [$9842], a

    ld a, LCDCF_BGON | LCDCF_ON
    ld [rLCDC], a

.loop
    ei
    halt
    jr .loop

LuvuiGraphics:
    INCBIN "res/luvui.2bpp"
.end

SECTION "Tile IDs", WRAM0
wLuvuiTileID:
    db
wBlankTileID:
    db