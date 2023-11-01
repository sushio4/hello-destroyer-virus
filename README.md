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
