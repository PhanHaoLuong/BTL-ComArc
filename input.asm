.data
file:       .asciiz "Hello.txt"
content:    .space 1024
.align 2
floatArr:   .space 40          # space for 10 floats (10 * 4 bytes)
space:      .asciiz " "
newline:    .asciiz "\n"
errorMsg:   .asciiz "Error: negative numbers are not allowed.\n"

# constants for rounding
.align 2
ten_f:      .float 10.0
half_f:     .float 0.5
zero_f:     .float 0.0

.text
.globl main
main:
    #### 1) OPEN FILE ###
    li $v0, 13
    la $a0, file
    li $a1, 0
    li $a2, 0
    syscall
    move $t0, $v0           # file descriptor

    #### 2) READ FILE ###
    li $v0, 14
    move $a0, $t0
    la $a1, content
    li $a2, 1024
    syscall

    #### 3) CLOSE FILE ###
    li $v0, 16
    move $a0, $t0
    syscall

    #### 4) PREP: pointers & zero constants ###
    la $t1, content         # pointer to input text
    la $t2, floatArr        # pointer where we store floats

    # load rounding constants into FPU registers
    la $t9, ten_f
    l.s $f10, 0($t9)        # $f10 = 10.0

    la $t9, half_f
    l.s $f11, 0($t9)        # $f11 = 0.5

    la $t9, zero_f
    l.s $f14, 0($t9)        # $f14 = 0.0 (for negative check if needed)

    # temporary integer accumulators (string parsing)
    li $t3, 0               # integer part accumulator
    li $t4, 0               # fractional part accumulator
    li $t5, 0               # fractional divisor as integer (10,100,...)
    li $t6, 0               # fractional flag (0=int part, 1=fraction part)

parse_loop:
    lb $t7, 0($t1)
    beqz $t7, parse_end     # end of string

    # negative sign check -> immediate error
    li $t8, 45              # ASCII '-'
    beq $t7, $t8, error_exit

    # space/newline -> end of a number
    beq $t7, 32, store_num
    beq $t7, 10, store_num

    # decimal point
    beq $t7, 46, is_dot

    # digit? convert ascii to 0..9
    addi $t7, $t7, -48
    blt $t7, 0, next_char
    bgt $t7, 9, next_char

    beqz $t6, int_part
    j frac_part

int_part:
    mul $t3, $t3, 10
    add $t3, $t3, $t7
    j next_char

frac_part:
    mul $t4, $t4, 10
    add $t4, $t4, $t7
    mul $t5, $t5, 10
    addi $t5, $t5, 0
    j next_char

is_dot:
    li $t6, 1
    li $t5, 1              # initialize divisor accumulator for fraction digits
    j next_char

next_char:
    addi $t1, $t1, 1
    j parse_loop

store_num:
    beqz $t3, skip_store   # nothing to store (multiple spaces), skip

    # Convert integer part to float in $f0
    mtc1 $t3, $f0          # move integer bits into $f0
    cvt.s.w $f0, $f0       # $f0 = float(integer part)

    # if fractional part exists, compute fraction float = t4 / t5 and add
    beqz $t6, rounding_step
    mtc1 $t1, $f1          # reuse $f1 temporarily (move something to satisfy instruction pattern)
    mtc1 $t4, $f1          # $f1 contains integer fractional digits
    cvt.s.w $f1, $f1       # fractional digits as float
    mtc1 $t9, $f2          # temporary: load divisor integer into f2 via mtc1
    mtc1 $t9, $f2          # (we'll instead load divisor using integer -> f2 correctly below)

    # load divisor t5 into $f2 properly:
    # t5 is an integer in integer reg; move then convert
    mtc1 $t5, $f2
    cvt.s.w $f2, $f2

    div.s $f1, $f1, $f2    # f1 = fractional_part / divisor
    add.s $f0, $f0, $f1    # f0 = integer + fractional

rounding_step:
    # ROUND TO 1 DECIMAL: rounded = floor(x*10 + 0.5) / 10
    mul.s $f1, $f0, $f10   # f1 = x * 10
    add.s $f1, $f1, $f11   # f1 = x*10 + 0.5
    cvt.w.s $f2, $f1       # convert to integer in FPU (round toward zero/truncate)
    cvt.s.w $f2, $f2       # convert back to float
    div.s $f0, $f2, $f10   # f0 = (int) / 10 => rounded value in f0

    # store f0 into array (ensure alignment)
    andi $t9, $t2, 3
    bnez $t9, align_fix_store
    s.s $f0, 0($t2)
    addi $t2, $t2, 4
    j reset_acc

align_fix_store:
    # safety: move t2 to next aligned boundary and store
    addi $t2, $t2, 4
    s.s $f0, -4($t2)
    j reset_acc

reset_acc:
    # reset parsing accumulators
    li $t3, 0
    li $t4, 0
    li $t5, 0
    li $t6, 0
    addi $t1, $t1, 1
    j parse_loop

skip_store:
    addi $t1, $t1, 1
    j parse_loop

parse_end:
    # handle last number if file does not end with space/newline
    beqz $t3, done_parse

    # same conversion as store_num but simpler (no extra pointer moves)
    mtc1 $t3, $f0
    cvt.s.w $f0, $f0
    beqz $t6, skip_frac_add
    mtc1 $t4, $f1
    cvt.s.w $f1, $f1
    mtc1 $t5, $f2
    cvt.s.w $f2, $f2
    div.s $f1, $f1, $f2
    add.s $f0, $f0, $f1

skip_frac_add:
    # rounding (same as above)
    mul.s $f1, $f0, $f10
    add.s $f1, $f1, $f11
    cvt.w.s $f2, $f1
    cvt.s.w $f2, $f2
    div.s $f0, $f2, $f10

    # store
    andi $t9, $t2, 3
    bnez $t9, end_align_fix
    s.s $f0, 0($t2)
    addi $t2, $t2, 4
    j done_parse

end_align_fix:
    addi $t2, $t2, 4
    s.s $f0, -4($t2)
    j done_parse

done_parse:
    #### 5) PRINT STORED FLOATS ####
    la $t2, floatArr
    li $t8, 0

print_loop:
    l.s $f12, 0($t2)
    li $v0, 2
    syscall

    li $v0, 4
    la $a0, space
    syscall

    addi $t2, $t2, 4
    addi $t8, $t8, 1
    blt $t8, 10, print_loop

    #### 6) EXIT ####
    li $v0, 10
    syscall

# Immediate error handler for negative numbers
error_exit:
    li $v0, 4
    la $a0, errorMsg
    syscall
    li $v0, 10
    syscall
