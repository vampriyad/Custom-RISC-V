
.equ SIM_EXIT,    0x50000000
.equ DOT_A0,      0x40000000
.equ DOT_B0,      0x40000010

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
    add t1, t0, t0
    add t2, t1, t0
    add t3, t2, t1
    li t4, 25
    bne t3, t4, fail

    addi s1, s1, 1
    la t0, dwords
    li t1, 0x1111
    sw t1, 0(t0)
    lw t2, 0(t0)
    add t3, t2, t2
    li t4, 0x2222
    bne t3, t4, fail

    addi s1, s1, 1
    lw t4, 0(t0)
    sw t4, 8(t0)
    lw t5, 8(t0)
    bne t5, t4, fail

    addi s1, s1, 1
    li t6, 7
    addi t6, t6, 3
    li s2, 10
    bne t6, s2, fail

    addi s1, s1, 1
    li s3, 0
    li s4, 1
    beq s4, s4, hz5
    addi s3, s3, 100
hz5:
    addi s3, s3, 1
    li t4, 1
    bne s3, t4, fail

    addi s1, s1, 1
    li s3, 0
    beq s4, zero, hz6
    addi s3, s3, 5
hz6:
    li t4, 5
    bne s3, t4, fail

    addi s1, s1, 1
    jal ra, hz7fn
hz7:
    la t4, hz7
    bne t0, t4, fail
    j hz7done
hz7fn:
    mv t0, ra
    ret
hz7done:

    addi s1, s1, 1
    la t0, hz8fn
    jalr ra, t0, 0
hz8:
    la t4, hz8
    bne t1, t4, fail
    j hz8done
hz8fn:
    mv t1, ra
    ret
hz8done:

    addi s1, s1, 1
    li t0, 0
    li t1, 10
hz9:
    add t0, t0, t1
    addi t1, t1, -1
    bnez t1, hz9
    li t4, 55
    bne t0, t4, fail

    addi s1, s1, 1
    li t0, DOT_A0
    li t2, 2
    sw t2, 0(t0)
    sw t2, 4(t0)
    sw t2, 8(t0)
    sw t2, 12(t0)
    li t1, DOT_B0
    li t3, 3
    sw t3, 0(t1)
    sw t3, 4(t1)
    sw t3, 8(t1)
    sw t3, 12(t1)
    cdot s5
    add s6, s5, s5
    li t4, 48
    bne s6, t4, fail

    addi s1, s1, 1
    la t0, dwords
    sw s5, 16(t0)
    lw s7, 16(t0)
    bne s7, s5, fail

    addi s1, s1, 1
    li t1, 0x77
    add zero, t1, t1
    add t2, zero, t0
    bne t2, t0, fail

    addi s1, s1, 1
    la t0, dwords
    lw t1, 0(t0)
    li t2, 0x1111
    blt t1, t2, fail
    bgt t1, t2, fail
    jal ra, hz13fn
hz13:
    j done
hz13fn:
    addi sp, zero, 0
    ret

done:
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
dwords: .space 32
