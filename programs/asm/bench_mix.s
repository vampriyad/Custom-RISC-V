
.equ SIM_EXIT,    0x50000000
.equ UART_DATA,   0x20000000
.equ UART_STATUS, 0x20000004
.equ TIMER_CNT,   0x30000000

.text
.org 0x00
    j _start
.org 0x04
    j _irq

_start:
    li s0, SIM_EXIT
    la sp, stack_top

    la t0, mat
    li t1, 512
    li s7, 42
    jal ra, fill

    li t5, TIMER_CNT
    lw s3, 0(t5)
    la t0, mat
    li t2, 32
    li s6, 0
mac_row:
    la t1, vec
    li t3, 16
    li t4, 0
mac_col:
    lw t6, 0(t0)
    lw a2, 0(t1)
    mul a2, t6, a2
    add t4, t4, a2
    addi t0, t0, 4
    addi t1, t1, 4
    addi t3, t3, -1
    bnez t3, mac_col
    add s6, s6, t4
    addi t2, t2, -1
    bnez t2, mac_row
    lw a1, 0(t5)
    sub a1, a1, s3
    la a0, nm_mac
    mv s5, s6
    jal ra, print_bench

    li t5, TIMER_CNT
    lw s3, 0(t5)
    la t0, mat
    li t2, 512
    li s6, 0
sum_lp:
    lw t6, 0(t0)
    add s6, s6, t6
    addi t0, t0, 4
    addi t2, t2, -1
    bnez t2, sum_lp
    lw a1, 0(t5)
    sub a1, a1, s3
    la a0, nm_sum
    jal ra, print_bench

    li t5, TIMER_CNT
    lw s3, 0(t5)
    la t0, mat
    la t1, dst
    li t2, 256
copy_lp:
    lw t6, 0(t0)
    sw t6, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, copy_lp
    lw a1, 0(t5)
    sub a1, a1, s3
    la a0, nm_copy
    jal ra, print_bench

    la t0, mat
    la t1, dst
    li t2, 256
    mv s6, s5
cpy_chk:
    lw t3, 0(t0)
    lw t4, 0(t1)
    bne t3, t4, fail
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, cpy_chk

    li t5, TIMER_CNT
    lw s3, 0(t5)
    li t2, 31
srt_outer:
    la t0, dst
    li t3, 31
    mv t4, t2
srt_inner:
    lw t6, 0(t0)
    lw a2, 4(t0)
    ble t6, a2, srt_noswap
    sw a2, 0(t0)
    sw t6, 4(t0)
srt_noswap:
    addi t0, t0, 4
    addi t3, t3, -1
    addi t4, t4, -1
    bnez t4, srt_inner
    addi t2, t2, -1
    bnez t2, srt_outer
    lw a1, 0(t5)
    sub a1, a1, s3
    la a0, nm_sort
    jal ra, print_bench

    la t0, dst
    li t2, 31
srt_chk:
    lw t3, 0(t0)
    lw t4, 4(t0)
    bgt t3, t4, fail
    addi t0, t0, 4
    addi t2, t2, -1
    bnez t2, srt_chk

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
    srai t3, s7, 18
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
nm_mac:  .asciz "BENCH mac512 "
nm_sum:  .asciz "BENCH sum512 "
nm_copy: .asciz "BENCH copy256 "
nm_sort: .asciz "BENCH sort32 "
.align 4
mat:  .space 2048
vec:  .space 64
dst:  .space 1024
stack: .space 64
stack_top:
