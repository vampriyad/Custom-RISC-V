
.equ SIM_EXIT,    0x50000000
.equ TIMER_CNT,   0x30000000
.equ TIMER_CMP,   0x30000004
.equ TIMER_CTRL,  0x30000008
.equ TICKS,       200

.text
.org 0x00
    j _start
.org 0x04
    j _irq

_start:
    li s0, SIM_EXIT
    li s1, 2
    la gp, scratch
    sw zero, 8(gp)

    addi s1, s1, 1
    li t0, TIMER_CNT
    lw t1, 0(t0)
    addi t1, t1, 2
spin:
    lw t2, 0(t0)
    bltu t2, t1, spin

    addi s1, s1, 1
    li t0, TIMER_CNT
    lw t1, 0(t0)
    addi t1, t1, TICKS
    li t0, TIMER_CMP
    sw t1, 0(t0)
    li t0, TIMER_CTRL
    li t1, 1
    sw t1, 0(t0)

    addi s1, s1, 1
wait_ticks:
    lw t1, 8(gp)
    li t2, 3
    blt t1, t2, wait_ticks

    addi s1, s1, 1
    lw t3, 8(gp)
    li t2, 4
wait_more:
    lw t1, 8(gp)
    blt t1, t2, wait_more

    li t0, TIMER_CTRL
    sw zero, 0(t0)
    lw t1, 8(gp)
    blt t1, t3, fail

    li t3, 1
    sw t3, 0(s0)
halt:
    j halt

fail:
    sw s1, 0(s0)
    j halt

_irq:
    sw t0, 0(gp)
    sw t1, 4(gp)

    li t0, TIMER_CNT
    lw t1, 0(t0)
    addi t1, t1, TICKS
    li t0, TIMER_CMP
    sw t1, 0(t0)

    li t0, TIMER_CTRL
    li t1, 3
    sw t1, 0(t0)

    lw t1, 8(gp)
    addi t1, t1, 1
    sw t1, 8(gp)

    lw t0, 0(gp)
    lw t1, 4(gp)
    mret

.data
.align 4
scratch: .space 16
