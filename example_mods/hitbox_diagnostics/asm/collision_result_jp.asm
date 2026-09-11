.psp

.createfile "../bins/COLLISION_RESULT_JP.bin", 0x0891EF00
    lui     k0, 0x0891
    ori     k0, k0, 0xF000
    lw      k1, 0x00(k0)
    addiu   k1, k1, 1
    sw      k1, 0x00(k0)
    sw      s6, 0x04(k0)
    sw      s8, 0x08(k0)
    lw      k1, 0x4C(sp)
    sw      k1, 0x0C(k0)
    lw      k1, 0x44(sp)
    sw      k1, 0x10(k0)
    lw      k1, 0x48(sp)
    sw      k1, 0x14(k0)
    lw      k1, 0xA0(sp)
    sw      k1, 0x18(k0)
    lw      k1, 0xA4(sp)
    sw      k1, 0x1C(k0)
    lw      k1, 0xA8(sp)
    sw      k1, 0x20(k0)
    lw      k1, 0x80(sp)
    sw      k1, 0x24(k0)
    lw      k1, 0x84(sp)
    sw      k1, 0x28(k0)
    lw      k1, 0x88(sp)
    sw      k1, 0x2C(k0)
    lw      k1, 0x8C(sp)
    sw      k1, 0x30(k0)
    lw      k1, 0x90(sp)
    sw      k1, 0x34(k0)
    lw      k1, 0x94(sp)
    sw      k1, 0x38(k0)
    lw      k1, 0x98(sp)
    sw      k1, 0x3C(k0)
    lw      k1, 0x9C(sp)
    sw      k1, 0x40(k0)
    lw      ra, 0x3C(sp)
    j       0x088843C4
    nop
.close
