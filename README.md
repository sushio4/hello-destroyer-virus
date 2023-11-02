# hello-destroyer-virus
This simple virus copies itself to an elf named "hello". Payload is just a write syscall to standard output that says "I am virus"
## how it works
- Display
- Open file named "hello"
- Search for program header with PT_NOTE type
- Change this header so it's loadable and executable
- Copy itself to the end of a file
- Change elf header so the victim starts executing virus first
- Put jump instruction at the end so it returns control to the original program
## build
For building inj_asm I used gcc with following flags:
- s
- nostdlib
- no-pie
If you want it to be REALLY tiny (641B) build inj_asm_tiny as follows:
- as inj_asm_tiny.s -o inj_asm_tiny.o --64
- ld -Ttext 0 --oformat=binary -o inj_asm_tiny inj_asm_tiny.o
