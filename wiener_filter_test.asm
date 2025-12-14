.data
M:              .word 3
iSz:            .word 9
R:              .float 2.0, 1.5, 0.9, 1.5, 2.0, 1.5, 0.9, 1.5, 2.0
gamma_dx:       .float 1.8, 1.2, 0.7
h_out:          .float 0.0, 0.0, 0.0
eps:            .float 1e-6

# Input and desired signals
input:          .float 0.1, 0.6, 0.9, 0.4, 0.1, -0.6, -0.8, -0.4, 0.1
desired:        .float 0.0, 0.5, 1.0, 0.5, 0.0, -0.5, -1.0, -0.5, 0.0
output:         .float 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
mmse:           .float 0.0

h_msg:          .asciiz "Coefficients h are: "
output_msg:     .asciiz "\nOutput: "
mmse_msg:       .asciiz "\nMMSE: "
space:          .asciiz " "
newline:        .asciiz "\n"

.text
main:
    la $s0, R
    la $s1, gamma_dx
    la $s2, h_out
    lw $t0, M
    li $t1, 0

FwdLoop:
    bge $t1, $t0, BackSub
    mul $t2, $t1, $t0
    add $t3, $t2, $t1
    sll $t3, $t3, 2
    add $t3, $t3, $s0
    l.s $f0, 0($t3)
    la $t4, eps
    l.s $f2, 0($t4)
    add.s $f0, $f0, $f2
    s.s $f0, 0($t3)
    addi $t4, $t1, 1

InnerI:
    bge $t4, $t0, NextK
    mul $t5, $t4, $t0
    add $t6, $t5, $t1
    sll $t6, $t6, 2
    add $t6, $t6, $s0
    l.s $f4, 0($t6)
    mul $t7, $t1, $t0
    add $t8, $t7, $t1
    sll $t8, $t8, 2
    add $t8, $t8, $s0
    l.s $f6, 0($t8)
    div.s $f8, $f4, $f6
    move $t9, $t1

InnerJ:
    bge $t9, $t0, NextRow
    mul $tA, $t4, $t0
    add $tB, $tA, $t9
    sll $tB, $tB, 2
    add $tB, $tB, $s0
    l.s $f10, 0($tB)
    mul $tC, $t1, $t0
    add $tD, $tC, $t9
    sll $tD, $tD, 2
    add $tD, $tD, $s0
    l.s $f12, 0($tD)
    mul.s $f14, $f8, $f12
    sub.s $f10, $f10, $f14
    s.s $f10, 0($tB)
    addi $t9, $t9, 1
    j InnerJ

NextRow:
    sll $tE, $t4, 2
    add $tE, $tE, $s1
    l.s $f16, 0($tE)
    sll $tF, $t1, 2
    add $tF, $tF, $s1
    l.s $f18, 0($tF)
    mul.s $f20, $f8, $f18
    sub.s $f16, $f16, $f20
    s.s $f16, 0($tE)
    addi $t4, $t4, 1
    j InnerI

NextK:
    addi $t1, $t1, 1
    j FwdLoop

BackSub:
    addi $t1, $t0, -1

BackLoop:
    blt $t1, $zero, PrintH
    sll $t2, $t1, 2
    add $t2, $t2, $s1
    l.s $f0, 0($t2)
    addi $t3, $t1, 1

InnerSum:
    bge $t3, $t0, SolveH
    mul $t4, $t1, $t0
    add $t5, $t4, $t3
    sll $t5, $t5, 2
    add $t5, $t5, $s0
    l.s $f2, 0($t5)
    sll $t6, $t3, 2
    add $t6, $t6, $s2
    l.s $f4, 0($t6)
    mul.s $f6, $f2, $f4
    sub.s $f0, $f0, $f6
    addi $t3, $t3, 1
    j InnerSum

SolveH:
    mul $t7, $t1, $t0
    add $t8, $t7, $t1
    sll $t8, $t8, 2
    add $t8, $t8, $s0
    l.s $f8, 0($t8)
    div.s $f10, $f0, $f8
    sll $t9, $t1, 2
    add $t9, $t9, $s2
    s.s $f10, 0($t9)
    addi $t1, $t1, -1
    j BackLoop

PrintH:
    li $v0, 4
    la $a0, h_msg
    syscall
    lw $t0, M
    li $t1, 0

PrintHLoop:
    bge $t1, $t0, ApplyFilter
    li $v0, 2
    sll $t2, $t1, 2
    add $t2, $t2, $s2
    l.s $f12, 0($t2)
    syscall
    li $v0, 4
    la $a0, space
    syscall
    addi $t1, $t1, 1
    j PrintHLoop

ApplyFilter:
    la $s3, input
    la $s4, output
    lw $s5, iSz
    lw $s6, M
    li $t0, 0

OuterLoop:
    bge $t0, $s5, PrintOutput
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    li $t1, 0

InnerLoop:
    bge $t1, $s6, StoreOutput
    sub $t2, $t0, $t1
    bltz $t2, NextK_Filter
    sll $t3, $t1, 2
    add $t3, $t3, $s2
    l.s $f2, 0($t3)
    sll $t4, $t2, 2
    add $t4, $t4, $s3
    l.s $f4, 0($t4)
    mul.s $f6, $f2, $f4
    add.s $f0, $f0, $f6

NextK_Filter:
    addi $t1, $t1, 1
    j InnerLoop

StoreOutput:
    sll $t5, $t0, 2
    add $t5, $t5, $s4
    s.s $f0, 0($t5)
    addi $t0, $t0, 1
    j OuterLoop

PrintOutput:
    li $v0, 4
    la $a0, output_msg
    syscall
    li $t0, 0

PrintOutputLoop:
    bge $t0, $s5, CalcMMSE
    li $v0, 2
    sll $t2, $t0, 2
    add $t2, $t2, $s4
    l.s $f12, 0($t2)
    syscall
    li $v0, 4
    la $a0, space
    syscall
    addi $t0, $t0, 1
    j PrintOutputLoop

CalcMMSE:
    la $s7, desired
    mtc1 $zero, $f10
    cvt.s.w $f10, $f10
    li $t0, 0

MMSELoop:
    bge $t0, $s5, FinalizeMMSE
    sll $t1, $t0, 2
    add $t1, $t1, $s7
    l.s $f0, 0($t1)
    sll $t2, $t0, 2
    add $t2, $t2, $s4
    l.s $f2, 0($t2)
    sub.s $f4, $f0, $f2
    mul.s $f6, $f4, $f4
    add.s $f10, $f10, $f6
    addi $t0, $t0, 1
    j MMSELoop

FinalizeMMSE:
    mtc1 $s5, $f8
    cvt.s.w $f8, $f8
    div.s $f10, $f10, $f8
    la $t0, mmse
    s.s $f10, 0($t0)
    li $v0, 4
    la $a0, mmse_msg
    syscall
    li $v0, 2
    mov.s $f12, $f10
    syscall
    li $v0, 4
    la $a0, newline
    syscall

Done:
    li $v0, 10
    syscall
