;
; valloc_lib.asm
; A library for allocating VRAM memory at runtime.
;
; Copyright 2021 Eievui
;
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.


; --- Config ---
; Double the valloc memory and allow allocation in the CGB's second bank.
DEF ENABLE_CGB EQU 0
; How many tiles does each block take up? 1 tile is 16 bytes.
DEF BLOCK_SIZE EQU 4

ASSERT BLOCK_SIZE <= 16, "Valloc block size must be less or equal to 16"
ASSERT LOG(BLOCK_SIZE * 1.0, 2.0) & $FFFF == 0, "Valloc block size must be a power of 2"

DEF BLOCK_EXPO EQU LOG(BLOCK_SIZE * 1.0, 2.0) / 1.0
DEF REGION_SIZE EQU (128 / BLOCK_SIZE) * (1 + ENABLE_CGB)

SECTION "Allocate Video Memory", ROM0
VallocPurge::
    xor a, a
    ld bc, REGION_SIZE * 3
    ld hl, wVallocBackground
    ASSERT wVallocBackground + REGION_SIZE == wVallocShared
    ASSERT wVallocShared + REGION_SIZE == wVallocObjects
    jp MemSet

; Allocate a block of memory in VRAM.
; @ c:  Number of tiles to allocate.
; @ hl: Which tile type to allocate, either wVallocBackground, wVallocObjects,
;       or wValloxShared
; @ Returns the index in b.
; @ Returns 0 in the a register upon success, and a non-zero value on failure.
Valloc:
    ld b, 0 ; Tile Index.
    ; Find an available memory block.
.findBlock
    ld a, [hli]
    and a, a
    jr z, .foundBlock
    ; Skip reserved blocks (They appear free, so must be ignored!)
    ; a already contains the block's size, so muliply it by BLOCK_SIZE and add it
    ; to b
    dec hl
    ld d, 0
    ld e, a
    add hl, de
    ; And skip those indices.
    ;ld a, e (a already equals e)
    add a, b
    ld b, a
    ; If the tile index has overflowed, valloc should fail.
    cp a, 128 / BLOCK_SIZE
    jr c, .findBlock
.fail
    ret

.foundBlock
    ; Fail if there isn't enough room left here.
    ld a, b
    add a, c
    cp a, 128 / BLOCK_SIZE + 1
    jr nc, .fail
    ld d, c
.verifySize
    dec d
    jr z, .success
    ; Check if the following blocks are already reserved.
    ld a, [hli]
    and a, a
    jr nz, .findBlock
    jr .verifySize
.success
    ; Seek back the the first block found and reserve it.
    ld a, l
    sub a, c
    ld l, a
    ld a, h
    sbc a, 0
    ld h, a
    ; Set the reserved blocks.
    ld a, c
    ld [hl], a
    ; Abjust b to be an index rather than a block ID.
    ld a, b
    REPT BLOCK_EXPO
        add a, a
    ENDR
    ld b, a
    xor a, a ; a == 0 == success!
    ret

SECTION "Valloc Shared", ROM0
; Allocate a block of memory in VRAM which is usable as either background or
; object tiles. This will overflow into the shared area if needed.
; @ c:  Number of tiles to allocate.
; @ hl: Which tile type to allocate, either wVallocBackground or wVallocObjects.
; @ Returns the address of tile in de and the index in b.
VallocShared::
    push bc
    call Valloc
.hook
    and a, a ; zero means success!
    jr nz, .fail
    pop de
    ret
.fail
    pop bc
    ld hl, wVallocShared
    call Valloc
    add a, 128
    ld b, a
    ret

SECTION "Valloc Free", ROM0
; Free a previously allocated block of memory.
; @ a:  Tile index
; @ hl: Tile type, either wVallocBackground or wVallocObjects.
VallocFree::
    REPT BLOCK_EXPO
        rra
    ENDR
    IF BLOCK_EXPO
        and a, $7F >> BLOCK_EXPO
    ENDC
    cp a, 128 / BLOCK_SIZE
    jr c, .notShared
    ld hl, wVallocShared - REGION_SIZE
.notShared

    add a, l
    ld l, a
    adc a, h
    sub a, l
    ld h, a
    ld [hl], 0
    ret

SECTION "Get Index Address", ROM0
; Offsets a VRAM address by a tile index, switching to the shared section if
; needed.
; @ a:  Tile index.
; @ hl: Which area of VRAM is expected, either $8000 (Objects) or $9000
;       (Background)
VallocGetAddr::
    cp a, 128
    jr c, .notShared
    ld hl, $8000
.notShared

    add a, l
    ld l, a
    adc a, h
    sub a, l
    ld h, a
    ret

SECTION "Valloc Usage Map", WRAM0

/*
Each block contains a single size byte which is used to search
for open blocks in memory. A 0 means that the given block is free,
and subsequent blocks can be checked for enough available space.
*/

wVallocBackground::
    ds REGION_SIZE
wVallocShared::
    ds REGION_SIZE
wVallocObjects::
    ds REGION_SIZE
