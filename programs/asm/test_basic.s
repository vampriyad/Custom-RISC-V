
.equ SIM_EXIT, 0x50000000

.text
.org 0x00
    j _start
.org 0x04
    j _irq

_start:
    li s0, SIM_EXIT
    li s1, 2

    addi s1, s1, 1
    li t0, 5
    li t1, 7
    add t2, t0, t1
    li t3, 12
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, 10
    li t1, 3
    sub t2, t0, t1
    li t3, 7
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, -5
    li t1, 5
    add t2, t0, t1
    bne t2, zero, fail

    addi s1, s1, 1
    li t0, 2000
    li t1, -2500
    add t2, t0, t1
    li t3, -500
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, 0x0F0F
    li t1, 0x00FF
    and t2, t0, t1
    li t3, 0x000F
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, 0x0F0F
    li t1, 0x00FF
    or t2, t0, t1
    li t3, 0x0FFF
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, 0x0F0F
    li t1, 0x00FF
    xor t2, t0, t1
    li t3, 0x0FF0
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, 1
    slli t2, t0, 31
    li t3, 0x80000000
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, 0x80000000
    srli t2, t0, 31
    li t3, 1
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, 0x80000000
    srai t2, t0, 31
    li t3, -1
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, 0x40
    li t1, 3
    sll t2, t0, t1
    li t3, 0x200
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, -16
    srai t2, t0, 2
    li t3, -4
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, -1
    li t1, 1
    slt t2, t0, t1
    li t3, 1
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, -1
    li t1, 1
    sltu t2, t0, t1
    bne t2, zero, fail

    addi s1, s1, 1
    li t0, 7
    li t1, 7
    slt t2, t0, t1
    bne t2, zero, fail

    addi s1, s1, 1
    li t0, 7
    li t1, 6
    mul t2, t0, t1
    li t3, 42
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, -3
    li t1, 5
    mul t2, t0, t1
    li t3, -15
    bne t2, t3, fail

    addi s1, s1, 1
    lui t0, 0x12345
    li t3, 0x12345000
    bne t0, t3, fail

    addi s1, s1, 1
auipc_lab:
    auipc t0, 0
    la t3, auipc_lab
    bne t0, t3, fail

    addi s1, s1, 1
    li t0, 0x55AA
    add zero, t0, t0
    add t2, zero, t0
    bne t2, t0, fail

    addi s1, s1, 1
    li t0, 4
    li t1, 4
    bne t0, t1, fail
    beq t0, t1, br1_ok
    j fail
br1_ok:
    addi s1, s1, 1
    li t0, 3
    li t1, 9
    blt t0, t1, br2_ok
    j fail
br2_ok:
    addi s1, s1, 1
    bge t1, t0, br3_ok
    j fail
br3_ok:
    addi s1, s1, 1
    bltu t0, t1, br4_ok
    j fail
br4_ok:
    addi s1, s1, 1
    bgeu t1, t0, br5_ok
    j fail
br5_ok:
    addi s1, s1, 1
    li t0, -1
    li t1, 1
    blt t0, t1, br6_ok
    j fail
br6_ok:
    addi s1, s1, 1
    bge t1, t0, br7_ok
    j fail
br7_ok:
    addi s1, s1, 1
    bltu t1, t0, br8_ok
    j fail
br8_ok:

    addi s1, s1, 1
    jal ra, sub_link
after_link:
    la t3, after_link
    bne t0, t3, fail

    addi s1, s1, 1
    la t0, sub_indirect
    jalr ra, t0, 0
after_indirect:
    la t3, after_indirect
    bne t1, t3, fail

    li t3, 1
    sw t3, 0(s0)
halt:
    j halt

fail:
    sw s1, 0(s0)
    j halt

sub_link:
    mv t0, ra
    ret

sub_indirect:
    mv t1, ra
    ret

_irq:
    j halt
