.data
	filepath:	.asciiz 	"output.txt"
	newline	.asciiz 	"\n"
	message:	.asciiz 	"Hello world, gay!"	
	buffer:	.space	50

.text

main:

write_output:
	# open a file
	li 	$v0, 13
	la 	$a0, filepath
	li	$a1, 1		# flag 1 for write mode
	syscall
	move	$s0, $v0		# store file path
	
	li   $t0, 0		# i = 0
	
write_loop:

	bge  $t0, 500, write_done # for (i = 0; i < 500; i++)
	
	#### Load arr[i] into $f12 ####
    la   $t1, arr
    sll  $t2, $t0, 2	# offset = i * 4
    add  $t1, $t1, $t2
    l.s  $f12, 0($t1)
    
    #### Convert float ? string in buffer ####
    li   $v0, 2         	# print float syscall
    syscall			# prints to console!

    # BUT we want the string, so we capture it:
    # MARS places printed text into console only, not buffer.
    # So instead, use syscall 3: float to string.

    li   $v0, 3           # float to string
    la   $a0, buffer
    li   $a1, 50
    syscall
    # now buffer contains ASCII representation of float
	
	
	# write to file
	li	$v0, 15
	move	$a0, $s0		# file path
	la	$a1, buffer
	move	$a2, $v0		# syscall 3 returns length in $v0
	syscall
	
	#### Write newline ####
    	li   $v0, 15
   	move $a0, $s0
    	la   $a1, newline
    	li   $a2, 1
    	syscall

    	#### next i ####
    	addi $t0, $t0, 1
    	j write_loop
	
write_done:
	# close a file
	li	$v0, 16
	move	$a0, $t0
	syscall
	
	# exit program
	li	$v0, 10
	syscall
