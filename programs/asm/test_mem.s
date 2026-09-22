
.equ SIM_EXIT, 0x50000000
.equ DATA,     0x10000000

.text
.org 0x00
    j _start
.org 0x04
    j _irq

_start:
    li s0, SIM_EXIT
    li s1, 2

    addi s1, s1, 1
    li t0, DATA
    li t1, 0x12345678
    sw t1, 0(t0)
    lw t2, 0(t0)
    bne t2, t1, fail

    addi s1, s1, 1
    li t1, 0x11111111
    sw t1, 4(t0)
    li t1, 0x22222222
    sw t1, 8(t0)
    li t1, 0x33333333
    sw t1, 12(t0)
    lw t2, 4(t0)
    li t3, 0x11111111
    bne t2, t3, fail
    lw t2, 8(t0)
    li t3, 0x22222222
    bne t2, t3, fail
    lw t2, 12(t0)
    li t3, 0x33333333
    bne t2, t3, fail

    addi s1, s1, 1
    li t1, 0xCAFEBABE
    sw t1, 4(t0)
    lw t2, 4(t0)
    bne t2, t1, fail
    lw t2, 8(t0)
    li t3, 0x22222222
    bne t2, t3, fail

    addi s1, s1, 1
    li t0, DATA
    addi t0, t0, 64
    li t1, 0x0BADF00D
    sw t1, -64(t0)
    li t2, DATA
    lw t3, 0(t2)
    bne t3, t1, fail

    addi s1, s1, 1
    li t0, DATA
    li t1, 0
    li t2, 16
fill:
    sw t1, 128(t0)
    addi t0, t0, 4
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, fill

    li t0, DATA
    li t1, 0
    li t2, 16
check:
    lw t3, 128(t0)
    bne t3, t1, fail
    addi t0, t0, 4
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, check

    addi s1, s1, 1
    li t0, 0x10000FFC
    li t1, 0x7FFFFFFF
    sw t1, 0(t0)
    lw t2, 0(t0)
    bne t2, t1, fail

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
pad: .space 64
