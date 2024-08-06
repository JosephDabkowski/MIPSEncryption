# DESCRIPTION
# The purpose of this program is to encrypt/decrypt a file for a user using a simple key algorithm, then store it in a readable file for the user.
# The program prompts the user for 3 options: 1. Encrypt, 2. Decrypt, or 3. Exit. When the user chooses 3, the program exits without falling through
# If the user chooses 1 or 2, the program requests a filename from the user, at which point, the program checks if the file exists. If it does not 
# exist, the program returns to the menu. Then the program requests a key from the user and adds a /0 null terminator at the end of it.
# Otherwise, the program then checks the status of the file's extension in relation to what menu option they selected. If the user selected 1, 
# encryption, all file extensions are valid, but if the user selected 2, the program must ensure that the file has a .enc extension. If it doesn't 
# the program issues a warning and returns to menu. At this point, if there are no issues, the program proceeds to copy the filename and add a .enc 
# or .txt extension depending on whether the user is encrypting or decrypting the file (respectively). Then begins the "translation" 
# (encryption/decryption) process. The program opens the user's file, and the new-created file, reads 1024 bytes of data from the file. Then byte-by-byte
# the program decrypts or encrypts the characters in the file and stores them in the buffer they were read from. Then it writes the data from the 
# buffer to the file. At which point, the program will attempt to read 1024 more bytes from the file, if it reads 0 then the program will terminate
# the translation process and close both files. Otherwise, the translation process will continue. If the process terminates, the program returns to the
# menu and prepares for encryption or decryption or an exit.
# Joseph Dabkowski
# JAD210011
# Starting November 11, 2023
.include "SysCalls.asm"
### Data Segment Starts Here ###
.data
menu:			.asciiz	"1: Encrypt the file\n2: Decrypt the file\n3: Exit\n"
filename_prompt:		.asciiz	"Enter a valid filename: "
key_prompt:		.asciiz	"Enter a key: "
input_err:		.asciiz	"Invalid Input. Please try again and enter [1-3].\n"
file_dne_err:		.asciiz	"File does not exist. Try Again.\n"
wrong_file_enc:		.asciiz	"File of incorrect type, only '.enc' supported for decryption.\nTry Again.\n"
wrong_file_gen:		.asciiz	"File of incorrect type, only '.txt' and '.enc' supported.\nTry Again.\n"
file_not_created:		.asciiz	"Error: New file could not be created.\n"
txt:			.asciiz	"txt"
enc:			.asciiz	"enc"
key:			.space	61		# Reserves 60-bytes, 60-characters + 1 byte for null-terminator in memory for key
filename:			.space	256		# Reserves 256-bytes, 255-characters + null-terminator for the filename
filename_2:		.space	256		# Reserves 256-bytes, 255-characters + null-terminator for the filename copy with changed 
						# extension
buffer:			.space	1024		# Reservers 1024-bytes for reading from file 
### Text Segment Starts Here ###
.text
.globl	main					# Global Main
# main label serves as menu function
main:
	li	$v0, SysPrintString			# load SysPrintString
	la	$a0, menu				# load menu address
	syscall					# print menu
	li	$v0, SysReadInt			# load SysReadInt
	syscall					# Read Int from user
	move	$s0, $v0				# move result into $s0
	beq	$v0, 1, filename_read		# if result == 1 -> jump to file name reading procedure
	beq	$v0, 2, filename_read		# if result == 2 -> jump to file name reading procedure
	beq	$v0, 3, full_exit			# if result == 3 -> jump to program exit (found at end of file)
	bge	$v0, 4, input_error_1		# if result >= 4, invalid input
	ble	$v0, 0, input_error_1		# if result <= 0, invalid input
# input_error_1 used for printing an error statement if input is invalid
input_error_1:
	li	$v0, SysPrintString			# load SysPrintString
	la	$a0, input_err			# load input_error message address
	syscall					# print error message
	j	main				# jump back to menu print - main
# filename_read is used to read the filename from the user, check the extension, and create a .enc/.txt for the .txt/.enc file (respectively)
filename_read:
	li	$v0, SysPrintString			# load SysPrintString
	la	$a0, filename_prompt		# load address of filename_prompt
	syscall					# print filename insert prompt
	li	$v0, SysReadString			# load SysReadString
	la	$a0, filename			# load filename space
	li	$a1, 256				# load max filename size + 1
	syscall					# read filename from user
	li	$t0, 0				# load 0 into $t0 for use in clean_filename
	jal	clean_filename			# jump and link to clean_filename
	jal	check_ext				# jump and link to check_ext
	beq	$s2, 3, invalid_file_ext		# if $s2 == 3, it means that the extension is neither .enc or .txt, branch to invalid_file_ext
						# the following operations
	bne	$s2, $s0, wrong_file_ext_2   		# if user choice not equal to file extension, branch to wrong_file_ext
	li	$v0, SysOpenFile			# load SysOpenFile
	la	$a0, filename			# load filename address
	li	$a1, 0				# load read-only flag
	li	$a2, 0				# load $a2 to 0, in case that it has not been reset from previous run			
	syscall					# load file
	bltz	$v0, fnf				# if $v0 <= 0, file could not be opened, branch to fnf (file-not-found)
	move	$a0, $v0				# move $v0 into $a0 (for file close)
	li	$v0, SysCloseFile			# load SysCloseFile
	syscall					# close the file (for now)
	li	$v0, SysPrintString			# load SysPrintString
	la	$a0, key_prompt			# load address of key_prompt
	syscall					# print key entry prompt
	li	$v0, SysReadString			# load SysReadString
	la	$a0, key				# load key address
	li	$a1, 61				# load max key length + 1
	syscall					# read key from user
	li	$t0, 0				# load 0 into $t0 for ext_change
	j	ext_change			# jump to ext_change (extension change
# filename_read_2 is a continuation of filename_read procedure for ext_change to jump back to
filename_read_2:
	li	$t0, 0				# load 0 into $t0
	jal	clean_key				# jump and link to clean_key
	beq	$s0, 1, translate			# if user_choice == 1, branch to translate
	beq	$s0, 2, translate			# if user_choice == 2, branch to translate
	j	filename_read			# otherwise, which should be impossible, jump back to top of filename_read
# fnf (file-not-found) prints an error statement for file not being found, then jumps back to top of main
fnf:
	li	$v0, SysPrintString			# load SysPrintString
	la	$a0, file_dne_err			# load file_dne_error error message
	syscall					# print error message
	j	main				# jump back to main (menu)
# invalid_file_ext prints an error message warning the user that they have entered an invalid extension
invalid_file_ext:
	li	$v0, SysPrintString			# load SysPrintString
	la	$a0, wrong_file_gen			# load address of wrong_file_gen
	syscall					# print error message
	j	main				# jump back to main (menu)
# invalid_file_ext prints an error message warning the user that they have entered an invalid extension for the requested operation
# in this case .enc
wrong_file_ext_2:
	li	$v0, SysPrintString			# load SysPrintString
	la	$a0, wrong_file_enc			# load wrong_file_enc message address
	syscall					# print that you cant use .enc for decryption
	j	main				# jump back to main (menu)
# translate is the label that prepares the program for encrypting/decrypting the file 
translate:
	move	$s1, $s0				# move $s0 (user choice) to $s1
	li	$v0, SysOpenFile			# load SysOpenFile
	la	$a0, filename			# load filename address
	la	$a1, 0				# load read-only-flag
	la	$a2, 0				# ensure that $a2 is 0
	syscall					# open [filename] file
	move	$s0, $v0				# $s0 stores [filename]'s descriptor
	li	$v0, SysOpenFile			# load SysOpenFile
	la	$a0, filename_2			# load filename_2 (alternate extension for encrypt/decrypt)
	li	$a1, 1				# load 1 for writing
	li	$a2, 0				# ensure that $a2 is 0
	syscall					# open [filename_2] for writing
	move	$s2, $v0				# $s2 stores [filename_2]'s descriptor
	li	$k1, 0				# buffer index
	li	$k0, 0				# key index
	bltz	$v0, new_file_fail			# check if file was created, if not branch to new_file_fail
# translate_2 is the label that reads the next 1024 bytes for conversion
translate_2:
	li	$v0, SysReadFile			# load file read instruction
	move	$a0, $s0				# move [filename] descriptor into $a0
	la	$a1, buffer			# load buffer address
	li	$a2, 1024				# load buffer length
	syscall					# load next 1024 bytes into buffer
	move	$t3, $v0				# move amount of bytes read into $t3
	blez 	$v0, exit_translate  		# if 0 or less, that means that there are no bytes
	sb	$zero, buffer($v0)			# store terminator at end of buffer
	li	$t5, 0				# load 0 into $t5 (conversion counter)
# translate_loop iterates byte-by-byte and encrypts/decrypts them, then stores them back in buffer
translate_loop:
	lb	$t1, buffer($k0)			# load buffer at $k0 into $t1
	lb	$t2, key($k1)			# load key at $k1 into $t2
	beq	$t1, '\0', exit_translate_loop	# if $t1 is terminator, branch to exit_translate_loop 
	beq	$t2, '\0', reset_key		# if $t2 is terminator, branch to reset_key
	beq	$s1, 1, encrypt_char		# if $s1 (user choice) == 1, encrypt that byte, branch to encrypt_char
	beq	$s1, 2, decrypt_char		# if $s1 (user choice) == 2, decrypt that byte, branch to decrypt_char
	addi	$t5, $t5, 1			# increment conversion counter
# translate_loop_2 is a breakpoint for translate loop
translate_loop_2:
	addi	$k0, $k0, 1			# increment buffer index
	addi	$k1, $k1, 1			# increment key index
	j	translate_loop			# jump back to top of translate_loop
# encrypt_char adds (buffer char) and (key char) then stores them back into buffer, then jumps back to translate_loop_2
encrypt_char:
	addu	$t1, $t1, $t2			# add $t1 and $t2, store in $t1
	sb	$t1, buffer($k0)			# store $t1 in buffer at $k0
	j	translate_loop_2			# jump back to translate_loop_2
# decrypt_char subtrancts (key char) from (buffer char) then stores them back into buffer, then jumps back to translate_loop_2
decrypt_char:
	subu	$t1, $t1, $t2			# subtract $t2 from $t1, then store in $t1
	sb	$t1, buffer($k0)			# store byte $t1 in buffer at $k0 
	j	translate_loop_2			# jump back to translate_loop_2
# exit_translate_loop stores /0 in the remaining unaltered buffer bytes (so that they dont appear in decrypted or encrypted file)
exit_translate_loop:
	bge	$k0, 1023, exit_translate_loop_2	# if $k0 (buffer index) >= 1023, then proceed to exit_translate_loop_2
	addi	$k0, $k0, 1			# increment $k0 buffer index
	sb	$zero, buffer($k0)			# store /0 in buffer at $k0
	j	exit_translate_loop			# jump back to exit_translate_loop
# exit_translate_loop_2 resets the index, then writes the modified buffer to [filename_2], then jumps back to translate_2 to read next 1024 bytes
exit_translate_loop_2:
	li	$k0, 0				# reset index $k0
	move	$a0, $s2				# move $s2 [filename_2] descriptor to $a0
	li	$v0, SysWriteFile			# load SysFileWrite
	la	$a1, buffer			# load buffer address
	syscall					# write modified buffer to [filename_2]
	j	translate_2			# jump back to translate_2
# reset_key resets the index of key and the key itself, then jumps back to translate_loop
reset_key:
	li	$k1, 0				# reset index $k1
	lb	$t2, key($k1)			# load new byte at $k1
	j	translate_loop			# jump back to translate_loop
# write_current writes the current buffer to the file
write_current:
	move	$a0, $s2				# move $s2 [filename_2] descriptor to $a0
	li	$v0, SysWriteFile			# load SysFileWrite
	la	$a1, buffer			# load buffer address
	move	$a2, $t3				# load bytes read to $a2
	syscall					# write current buffer to [filename_2]
	li	$k1, 0				# reset index $k1
	j	translate_2			# jump back to translate_2
# exit_translate closes both files, then jumps back to main (menu)
exit_translate:
	li	$v0, SysCloseFile			# load SysCloseFile
	move	$a0, $s2				# move [filename_2] descriptor to $a0
	syscall					# close [filename_2]
	li	$v0, SysCloseFile			# load SysCloseFile
	move	$a0, $s0				# move [filename] descriptor to $a0
	syscall					# close [filename]
	j	main				# jump back to main (menu)
# new_file_fail prints an error if a new file could not be created
new_file_fail:
	li	$v0, SysPrintString			# load SysPrintString
	la	$a0, file_not_created		# load file_not_created address
	syscall					# print error statement
	j	main				# jump back to main (menu)
# newline removal procedure/subroutine for filename, this is not a function.
# Requires 0 in $t0
# clean_filename iterates through filename, checking for \0 or \n
clean_filename:
	lb	$t1, filename($t0)			# load byte of filename at $t0, store in $t1
	beq	$t1, '\0', exit_newline_file		# if $t1 == \0, branch to exit_newline_file, procedure is complete
	beq	$t1, '\n', rem_newline_file		# if $t1 == \n, branch to rem_newline_file for \n removal
	addi	$t0, $t0, 1			# increment index
	j	clean_filename			# jump back to clean_filename
# rem_newline_file replaces the current byte (newline) with \0
rem_newline_file:
	sb	$zero, filename($t0)		# store \0 in filename at $t0
# exit_newline_file resets index, then jumps register back to $ra
exit_newline_file:
	li	$t0, 0				# resets $t0 index
	jr	$ra				# jump register back to $ra
# end of newline removal procedure/subroutine for filename

# newline removal procedure/subroutine for key, this is not a function.
# Requires 0 in $t0
# clean_key iterates through key, checking for \0 or \n
clean_key:
	lb	$t1, key($t0)			# load byte of key at $t0, store in $t1
	beq	$t1, '\0', exit_newline_key		# if $t1 == \0, branch to exit_newline_key, procedure is complete
	beq	$t1, '\n', rem_newline_key		# if $t1 == \n, branch to rem_newline_key for \n removal
	addi	$t0, $t0, 1			# increment index
	j	clean_key				# jump back to clean_key
# rem_newline_key replaces the current byte (newline) with \0
rem_newline_key:
	sb	$zero, key($t0)			# store \0 in key at $t0
# exit_newline_key resets index, then jumps register back to $ra
exit_newline_key:
	li	$t0, 0				# resets $t0 index
	jr	$ra				# jump register back to $ra
# end of newline removal procedure/subroutine for key
# check_ext checks what type of file was inputted, returning 1 if it is .txt, 2 if it is .enc, and 3 if it is something else
check_ext:
	beq	$s0, 1, override_check_ext		# if user_choice is encryption, override check
	lb	$t1, filename($t0)			# load byte of filename at $t0, store in $t1
	beq	$t1, '.', e_or_t			# if $t1 == ., the extension is beginning, branch to e_or_t
	addi	$t0, $t0, 1			# increment index
	j	check_ext				# jump back to top of check_ext
# e_or_t checks if the first character of extension is e or t
e_or_t:
	addi	$t0, $t0, 1			# increment index
	lb	$t1, filename($t0)			# load byte of filename at $t0, store in $t1
	beq	$t1, 't', txt_check_2		# if $t1 == t, branch to txt_check_2
	beq	$t1, 'e', enc_check_2		# if $t1 == e, branch to enc_check_2
	j	invalid_ext			# jump to invalid_ext
# txt_check_2 checks if the second character of extension is x, otherwise its wrong
txt_check_2:
	addi	$t0, $t0, 1			# increment index
	lb	$t1, filename($t0)			# load byte of filename at $t0, store in $t1
	beq	$t1, 'x', txt_check_3		# if $t1 == x, branch to txt_check_3
	j	invalid_ext			# jump to invalid_ext
# txt_check_3 checks if the third character of extension is t, otherwise its wrong
txt_check_3:
	addi	$t0, $t0, 1			# increment index
	lb	$t1, filename($t0)			# load byte of filename at $t0, store in $t1
	bne	$t1, 't', invalid_ext		# if $t1 != t, branch to invalid_ext
	li	$s2, 1				# load 1 into $s2 (means that filename has encryption-usable extension)
	jr	$ra				# jump back to register $ra
# enc_check_2 checks if the second character of extension is n, otherwise its wrong
enc_check_2:
	addi	$t0, $t0, 1			# increment index
	lb	$t1, filename($t0)			# load filename at $t0 into $t1
	beq	$t1, 'n', enc_check_3		# if $t1 == n, branch to enc_check_3
	j	invalid_ext			# jump to invalid_ext
# enc_check_3 checks if the third character of extension is c, otherwise its wrong
enc_check_3:
	addi	$t0, $t0, 1			# increment index
	lb	$t1, filename($t0)			# load filename at $t0 into $t1
	bne	$t1, 'c', invalid_ext		# if $t1 != c, branch to invalid_ext
	li	$s2, 2				# load 2 into $s2 (means that filename has decryption-usable extension)
	jr	$ra				# jump to invalid_ext
# invalid_ext stores 3 (invalid code) into $s2, then jumps register to $ra
invalid_ext:
	li	$s2, 1				# load 3 into $s2
	jr	$ra				# jump register to $ra
override_check_ext:
	li	$s2, 1
	jr	$ra
# end of check_ext
# ext_change, changes .txt filename to .enc filename - requires 0 in $t0, loops through and checks for .
ext_change:
	lb	$t1, filename($t0)			# load $t0-th byte of filename
	beq	$t1, '.', ext_proced_1		# if this byte == '.', then time for extension swap
	sb	$t1, filename_2($t0)		# otherwise, copy filename at $t0 to filename_2 at $t0
	addi	$t0, $t0, 1			# increment index
	j	ext_change			# loop back to top
# ext_proced_1 copies the . into filename_2, then begins enc_to_txt or add_enc
ext_proced_1:
	sb	$t1, filename_2($t0)		# Store '.' character before extension
	addi	$t0, $t0, 1			# increment index
	lb	$t1, filename($t0)			# get first byte after '.' in filename
	beq	$t1, 'e', enc_to_txt		# if first byte is 'e' the extension is enc -> txt
	j	add_enc			# otherwise, perform txt -> enc
# enc_to_txt adds txt to the end of filename_2
enc_to_txt:
	li	$t5, 0				# load 0 into $t5 (extension index)
	lb	$t2, txt($t5)			# load first byte of txt into $t2
	addi	$t5, $t5, 1			# increment extension index
	lb	$t3, txt($t5)			# load second byte of txt into $t3
	sb	$t2, filename_2($t0)		# store t into filename_2 at $t0
	addi	$t0, $t0, 1			# increment filename index
	sb	$t3, filename_2($t0)		# load x into filename_2 at $t0
	addi	$t0, $t0, 1			# increment filename index
	sb	$t2, filename_2($t0)		# store t into filename_2 at $t0
	li	$t2, 0				# reset $t0
	li	$t3, 0				# reset $t3
	j	filename_read_2			# jump to filename_read_2 (breakpoint)
# enc_to_txt adds txt to the end of filename_2
add_enc:
	li	$t5, 0				# load 0 into $t5 (extension index)
	lb	$t2, enc($t5)			# load first byte of enc into $t2
	addi	$t5, $t5, 1			# increment extension index
	lb	$t3, enc($t5)			# load second byte of enc into $t3
	addi	$t5, $t5, 1			# increment filename_2 index
	lb	$t4, enc($t5)			# load third byte of enc into $t4
	sb	$t2, filename_2($t0)		# store e in filename_2 at $t0
	addi	$t0, $t0, 1			# increment filename index
	sb	$t3, filename_2($t0)		# store n in filename_2 at $t0
	addi	$t0, $t0, 1			# increment filename index
	sb	$t4, filename_2($t0)		# store c in filename_2 at $t0
	li	$t2, 0				# reset t2
	li	$t3, 0				# reset t3
	li	$t4, 0				# reset t4
	j	filename_read_2			# jump to filename_read_2 (breakpoint)
# end of ext_change procedure
full_exit:
	li	$v0, SysExit			# load SysExit
	syscall					# Exit Program
### End of Program ###