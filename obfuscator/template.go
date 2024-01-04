package main

import (
    "obfuscator/FILE"
    "fmt"
    "os"
    "strings"
    "context"
)

func main() {
    exe, err := FILE.New()
    if err != nil {
        panic(err)
    }
    defer exe.Close()

    c := exe.CommandContext(context.Background(), os.Args[1:]...)
	c.Stdin = os.Stdin
	c.Env = os.Environ()
	b, err := c.CombinedOutput()

	if err != nil {
	    fmt.Print(strings.TrimSpace(string(b)))
	    panic(err)
	}

    fmt.Print(strings.TrimSpace(string(b)))
}
