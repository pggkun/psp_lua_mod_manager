.psp

.createfile "../bins/HIT_CAPTURE_US.bin", 0x08921600
    lui     k0, 0x0892
    ori     k0, k0, 0x1640
    sw      t0, 0x00(k0)
    lw      k1, 0x04(k0)
    addiu   k1, k1, 1
    sw      k1, 0x04(k0)
    lw      k1, 0x30(t0)
    sw      k1, 0x08(k0)
    lw      k1, 0x34(t0)
    sw      k1, 0x0C(k0)
    lw      k1, 0x38(t0)
    sw      k1, 0x10(k0)
    sw      s5, 0x14(k0)
    sh      v0, 0x2E4(s5)
    j       0x09AC7AD8
    nop
.close
