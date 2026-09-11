.psp

NODE_TABLE  equ 0x0891EA40
SCREEN_DATA equ 0x0891EC00
PROJECTOR   equ 0x0891EF00

.createfile "../bins/MATRIX_CAPTURE_JP.bin", 0x0891E9C0
    vmmov.q m700, m100
    jal     0x08826F24
    move    a1, s4
    j       0x08841DD8
    nop

.org PROJECTOR
    addiu sp, sp, -0xC0
    sw ra, 0x00(sp)
    sw a0, 0x04(sp)
    sw t0, 0x08(sp)
    sw t1, 0x0C(sp)
    sw t2, 0x10(sp)
    sw t3, 0x14(sp)
    sw t4, 0x18(sp)
    sw t5, 0x1C(sp)
    sw t6, 0xA0(sp)
    sw t7, 0xA4(sp)
    sv.q c500, 0x20(sp)
    sv.q c510, 0x30(sp)
    sv.q c520, 0x40(sp)
    sv.q c530, 0x50(sp)
    sv.q c600, 0x60(sp)
    sv.q c610, 0x70(sp)
    sv.q c620, 0x80(sp)
    sv.q c630, 0x90(sp)
    sw zero, 0xA8(sp)
    move t6, zero
    li t0, NODE_TABLE
    lw t4, 0x188(t0)
    beqz t4, @@done
    addiu t4, t4, -1
    sw t4, 0x188(t0)
    lw t1, 0(t0)
    sltiu t4, t1, 49
    bnez t4, @@count_ok
    nop
    li t1, 48
@@count_ok:
    addiu t0, t0, 4
    li t2, SCREEN_DATA
    move a1, zero
@@loop:
    beqz t1, @@done
    nop
    lw t3, 0(t0)
    beqz t3, @@invalid
    nop
    vzero.q c500
    lv.s s500, 0x100(t3)
    lv.s s501, 0x104(t3)
    lv.s s502, 0x108(t3)
    vone.s s503
    vdot.q s600, r700, c500
    vdot.q s610, r701, c500
    vdot.q s620, r702, c500
    vdot.q s630, r703, c500
    vzero.q c500
    vzero.q c510
    vzero.q c520
    vzero.q c530
    li t4, 0x3F9B8C00
    mtv t4, s500
    li t4, 0x40093EFF
    mtv t4, s511
    li t4, 0xBF800000
    mtv t4, s522
    mtv t4, s532
    li t4, 0xC2700000
    mtv t4, s523
    vtfm4.q r601, m500, r600
    vdiv.s s602, s601, s631
    vdiv.s s612, s611, s631
    vone.s s630
    li t4, 0x3F000000
    mtv t4, s620
    li t4, 0x43F00000
    mtv t4, s600
    li t4, 0x43880000
    mtv t4, s610
    vadd.s s602, s602, s630
    vmul.s s602, s602, s620
    vmul.s s602, s602, s600
    vsub.s s612, s630, s612
    vmul.s s612, s612, s620
    vmul.s s612, s612, s610
    vf2in.s s602, s602, 0
    vf2in.s s612, s612, 0
    mfv t4, s602
    mfv t5, s612
    sw t4, 0(t2)
    sw t5, 4(t2)
    bltz t4, @@offscreen
    nop
    bltz t5, @@offscreen
    nop
    sltiu t7, t4, 480
    beqz t7, @@offscreen
    nop
    sltiu t7, t5, 272
    beqz t7, @@offscreen
    nop
    li t7, 1
    sw t7, 8(t2)
    lw t7, 0xA8(sp)
    bnez t7, @@check_spread
    nop
    sw t4, 0xAC(sp)
    sw t5, 0xB0(sp)
    li t7, 1
    sw t7, 0xA8(sp)
    b @@visible_count
    nop
@@check_spread:
    lw t3, 0xAC(sp)
    subu t3, t4, t3
    bgez t3, @@dx_positive
    nop
    negu t3, t3
@@dx_positive:
    sltiu t7, t3, 3
    beqz t7, @@spread_found
    nop
    lw t3, 0xB0(sp)
    subu t3, t5, t3
    bgez t3, @@dy_positive
    nop
    negu t3, t3
@@dy_positive:
    sltiu t7, t3, 3
    bnez t7, @@visible_count
    nop
@@spread_found:
    li t7, 2
    sw t7, 0xA8(sp)
@@visible_count:
    addiu t6, t6, 1
    b @@next
    nop
@@offscreen:
    sw zero, 8(t2)
    bnez t6, @@next
    nop
    sltiu t7, a1, 7
    bnez t7, @@next
    nop
    li t1, 1
    b @@next
    nop
@@invalid:
    sw zero, 8(t2)
@@next:
    addiu a1, a1, 1
    sltiu t7, a1, 8
    bnez t7, @@advance
    nop
    lw t7, 0xA8(sp)
    sltiu t7, t7, 2
    beqz t7, @@advance
    nop
    li t1, 1
@@advance:
    addiu t0, t0, 8
    addiu t2, t2, 12
    addiu t1, t1, -1
    b @@loop
    nop
@@done:
    lw t7, 0xA8(sp)
    sltiu t7, t7, 2
    bnez t7, @@restore
    nop
    li t0, NODE_TABLE
    sw zero, 0x188(t0)
    li t7, 1
    sw t7, 0x18C(t0)
@@restore:
    lv.q c500, 0x20(sp)
    lv.q c510, 0x30(sp)
    lv.q c520, 0x40(sp)
    lv.q c530, 0x50(sp)
    lv.q c600, 0x60(sp)
    lv.q c610, 0x70(sp)
    lv.q c620, 0x80(sp)
    lv.q c630, 0x90(sp)
    lw ra, 0x00(sp)
    lw a0, 0x04(sp)
    lw t0, 0x08(sp)
    lw t1, 0x0C(sp)
    lw t2, 0x10(sp)
    lw t3, 0x14(sp)
    lw t4, 0x18(sp)
    lw t5, 0x1C(sp)
    lw t6, 0xA0(sp)
    lw t7, 0xA4(sp)
    jr ra
    addiu sp, sp, 0xC0
.close
