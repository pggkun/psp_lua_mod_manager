.psp

.createfile "../bins/COLLISION_QUERY_JP.bin", 0x0891E9C0
    ; Hooked at 0x088838A8, after the function has allocated its stack.
    ; The hook delay slot executes the original "move s4, a1" at 0x088838AC.
    sw      k0, 0x00(sp)
    sw      k1, 0x04(sp)
    lui     k0, 0x0891
    ori     k0, k0, 0xE960
    lw      k1, 0x00(k0)
    addiu   k1, k1, 1
    sw      k1, 0x00(k0)
    sw      a0, 0x04(k0)
    sw      a1, 0x08(k0)
    sw      a2, 0x0C(k0)
    sw      a3, 0x10(k0)
    sw      t0, 0x14(k0)
    sw      t1, 0x18(k0)
    sw      t2, 0x1C(k0)
    sw      t3, 0x20(k0)
    sw      sp, 0x24(k0)
    sw      ra, 0x28(k0)
    lw      k1, 0x04(sp)
    lw      k0, 0x00(sp)
    move    s5, a0
    j       0x088838B0
    nop
.close
