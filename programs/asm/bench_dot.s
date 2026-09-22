
.equ SIM_EXIT,    0x50000000
.equ UART_DATA,   0x20000000
.equ UART_STATUS, 0x20000004
.equ TIMER_CNT,   0x30000000
.equ DOT_A0,      0x40000000
.equ DOT_B0,      0x40000010
.equ NDOTS,       64

.text
.org 0x00
    j _start
.org 0x04
    j _irq

_start:
    li s0, SIM_EXIT
    la sp, stack_top

    la t0, arrA
    li t1, 256
    li s7, 12345
    jal ra, fill
    la t0, arrB
    li t1, 256
    jal ra, fill

    li t5, TIMER_CNT
    lw s3, 0(t5)
    la t0, arrA
    la t1, arrB
    li t2, NDOTS
    li s6, 0
swr_dot:
    li t3, 4
    li t4, 0
swr_lane:
    lw t6, 0(t0)
    lw a2, 0(t1)
    mul a2, t6, a2
    add t4, t4, a2
    addi t0, t0, 4
    addi t1, t1, 4
    addi t3, t3, -1
    bnez t3, swr_lane
    add s6, s6, t4
    addi t2, t2, -1
    bnez t2, swr_dot
    lw a1, 0(t5)
    sub a1, a1, s3
    la a0, nm_swrolled
    mv s5, s6
    jal ra, print_bench

    li t5, TIMER_CNT
    lw s3, 0(t5)
    la t0, arrA
    la t1, arrB
    li t2, NDOTS
    li s6, 0
swu_dot:
    lw t6, 0(t0)
    lw a2, 0(t1)
    mul a2, t6, a2
    lw t6, 4(t0)
    lw a3, 4(t1)
    mul a3, t6, a3
    add a2, a2, a3
    lw t6, 8(t0)
    lw a3, 8(t1)
    mul a3, t6, a3
    add a2, a2, a3
    lw t6, 12(t0)
    lw a3, 12(t1)
    mul a3, t6, a3
    add a2, a2, a3
    add s6, s6, a2
    addi t0, t0, 16
    addi t1, t1, 16
    addi t2, t2, -1
    bnez t2, swu_dot
    lw a1, 0(t5)
    sub a1, a1, s3
    la a0, nm_swunrolled
    jal ra, print_bench
    bne s6, s5, fail

    li t5, TIMER_CNT
    lw s3, 0(t5)
    la t0, arrA
    la t1, arrB
    li t2, NDOTS
    li s6, 0
    li a4, DOT_A0
    li a5, DOT_B0
hw_dot:
    lw t6, 0(t0)
    sw t6, 0(a4)
    lw t6, 4(t0)
    sw t6, 4(a4)
    lw t6, 8(t0)
    sw t6, 8(a4)
    lw t6, 12(t0)
    sw t6, 12(a4)
    lw a2, 0(t1)
    sw a2, 0(a5)
    lw a2, 4(t1)
    sw a2, 4(a5)
    lw a2, 8(t1)
    sw a2, 8(a5)
    lw a2, 12(t1)
    sw a2, 12(a5)
    cdot a2
    add s6, s6, a2
    addi t0, t0, 16
    addi t1, t1, 16
    addi t2, t2, -1
    bnez t2, hw_dot
    lw a1, 0(t5)
    sub a1, a1, s3
    la a0, nm_hwstream
    jal ra, print_bench
    bne s6, s5, fail

    li t5, TIMER_CNT
    lw s3, 0(t5)
    li t2, NDOTS
    li s6, 0
hwc_dot:
    cdot a2
    add s6, s6, a2
    addi t2, t2, -1
    bnez t2, hwc_dot
    lw a1, 0(t5)
    sub a1, a1, s3
    la a0, nm_hwcached
    jal ra, print_bench

    li t3, 1
    sw t3, 0(s0)
halt:
    j halt

fail:
    li t3, 99
    sw t3, 0(s0)
    j halt

fill:
    li t2, 1103515245
fill_lp:
    mul s7, s7, t2
    li t4, 12345
    add s7, s7, t4
    srai t3, s7, 17
    sw t3, 0(t0)
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, fill_lp
    ret

putc:
    li t0, UART_STATUS
putc_poll:
    lw t1, 0(t0)
    andi t1, t1, 1
    bnez t1, putc_poll
    li t0, UART_DATA
    sw a0, 0(t0)
    ret

print_str:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    mv s2, a0
ps_word:
    lw s3, 0(s2)
    beqz s3, ps_done
    li t2, 4
ps_byte:
    andi a0, s3, 0xFF
    beqz a0, ps_done
    jal ra, putc
    srli s3, s3, 8
    addi t2, t2, -1
    bnez t2, ps_byte
    addi s2, s2, 4
    j ps_word
ps_done:
    lw ra, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 12
    ret

print_hex:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    mv s2, a0
    li a0, 0x30
    jal ra, putc
    li a0, 0x78
    jal ra, putc
    li s3, 28
ph_loop:
    srl t0, s2, s3
    andi t0, t0, 0xF
    li t1, 10
    blt t0, t1, ph_digit
    addi a0, t0, 0x57
    j ph_emit
ph_digit:
    addi a0, t0, 0x30
ph_emit:
    jal ra, putc
    addi s3, s3, -4
    bgez s3, ph_loop
    lw ra, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 12
    ret

print_bench:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    mv s2, a1
    jal ra, print_str
    mv a0, s2
    jal ra, print_hex
    li a0, 0x0A
    jal ra, putc
    lw ra, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 12
    ret

_irq:
    j halt

.data
.align 4
nm_swrolled:   .asciz "BENCH sw_rolled "
nm_swunrolled: .asciz "BENCH sw_unrolled "
nm_hwstream:   .asciz "BENCH hw_stream "
nm_hwcached:   .asciz "BENCH hw_cached "
.align 4
arrA: .space 1024
arrB: .space 1024
stack: .space 64
stack_top:
