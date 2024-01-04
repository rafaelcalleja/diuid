package main

import (
	_ "embed"
	"log"
	"os"

	"codeberg.org/msantos/execve"

	"golang.org/x/sys/unix"
)

//go:embed file.bin
var bin []byte

func main() {
	fd, err := unix.MemfdCreate("file.bin", unix.MFD_CLOEXEC)
	if err != nil {
		log.Fatalln("MemfdCreate:", err)
	}

	if n, err := unix.Write(fd, bin); err != nil || n != len(bin) {
		log.Fatalln("Write:", err)
	}

	if err := execve.Fexecve(uintptr(fd), os.Args, os.Environ()); err != nil {
		log.Fatalln("Fexecve:", err)
	}
	os.Exit(126)
}
