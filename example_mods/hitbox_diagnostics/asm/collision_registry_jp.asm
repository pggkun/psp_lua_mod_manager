.psp

.createfile "../bins/COLLISION_REGISTRY_JP.bin", 0x0891E9C0
    lui     k0, 0x0891
    ori     k0, k0, 0xE940
    sw      v0, 0x1C(k0)
    lw      s3, 0x38(v0)
    j       0x08883E3C
    nop
.close
