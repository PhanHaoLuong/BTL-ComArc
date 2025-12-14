.data
# File paths
input_file:     .asciiz "input.txt"
desired_file:   .asciiz "desired.txt"
output_file:    .asciiz "output.txt"

# File reading buffer
file_content:   .space 1024

# Signal arrays
.align 2
input:          .space 2000        # Max 500 floats
desired:        .space 2000        # Max 500 floats
output:         .space 2000        # Max 500 floats

# Wiener filter parameters
M:              .word 10           # Filter order
iSz:            .word 0            # Will be set after reading file
R:              .space 400         # M*M floats (10*10*4 = 400)
gamma_dx:       .space 40          # M floats (10*4 = 40)
h_out:          .space 40          # Filter coefficients
eps:            .float 1e-6
mmse:           .float 0.0         # MMSE storage

# Constants for rounding
.align 2
ten_f:          .float 10.0
half_f:         .float 0.5
zero_f:         .float 0.0

# Output messages
h_msg:          .asciiz "Coefficients h are: "
output_msg:     .asciiz "Filtered output: "
mmse_msg:       .asciiz "MMSE: "
space:          .asciiz " "
newline:        .asciiz "\n"
errorMsg:       .asciiz "Error: size not match"

# Buffer for float to string conversion
buffer:         .space 50
str_minus:      .asciiz "-"
str_dot:        .asciiz "."
str_zero:       .asciiz "0"

.text
.globl main

main:
    # Read input signal from file
    la $a0, input_file
    la $a1, input
    jal read_file_to_array
    move $s5, $v0               # Store count in $s5
    
    # Read desired signal from file
    la $a0, desired_file
    la $a1, desired
    jal read_file_to_array
    move $s7, $v0               # Store count in $s7
    
    # Verify both files have same number of samples
    bne $s5, $s7, error_exit
    beqz $s5, exit_program
    
    # Store signal size
    la $t0, iSz
    sw $s5, 0($t0)
    
    # Continue to Wiener filter processing
    j wiener_filter_start

# =========================================================================
# FILE READING SUBROUTINE
# Input: $a0 = filename address, $a1 = destination array address
# Output: $v0 = number of floats read
# =========================================================================
read_file_to_array:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    
    move $s0, $a1               # Save destination array address
    
    # Open file
    li $v0, 13
    li $a1, 0                   # Read mode
    li $a2, 0
    syscall
    move $s1, $v0               # File descriptor
    
    # Read file
    li $v0, 14
    move $a0, $s1
    la $a1, file_content
    li $a2, 1024
    syscall
    
    # Close file
    li $v0, 16
    move $a0, $s1
    syscall
    
    # Parse content
    la $s1, file_content        # Pointer to input text
    move $s2, $s0               # Pointer to output array
    li $s3, 0                   # Float counter
    
    # Load rounding constants
    la $t9, ten_f
    l.s $f10, 0($t9)
    la $t9, half_f
    l.s $f11, 0($t9)
    
    # Parsing accumulators
    li $t3, 0                   # Integer part
    li $t4, 0                   # Fractional part
    li $t5, 0                   # Fractional divisor
    li $t6, 0                   # Fractional flag
    li $t8, 0                   # Sign flag (0=positive, 1=negative)

parse_loop:
    lb $t7, 0($s1)
    beqz $t7, parse_end
    
    # Check for negative sign - ALLOW IT
    li $t9, 45                  # '-'
    bne $t7, $t9, check_space
    li $t8, 1                   # Set negative flag
    addi $s1, $s1, 1
    j parse_loop
    
check_space:
    # Space/newline -> store number
    beq $t7, 32, store_num
    beq $t7, 10, store_num
    
    # Decimal point
    beq $t7, 46, is_dot
    
    # Convert digit
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
    j next_char

is_dot:
    li $t6, 1
    li $t5, 1
    j next_char

next_char:
    addi $s1, $s1, 1
    j parse_loop

store_num:
    beqz $t3, check_frac_only
    j do_conversion
    
check_frac_only:
    beqz $t6, skip_store        # No integer and no decimal, skip
    
do_conversion:
    # Convert to float
    mtc1 $t3, $f0
    cvt.s.w $f0, $f0
    
    beqz $t6, apply_sign
    mtc1 $t4, $f1
    cvt.s.w $f1, $f1
    mtc1 $t5, $f2
    cvt.s.w $f2, $f2
    div.s $f1, $f1, $f2
    add.s $f0, $f0, $f1

apply_sign:
    # Apply negative sign if needed
    beqz $t8, rounding_step
    la $t9, zero_f
    l.s $f3, 0($t9)
    sub.s $f0, $f3, $f0         # Make negative

rounding_step:
    mul.s $f1, $f0, $f10
    add.s $f1, $f1, $f11
    cvt.w.s $f2, $f1
    cvt.s.w $f2, $f2
    div.s $f0, $f2, $f10
    
    # Store float
    s.s $f0, 0($s2)
    addi $s2, $s2, 4
    addi $s3, $s3, 1

reset_acc:
    li $t3, 0
    li $t4, 0
    li $t5, 0
    li $t6, 0
    li $t8, 0                   # Reset sign flag
    addi $s1, $s1, 1
    j parse_loop

skip_store:
    addi $s1, $s1, 1
    j parse_loop

parse_end:
    beqz $t3, check_last_frac
    j process_last
    
check_last_frac:
    beqz $t6, done_parse
    
process_last:
    # Process last number
    mtc1 $t3, $f0
    cvt.s.w $f0, $f0
    beqz $t6, apply_last_sign
    mtc1 $t4, $f1
    cvt.s.w $f1, $f1
    mtc1 $t5, $f2
    cvt.s.w $f2, $f2
    div.s $f1, $f1, $f2
    add.s $f0, $f0, $f1

apply_last_sign:
    beqz $t8, skip_frac_add
    la $t9, zero_f
    l.s $f3, 0($t9)
    sub.s $f0, $f3, $f0

skip_frac_add:
    mul.s $f1, $f0, $f10
    add.s $f1, $f1, $f11
    cvt.w.s $f2, $f1
    cvt.s.w $f2, $f2
    div.s $f0, $f2, $f10
    
    s.s $f0, 0($s2)
    addi $s3, $s3, 1

done_parse:
    move $v0, $s3               # Return float count
    
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# =========================================================================
# WIENER FILTER IMPLEMENTATION
# =========================================================================
wiener_filter_start:
    lw $s6, M                      # M = filter order
    la $s0, input
    la $s1, R
    
    # Compute Autocorrelation Matrix R
    li $t0, 0
compute_R_row:
    bge $t0, $s6, compute_gamma
    li $t1, 0
    
compute_R_col:
    bge $t1, $s6, next_R_row
    
    # Calculate lag = |i - j|
    sub $t2, $t0, $t1
    bgez $t2, lag_positive
    sub $t2, $zero, $t2
lag_positive:
    
    # Compute autocorrelation
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    move $t3, $t2
    
autocorr_sum:
    bge $t3, $s5, store_R_element
    
    sll $t4, $t3, 2
    add $t4, $t4, $s0
    l.s $f2, 0($t4)
    
    sub $t5, $t3, $t2
    sll $t5, $t5, 2
    add $t5, $t5, $s0
    l.s $f4, 0($t5)
    
    mul.s $f6, $f2, $f4
    add.s $f0, $f0, $f6
    
    addi $t3, $t3, 1
    j autocorr_sum
    
store_R_element:
    mtc1 $s5, $f8
    cvt.s.w $f8, $f8
    div.s $f0, $f0, $f8
    
    mul $t6, $t0, $s6
    add $t6, $t6, $t1
    sll $t6, $t6, 2
    add $t6, $t6, $s1
    s.s $f0, 0($t6)
    
    addi $t1, $t1, 1
    j compute_R_col
    
next_R_row:
    addi $t0, $t0, 1
    j compute_R_row

    # Compute Cross-correlation Vector gamma_dx
compute_gamma:
    la $s2, desired
    la $s3, gamma_dx
    li $t0, 0
    
compute_gamma_loop:
    bge $t0, $s6, solve_system
    
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    move $t1, $t0
    
crosscorr_sum:
    bge $t1, $s5, store_gamma
    
    sll $t2, $t1, 2
    add $t2, $t2, $s2
    l.s $f2, 0($t2)
    
    sub $t3, $t1, $t0
    sll $t3, $t3, 2
    add $t3, $t3, $s0
    l.s $f4, 0($t3)
    
    mul.s $f6, $f2, $f4
    add.s $f0, $f0, $f6
    
    addi $t1, $t1, 1
    j crosscorr_sum
    
store_gamma:
    mtc1 $s5, $f8
    cvt.s.w $f8, $f8
    div.s $f0, $f0, $f8
    
    sll $t4, $t0, 2
    add $t4, $t4, $s3
    s.s $f0, 0($t4)
    
    addi $t0, $t0, 1
    j compute_gamma_loop

    # Solve System Using Gaussian Elimination
solve_system:
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
    bge $t0, $s5, CalcMMSE
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

# Calculate MMSE
CalcMMSE:
    la $s7, desired
    la $s4, output
    lw $s5, iSz
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
    
    # Store MMSE value
    la $t0, mmse
    s.s $f10, 0($t0)
    
    # Print to console
    j PrintOutput

PrintOutput:
    li $v0, 4
    la $a0, output_msg
    syscall
    
    li $t0, 0
    lw $s5, iSz
PrintOutputLoop:
    bge $t0, $s5, PrintMMSE
    li $v0, 2
    sll $t2, $t0, 2
    la $t3, output
    add $t3, $t3, $t2
    l.s $f12, 0($t3)
    syscall
    li $v0, 4
    la $a0, space
    syscall
    addi $t0, $t0, 1
    j PrintOutputLoop

PrintMMSE:
    li $v0, 4
    la $a0, newline
    syscall
    la $a0, mmse_msg
    syscall
    
    li $v0, 2
    la $t0, mmse
    l.s $f12, 0($t0)
    syscall
    
    li $v0, 4
    la $a0, newline
    syscall
    
    j WriteToFile

# =========================================================================
# WRITE OUTPUT TO FILE
# =========================================================================
WriteToFile:
    # Open file for writing
    li $v0, 13
    la $a0, output_file
    li $a1, 1                   # Write mode
    syscall
    move $s0, $v0               # File descriptor
    
    # Write "Filtered output: "
    li $v0, 15
    move $a0, $s0
    la $a1, output_msg
    li $a2, 17
    syscall
    
    # Write output values using float_to_string
    li $t0, 0
    lw $s5, iSz
    
WriteOutputLoop:
    bge $t0, $s5, WriteMMSEToFile
    
    # Load output[i]
    sll $t1, $t0, 2
    la $t2, output
    add $t3, $t2, $t1
    l.s $f12, 0($t3)
    
    # Round to 1 decimal
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal round_to_one_decimal
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # Convert to string
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $t0, 4($sp)
    la $a0, buffer
    jal float_to_string
    lw $t0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    
    # Get string length
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $t0, 4($sp)
    la $a0, buffer
    jal get_string_length
    move $t9, $v0
    lw $t0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    
    # Write string to file
    li $v0, 15
    move $a0, $s0
    la $a1, buffer
    move $a2, $t9
    syscall
    
    # Write space
    li $v0, 15
    move $a0, $s0
    la $a1, space
    li $a2, 1
    syscall
    
    addi $t0, $t0, 1
    j WriteOutputLoop

WriteMMSEToFile:
    # Write newline
    li $v0, 15
    move $a0, $s0
    la $a1, newline
    li $a2, 1
    syscall
    
    # Write "MMSE: "
    li $v0, 15
    move $a0, $s0
    la $a1, mmse_msg
    li $a2, 6
    syscall
    
    # Load and convert MMSE
    la $t0, mmse
    l.s $f12, 0($t0)
    
    # Round to 1 decimal
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal round_to_one_decimal
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # Convert to string
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    la $a0, buffer
    jal float_to_string
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # Get string length
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    la $a0, buffer
    jal get_string_length
    move $t9, $v0
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # Write MMSE to file
    li $v0, 15
    move $a0, $s0
    la $a1, buffer
    move $a2, $t9
    syscall
    
    # Write final newline
    li $v0, 15
    move $a0, $s0
    la $a1, newline
    li $a2, 1
    syscall
    
    # Close file
    li $v0, 16
    move $a0, $s0
    syscall
    
    j exit_program

# =========================================================================
# UTILITY FUNCTIONS
# =========================================================================

# Round float in $f12 to 1 decimal place
round_to_one_decimal:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    s.s $f1, 4($sp)
    s.s $f2, 8($sp)
    
    la $t0, ten_f
    l.s $f1, 0($t0)
    mul.s $f2, $f12, $f1
    round.w.s $f2, $f2
    cvt.s.w $f2, $f2
    div.s $f12, $f2, $f1
    
    lw $ra, 0($sp)
    l.s $f1, 4($sp)
    l.s $f2, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# Convert float in $f12 to string at address $a0
float_to_string:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s7, 0($sp)
    
    move $s7, $a0
    la $t0, zero_f
    l.s $f0, 0($t0)
    
    # Handle negative
    c.lt.s $f12, $f0
    bc1f ftos_positive
    
    # Write minus sign
    la $t0, str_minus
    lb $t1, 0($t0)
    sb $t1, 0($s7)
    addi $s7, $s7, 1
    sb $t1, 0($s7)
    addi $s7, $s7, 1
    
    # Null terminate
    sb $zero, 0($s7)
    
    lw $s7, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# Convert integer to string recursively
int_to_string_recursive:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $a0, 0($sp)
    
    li $t0, 10
    div $a0, $t0
    mflo $a0
    
    bnez $a0, itos_recurse
    lw $a0, 0($sp)
    j itos_write_digit
    
itos_recurse:
    jal int_to_string_recursive
    move $a1, $v0
    lw $a0, 0($sp)
    
itos_write_digit:
    li $t0, 10
    div $a0, $t0
    mfhi $t1
    addi $t1, $t1, 48
    sb $t1, 0($a1)
    addi $v0, $a1, 1
    
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# Get string length (address in $a0, returns length in $v0)
get_string_length:
    li $v0, 0
strlen_loop:
    lb $t0, 0($a0)
    beqz $t0, strlen_done
    addi $a0, $a0, 1
    addi $v0, $v0, 1
    j strlen_loop
strlen_done:
    jr $ra

error_exit:
    li $v0, 4
    la $a0, errorMsg
    syscall
    li $v0, 4
    la $a0, newline
    syscall

exit_program:
    li $v0, 10
    syscall7, $s7, 1
    abs.s $f12, $f12
    
ftos_positive:
    # Integer part
    trunc.w.s $f1, $f12
    mfc1 $t0, $f1
    
    bnez $t0, ftos_has_int
    la $t1, str_zero
    lb $t2, 0($t1)
    sb $t2, 0($s7)
    addi $s7, $s7, 1
    j ftos_decimal_point
    
ftos_has_int:
    move $a0, $t0
    move $a1, $s7
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal int_to_string_recursive
    move $s7, $v0
    lw $ra, 0($sp)
    addi $sp, $sp, 4

ftos_decimal_point:
    # Write decimal point
    la $t0, str_dot
    lb $t1, 0($t0)
    sb $t1, 0($s7)
    addi $s7, $s7, 1
    
    # Fractional part
    cvt.s.w $f1, $f1
    sub.s $f12, $f12, $f1
    la $t0, ten_f
    l.s $f10, 0($t0)
    
    # Get 1 decimal digit
    mul.s $f12, $f12, $f10
    trunc.w.s $f1, $f12
    mfc1 $t1, $f1
    addi $t1, $t1, 48
    sb $t1, 0($s7)
    addi $s7, $s7, 1
    
    # Pad with zeros (for formatting consistency)
    li $t1, 48
    sb $t1, 0($s7)
    addi $s7, $s7, 1
    sb $t1, 0($s7)
    addi $s
