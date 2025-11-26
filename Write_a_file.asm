.data
	filepath:	.asciiz "output.txt"
	message:	.asciiz "Hello world, gay!"	
	buffer:	.space	1024

.text

main:
	# open a file
	li 	$v0, 13
	la 	$a0, filepath
	li	$a1, 1		# flag 1 for write mode
	syscall
	move	$t0, $v0		# store file path
	
	# write to file
	li	$v0, 15
	move	$a0, $t0
	la	$a1, message
	li	$a2, 1024		# number of bytes to write
	syscall
	
	# close a file
	li	$v0, 16
	move	$a0, $t0
	syscall
	
	# exit program
	li	$v0, 10
	syscall
