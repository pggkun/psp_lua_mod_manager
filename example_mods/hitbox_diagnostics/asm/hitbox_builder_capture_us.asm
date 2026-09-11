.psp

.createfile "../bins/HITBOX_BUILDER_CAPTURE_US.bin", 0x08921C00
    lui     k0, 0x0892
    ori     k0, k0, 0x1660
    lw      k1, 0x3C(k0)
    lw      k0, -0x0C(k0)
    bne     k1, k0, capture_return
    nop
    lui     k0, 0x0892
    ori     k0, k0, 0x1660
    lw      k1, 0x3C(k0)
    sw      k1, 0x48(k0)
    lw      k1, 0x40(k0)
    sw      k1, 0x4C(k0)
    sw      a2, 0x04(k0)
    lw      k1, 0x00(a2)
    sw      k1, 0x08(k0)
    lw      k1, 0x04(a2)
    sw      k1, 0x0C(k0)
    lw      k1, 0x08(a2)
    sw      k1, 0x10(k0)
    lw      k1, 0x0C(a2)
    sw      k1, 0x14(k0)
    lw      k1, 0x10(a2)
    sw      k1, 0x18(k0)
    lw      k1, 0x14(a2)
    sw      k1, 0x1C(k0)
    lw      k1, 0x18(a2)
    sw      k1, 0x20(k0)
    lw      k1, 0x1C(a2)
    sw      k1, 0x24(k0)
    lw      k1, 0x20(a2)
    sw      k1, 0x28(k0)
    lw      k1, 0x24(a2)
    sw      k1, 0x2C(k0)
    lw      k1, 0x28(a2)
    sw      k1, 0x30(k0)
    lw      k1, 0x2C(a2)
    sw      k1, 0x34(k0)
    lw      k1, 0x30(a2)
    sw      k1, 0x38(k0)
    lw      k1, 0x00(k0)
    addiu   k1, k1, 1
    sw      k1, 0x00(k0)
capture_return:
    jr      ra
    nop

.orga 0xC0
    lui     k0, 0x0892
    ori     k0, k0, 0x1660
    sw      a0, 0x3C(k0)
    sw      a1, 0x40(k0)
    sw      a2, 0x44(k0)
    addiu   sp, sp, -0x40
    nop
    nop
.close
