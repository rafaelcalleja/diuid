package main

import (
	_ "embed"
	"log"
	"os"
	"syscall"
	"unsafe"
)

//go:embed file.bin
var filePayload []byte

func MemfdCreate(path string) (r1 uintptr, err error) {
	s, err := syscall.BytePtrFromString(path)
	if err != nil {
		return 0, err
	}

	r1, _, errno := syscall.Syscall(319, uintptr(unsafe.Pointer(s)), 0, 0)
	if int(r1) == -1 {
		return r1, errno
	}

	return r1, nil
}

func CopyToMem(fd uintptr, buf []byte) (err error) {
	_, err = syscall.Write(int(fd), buf)
	if err != nil {
		return err
	}

	return nil
}

func ExecveAt(fd uintptr, args []string) (err error) {
	s, err := syscall.BytePtrFromString("")
	if err != nil {
		return err
	}
	argv := append([]string{""}, args...)
	argvp, err := syscall.SlicePtrFromStrings(argv)
	if err != nil {
		return err
	}
	envv := os.Environ()
	envvp, err := syscall.SlicePtrFromStrings(envv)
	if err != nil {
		return err
	}
	ret, _, errno := syscall.Syscall6(322, fd, uintptr(unsafe.Pointer(s)),
		uintptr(unsafe.Pointer(&argvp[0])),
		uintptr(unsafe.Pointer(&envvp[0])),
		0x1000 /* AT_EMPTY_PATH */, 0)
	if int(ret) == -1 {
		return errno
	}

	// never hit
	log.Println("should never hit")
	return err
}

func main() {
	//fd, err := MemfdCreate("/file.bin", unix.MFD_CLOEXEC| unix.MFD_EXEC)
	fd, err := MemfdCreate("/file.bin")

	if err != nil {
		log.Fatal(err)
	}

	err = CopyToMem(fd, filePayload)
	if err != nil {
		log.Fatal(err)
	}


	err = ExecveAt(fd, []string{})

	if err != nil {
		log.Fatal(err)
	}

}
