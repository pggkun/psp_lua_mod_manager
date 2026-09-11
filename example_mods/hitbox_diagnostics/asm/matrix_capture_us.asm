.psp

.createfile "../bins/MATRIX_CAPTURE_US.bin", 0x089216C0
    vmmov.q m700, m100
    lui     k0, 0x0892
    ori     k0, k0, 0x1660
    sv.q    c700, 0x00(k0)
    sv.q    c710, 0x10(k0)
    sv.q    c720, 0x20(k0)
    sv.q    c730, 0x30(k0)
    jal     0x088266CC
    move    a1, s4
    j       0x08841DBC
    nop
.close
