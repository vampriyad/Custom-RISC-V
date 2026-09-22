
.equ SIM_EXIT,    0x50000000
.equ DOT_A0,      0x40000000
.equ DOT_B0,      0x40000010
.equ DOT_RESULT,  0x40000020
.equ DOT_CMD,     0x40000024

.text
.org 0x00
    j _start
.org 0x04
    j _irq

_start:
    li s0, SIM_EXIT
    li s1, 2

    addi s1, s1, 1
    la t0, va
    la t1, vb
    li t2, 4
    li s2, 0
sw_loop:
    lw t3, 0(t0)
    lw t4, 0(t1)
    mul t5, t3, t4
    add s2, s2, t5
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, sw_loop

    addi s1, s1, 1
    la t0, va
    la t1, vb
    lw t2, 0(t0)
    lw t3, 0(t1)
    mul s3, t2, t3
    lw t2, 4(t0)
    lw t3, 4(t1)
    mul t4, t2, t3
    add s3, s3, t4
    lw t2, 8(t0)
    lw t3, 8(t1)
    mul t4, t2, t3
    add s3, s3, t4
    lw t2, 12(t0)
    lw t3, 12(t1)
    mul t4, t2, t3
    add s3, s3, t4

    addi s1, s1, 1
    bne s2, s3, fail

    addi s1, s1, 1
    li t0, 1
    bne s2, t0, fail

    addi s1, s1, 1
    la t0, va
    la t1, vb
    li t2, DOT_A0
    lw t3, 0(t0)
    sw t3, 0(t2)
    lw t3, 4(t0)
    sw t3, 4(t2)
    lw t3, 8(t0)
    sw t3, 8(t2)
    lw t3, 12(t0)
    sw t3, 12(t2)
    li t2, DOT_B0
    lw t3, 0(t1)
    sw t3, 0(t2)
    lw t3, 4(t1)
    sw t3, 4(t2)
    lw t3, 8(t1)
    sw t3, 8(t2)
    lw t3, 12(t1)
    sw t3, 12(t2)

    addi s1, s1, 1
    cdot s4
    bne s4, s2, fail

    addi s1, s1, 1
    li t0, DOT_CMD
    sw zero, 0(t0)
    li t0, DOT_RESULT
    lw s5, 0(t0)
    bne s5, s2, fail

    addi s1, s1, 1
    cdot s4
    li t0, DOT_RESULT
    lw s5, 0(t0)
    bne s5, s4, fail

    li t3, 1
    sw t3, 0(s0)
halt:
    j halt

fail:
    sw s1, 0(s0)
    j halt

_irq:
    j halt

.data
.align 4
va: .word 3, -2, 7, 10
vb: .word 4, 5, -3, 2
