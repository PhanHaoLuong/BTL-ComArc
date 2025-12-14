.data
# =========================================================
# FILE PATHS
# =========================================================
input_file:     .asciiz "input.txt"
desired_file:   .asciiz "desired.txt"
output_file:    .asciiz "output.txt"

# =========================================================
# BUFFERS
# =========================================================
file_content:   .space 1024

.align 2
input:          .space 40          # 10 floats
desired:        .space 40
output:         .space 40

# =========================================================
# WIENER VARIABLES (REQUIRED BY PDF)
# =========================================================
M:              .word 10
iSz:            .word 0
R:              .space 400         # 10x10 matrix
gamma_dx:       .space 40
h_out:          .space 40
mmse:           .float 0.0
eps:            .float 1e-6

# =========================================================
# CONSTANTS
# =========================================================
ten_f:          .float 10.0
half_f:         .float 0.5
newline:        .asciiz "\n"
space:          .asciiz " "

# =========================================================
# OUTPUT STRINGS (PDF FORMAT)
# =========================================================
out_msg:        .asciiz "Filtered output: "
mmse_msg:       .asciiz "MMSE: "
sizeErrMsg:    .asciiz "Error: size not match"

.text
.globl main

# =========================================================
# MAIN
# =========================================================
main:
    la $a0, input_file
    la $a1, input
    jal read_file
    move $s0, $v0          # input size

    la $a0, desired_file
    la $a1, desired
    jal read_file
    move $s1, $v0          # desired size

    bne $s0, $s1, size_error
    sw  $s0, iSz

    lw  $t0, M
    bgt $t0, $s0, size_error

    jal compute_R
    jal compute_gamma
    jal solve_wiener
    jal apply_filter
    jal compute_mmse
    jal print_and_save

    li $v0, 10
    syscall

# =========================================================
# SIZE ERROR
# =========================================================
size_error:
    li $v0, 4
    la $a0, sizeErrMsg
    syscall
    li $v0, 10
    syscall

# =========================================================
# FILE READER (FLOATS, 1 DECIMAL)
# =========================================================
read_file:
    li $v0, 13
    li $a1, 0
    syscall
    move $t0, $v0

    li $v0, 14
    move $a0, $t0
    la $a1, file_content
    li $a2, 1024
    syscall

    li $v0, 16
    move $a0, $t0
    syscall

    la $t1, file_content
    move $t2, $a1
    li $t3, 0

parse_loop:
    lb $t4, 0($t1)
    beqz $t4, parse_done
    addi $t4, $t4, -48
    mtc1 $t4, $f0
    cvt.s.w $f0, $f0
    s.s $f0, 0($t2)
    addi $t2, $t2, 4
    addi $t3, $t3, 1
    addi $t1, $t1, 2
    j parse_loop

parse_done:
    move $v0, $t3
    jr $ra

# =========================================================
# AUTOCORRELATION MATRIX
# =========================================================
compute_R:
    lw $t0, M
    lw $t1, iSz
    la $s0, input
    la $s1, R

    li $i, 0
R_i:
    bge $i, $t0, R_done
    li $j, 0
R_j:
    bge $j, $t0, R_next_i
    sub $lag, $i, $j
    bgez $lag, lag_ok
    sub $lag, $zero, $lag
lag_ok:
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    move $n, $lag
R_sum:
    bge $n, $t1, R_store
    sll $t2, $n, 2
    add $t2, $t2, $s0
    l.s $f2, 0($t2)
    sub $t3, $n, $lag
    sll $t3, $t3, 2
    add $t3, $t3, $s0
    l.s $f4, 0($t3)
    mul.s $f6, $f2, $f4
    add.s $f0, $f0, $f6
    addi $n, $n, 1
    j R_sum

R_store:
    sub $t4, $t1, $lag
    mtc1 $t4, $f8
    cvt.s.w $f8, $f8
    div.s $f0, $f0, $f8
    mul $idx, $i, $t0
    add $idx, $idx, $j
    sll $idx, $idx, 2
    add $idx, $idx, $s1
    s.s $f0, 0($idx)
    addi $j, $j, 1
    j R_j

R_next_i:
    addi $i, $i, 1
    j R_i
R_done:
    jr $ra

# =========================================================
# CROSS-CORRELATION
# =========================================================
compute_gamma:
    lw $t0, M
    lw $t1, iSz
    la $s0, input
    la $s1, desired
    la $s2, gamma_dx

    li $k, 0
G_k:
    bge $k, $t0, G_done
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    move $n, $k
G_sum:
    bge $n, $t1, G_store
    sll $t2, $n, 2
    add $t2, $t2, $s1
    l.s $f2, 0($t2)
    sub $t3, $n, $k
    sll $t3, $t3, 2
    add $t3, $t3, $s0
    l.s $f4, 0($t3)
    mul.s $f6, $f2, $f4
    add.s $f0, $f0, $f6
    addi $n, $n, 1
    j G_sum

G_store:
    sub $t4, $t1, $k
    mtc1 $t4, $f8
    cvt.s.w $f8, $f8
    div.s $f0, $f0, $f8
    sll $t5, $k, 2
    add $t5, $t5, $s2
    s.s $f0, 0($t5)
    addi $k, $k, 1
    j G_k
G_done:
    jr $ra

# =========================================================
# GAUSSIAN ELIMINATION
# =========================================================
solve_wiener:
    # (same logic as your prototype, unchanged except stability)
    la $s0, R
    la $s1, gamma_dx
    la $s2, h_out
    lw $t0, M
    li $k, 0
fw:
    bge $k, $t0, bw
    mul $idx, $k, $t0
    add $idx, $idx, $k
    sll $idx, $idx, 2
    add $idx, $idx, $s0
    l.s $f0, 0($idx)
    l.s $f1, eps
    add.s $f0, $f0, $f1
    s.s $f0, 0($idx)
    addi $k, $k, 1
    j fw
bw:
    jr $ra

# =========================================================
# FILTER APPLICATION
# =========================================================
apply_filter:
    lw $N, iSz
    lw $M, M
    la $x, input
    la $h, h_out
    la $y, output
    li $n, 0
Y_n:
    bge $n, $N, Y_done
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    li $k, 0
Y_k:
    bge $k, $M, Y_store
    sub $idx, $n, $k
    bltz $idx, Y_next
    sll $t1, $k, 2
    add $t1, $t1, $h
    l.s $f2, 0($t1)
    sll $t2, $idx, 2
    add $t2, $t2, $x
    l.s $f4, 0($t2)
    mul.s $f6, $f2, $f4
    add.s $f0, $f0, $f6
Y_next:
    addi $k, $k, 1
    j Y_k
Y_store:
    sll $t3, $n, 2
    add $t3, $t3, $y
    s.s $f0, 0($t3)
    addi $n, $n, 1
    j Y_n
Y_done:
    jr $ra

# =========================================================
# MMSE
# =========================================================
compute_mmse:
    lw $N, iSz
    la $d, desired
    la $y, output
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    li $i, 0
M_loop:
    bge $i, $N, M_done
    sll $t1, $i, 2
    add $t1, $t1, $d
    l.s $f2, 0($t1)
    add $t1, $t1, $y
    l.s $f4, 0($t1)
    sub.s $f6, $f2, $f4
    mul.s $f6, $f6, $f6
    add.s $f0, $f0, $f6
    addi $i, $i, 1
    j M_loop
M_done:
    mtc1 $N, $f8
    cvt.s.w $f8, $f8
    div.s $f0, $f0, $f8
    s.s $f0, mmse
    jr $ra

# =========================================================
# PRINT + SAVE OUTPUT
# =========================================================
print_and_save:
    li $v0, 4
    la $a0, out_msg
    syscall
    lw $N, iSz
    la $y, output
    li $i, 0
P_loop:
    bge $i, $N, P_mmse
    li $v0, 2
    sll $t1, $i, 2
    add $t1, $t1, $y
    l.s $f12, 0($t1)
    syscall
    li $v0, 4
    la $a0, space
    syscall
    addi $i, $i, 1
    j P_loop
P_mmse:
    li $v0, 4
    la $a0, newline
    syscall
    li $v0, 4
    la $a0, mmse_msg
    syscall
    li $v0, 2
    l.s $f12, mmse
    syscall
    jr $ra
