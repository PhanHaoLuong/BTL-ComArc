.data
file:       .asciiz "Hello.txt"
content:    .space 1024
.align 2
floatArr:   .space 40           # 10 floats (4 bytes each)
space:      .asciiz " "
newline:    .asciiz "\n"
# errorMsg removed as negative numbers are now allowed

.text
main:
    #### 1. OPEN FILE ####
    li $v0, 13
    la $a0, file
    li $a1, 0           # read only
    li $a2, 0
    syscall
    move $t0, $v0       # save file descriptor

    #### 2. READ FILE ####
    li $v0, 14
    move $a0, $t0
    la $a1, content
    li $a2, 1024
    syscall

    #### 3. CLOSE FILE ####
    li $v0, 16
    move $a0, $t0
    syscall

    #### 4. PARSE INTO FLOATS ####
    la $t1, content     # content pointer
    la $t2, floatArr    # array pointer

    # Registers:
    # $t3 = integer part
    # $t4 = fractional part
    # $t5 = divisor (powers of 10)
    # $t6 = flag: 0=int processing, 1=fraction processing
    # $s4 = flag: has_digits (0=no digits seen yet, 1=digits seen)
    # $s5 = flag: is_negative (0=positive, 1=negative)

    li $t3, 0
    li $t4, 0
    li $t5, 0
    li $t6, 0
    li $s4, 0           # Initialize has_digits
    li $s5, 0           # Initialize is_negative

parse_loop:
    lb $t7, 0($t1)
    beqz $t7, parse_end        # null terminator -> end

    # --- detect negative sign ---
    li $t8, 45                 # ASCII '-'
    beq $t7, $t8, is_minus     # CHANGE: Jump to sign handler

    # --- space or newline means end of number ---
    beq $t7, 32, store_num     # Space
    beq $t7, 10, store_num     # Newline
    beq $t7, 13, store_num     # Carriage return

    # --- decimal point '.' ---
    beq $t7, 46, is_dot

    # --- digit check ---
    addi $t7, $t7, -48
    blt $t7, 0, next_char
    bgt $t7, 9, next_char

    # If we get here, it is a valid digit
    li $s4, 1                  # Set has_digits = 1

    beqz $t6, int_part
    j frac_part

is_minus:
    li $s5, 1                  # CHANGE: Set negative flag
    j next_char

int_part:
    mul $t3, $t3, 10
    add $t3, $t3, $t7
    j next_char

frac_part:
    mul $t4, $t4, 10
    add $t4, $t4, $t7
    mul $t5, $t5, 10
    j next_char

is_dot:
    li $t6, 1
    li $t5, 1
    j next_char

next_char:
    addi $t1, $t1, 1
    j parse_loop

store_num:
    beqz $s4, skip_store       # Only store if we actually saw digits

    mtc1 $t3, $f0
    cvt.s.w $f0, $f0

    beqz $t6, check_sign       # No fraction? Go straight to sign check

    # Calculate fraction
    mtc1 $t4, $f1
    cvt.s.w $f1, $f1
    mtc1 $t5, $f2
    cvt.s.w $f2, $f2
    div.s $f1, $f1, $f2
    add.s $f0, $f0, $f1        # f0 = integer + fraction

check_sign:
    # CHANGE: Apply negative sign if flag is set
    beqz $s5, store_final
    neg.s $f0, $f0

store_final:
    s.s $f0, 0($t2)
    addi $t2, $t2, 4           # Increment array pointer
    j reset_acc

reset_acc:
    li $t3, 0
    li $t4, 0
    li $t5, 0
    li $t6, 0
    li $s4, 0
    li $s5, 0                  # CHANGE: Reset negative flag
    addi $t1, $t1, 1
    j parse_loop

skip_store:
    # Even if we skip storing, we must reset flags (like is_negative)
    # in case we had a lone '-' or garbage
    li $s5, 0                  
    addi $t1, $t1, 1
    j parse_loop

parse_end:
    beqz $s4, done_parse       # If no digits pending, we are done

    mtc1 $t3, $f0
    cvt.s.w $f0, $f0

    beqz $t6, check_sign_last

    mtc1 $t4, $f1
    cvt.s.w $f1, $f1
    mtc1 $t5, $f2
    cvt.s.w $f2, $f2
    div.s $f1, $f1, $f2
    add.s $f0, $f0, $f1

check_sign_last:
    # CHANGE: Apply negative sign for the last number
    beqz $s5, save_last
    neg.s $f0, $f0

save_last:
    s.s $f0, 0($t2)
    addi $t2, $t2, 4

done_parse:
    #### 5. PRINT FLOAT ARRAY ####
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

    #### 6. EXIT ####
    li $v0, 10
    syscall
