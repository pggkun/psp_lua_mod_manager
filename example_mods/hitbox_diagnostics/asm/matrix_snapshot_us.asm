.psp

.createfile "../bins/MATRIX_SNAPSHOT_US.bin", 0x08921700
    lui     k0, 0x0892
    ori     k0, k0, 0x1660
    sv.q    c700, 0x00(k0)
    sv.q    c710, 0x10(k0)
    sv.q    c720, 0x20(k0)
    sv.q    c730, 0x30(k0)
    jr      ra
    nop
.close
