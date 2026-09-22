
.equ SIM_EXIT,    0x50000000
.equ UART_DATA,   0x20000000
.equ UART_STATUS, 0x20000004

.text
.org 0x00
    j _start
.org 0x04
    j _irq

_start:
    li s0, SIM_EXIT
    la sp, stack_top

    la a0, msg
    jal ra, print_str

    li a0, 0xDEADBEEF
    jal ra, print_hex

    la a0, msg2
    jal ra, print_str

    li t3, 1
    sw t3, 0(s0)
halt:
    j halt

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
msg:  .asciz "Hello from my CPU!"
msg2: .asciz "\nDone.\n"
stack: .space 64
stack_top:
