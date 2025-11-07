.data
M:              .word 3
R:              .float 2.0, 1.5, 0.9, 1.5, 2.0, 1.5, 0.9, 1.5, 2.0
gamma_dx:       .float 1.8, 1.2, 0.7
h_out:          .float 0.0, 0.0, 0.0
eps:            .float 0.000001
newline:        .asciiz "\n"

.text
main:
    la   $s0, R
    la   $s1, gamma_dx
    la   $s2, h_out
    lw   $t0, M

    li   $t1, 0
FwdLoop:
    bge  $t1, $t0, BackSub

    mul  $t2, $t1, $t0
    add  $t3, $t2, $t1
    sll  $t3, $t3, 2
    add  $t3, $t3, $s0
    l.s  $f0, 0($t3)
    la   $t4, eps
    l.s  $f2, 0($t4)
    add.s $f0, $f0, $f2
    s.s  $f0, 0($t3)

    addi $t5, $t1, 1
InnerI:
    bge  $t5, $t0, NextK

    mul  $t6, $t5, $t0
    add  $t7, $t6, $t1
    sll  $t7, $t7, 2
    add  $t7, $t7, $s0
    l.s  $f4, 0($t7)

    mul  $t8, $t1, $t0
    add  $t9, $t8, $t1
    sll  $t9, $t9, 2
    add  $t9, $t9, $s0
    l.s  $f6, 0($t9)
    div.s $f8, $f4, $f6

    li   $t2, 0
InnerJ:
    bge  $t2, $t0, NextRow

    mul  $t3, $t5, $t0
    add  $t3, $t3, $t2
    sll  $t3, $t3, 2
    add  $t3, $t3, $s0
    l.s  $f10, 0($t3)

    mul  $t4, $t1, $t0
    add  $t4, $t4, $t2
    sll  $t4, $t4, 2
    add  $t4, $t4, $s0
    l.s  $f12, 0($t4)

    mul.s $f14, $f8, $f12
    sub.s $f10, $f10, $f14
    s.s  $f10, 0($t3)

    addi $t2, $t2, 1
    j    InnerJ
NextRow:
    sll  $t6, $t5, 2
    add  $t6, $t6, $s1
    l.s  $f16, 0($t6)

    sll  $t7, $t1, 2
    add  $t7, $t7, $s1
    l.s  $f18, 0($t7)

    mul.s $f20, $f8, $f18
    sub.s $f16, $f16, $f20
    s.s  $f16, 0($t6)

    addi $t5, $t5, 1
    j    InnerI
NextK:
    addi $t1, $t1, 1
    j    FwdLoop

BackSub:
    addi $t1, $t0, -1
BackLoop:
    blt  $t1, $zero, PrintH
    sll  $t2, $t1, 2
    add  $t2, $t2, $s1
    l.s  $f0, 0($t2)

    addi $t3, $t1, 1
InnerSum:
    bge  $t3, $t0, SolveH
    mul  $t4, $t1, $t0
    add  $t5, $t4, $t3
    sll  $t5, $t5, 2
    add  $t5, $t5, $s0
    l.s  $f2, 0($t5)

    sll  $t6, $t3, 2
    add  $t6, $t6, $s2
    l.s  $f4, 0($t6)

    mul.s $f6, $f2, $f4
    sub.s $f0, $f0, $f6

    addi $t3, $t3, 1
    j    InnerSum
SolveH:
    mul  $t7, $t1, $t0
    add  $t8, $t7, $t1
    sll  $t8, $t8, 2
    add  $t8, $t8, $s0
    l.s  $f8, 0($t8)

    div.s $f10, $f0, $f8
    sll  $t9, $t1, 2
    add  $t9, $t9, $s2
    s.s  $f10, 0($t9)

    addi $t1, $t1, -1
    j    BackLoop

PrintH:
    li   $t1, 0
PrintLoop:
    bge  $t1, $t0, Exit
    sll  $t2, $t1, 2
    add  $t2, $t2, $s2
    l.s  $f12, 0($t2)
    li   $v0, 2
    syscall
    la   $a0, newline
    li   $v0, 4
    syscall
    addi $t1, $t1, 1
    j    PrintLoop

Exit:
    li   $v0, 10
    syscall
 
