package main

import (
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"syscall"

	"github.com/rootless-containers/rootlesskit/v2/pkg/api"
)

const (
	realProxy       = "docker-proxy"
	diuidParentHost = "10.0.2.2"
	diuidParentPort = "2222"
)

// drop-in replacement for docker-proxy.
// needs to be executed in the child namespace.
func main() {
	f := os.NewFile(3, "signal-parent")
	defer f.Close()
	if err := xmain(f); err != nil {
		// success: "0\n" (written by realProxy)
		// error: "1\n" (written by either rootlesskit-docker-proxy or realProxy)
		fmt.Fprintf(f, "1\n%s", err)
		log.Fatal(err)
	}
}

func isIPv6(ipStr string) bool {
	ip := net.ParseIP(ipStr)
	if ip == nil {
		return false
	}
	return ip.To4() == nil
}

func getPortDriverProtos(info *api.Info) (string, map[string]struct{}, error) {
	if info.PortDriver == nil {
		return "", nil, errors.New("no port driver is available")
	}
	m := make(map[string]struct{}, len(info.PortDriver.Protos))
	for _, p := range info.PortDriver.Protos {
		m[p] = struct{}{}
	}
	return info.PortDriver.Driver, m, nil
}

type protocolUnsupportedError struct {
	apiProto       string
	portDriverName string
	hostIP         string
	hostPort       int
}

func (e *protocolUnsupportedError) Error() string {
	return fmt.Sprintf("protocol %q is not supported by the RootlessKit port driver %q, discarding request for %q",
		e.apiProto,
		e.portDriverName,
		net.JoinHostPort(e.hostIP, strconv.Itoa(e.hostPort)))
}

func xmain(f *os.File) error {
	containerIP := flag.String("container-ip", "", "container ip")
	containerPort := flag.Int("container-port", -1, "container port")
	hostIP := flag.String("host-ip", "", "host ip")
	hostPort := flag.Int("host-port", -1, "host port")
	proto := flag.String("proto", "tcp", "proxy protocol")
	flag.Parse()

	// use loopback IP as the child IP, when port-driver="builtin"
	childIP := "127.0.0.1"
	if isIPv6(*hostIP) {
		childIP = "::1"
	}

	cmd := exec.Command(realProxy,
		"-container-ip", *containerIP,
		"-container-port", strconv.Itoa(*containerPort),
		"-host-ip", childIP,
		"-host-port", strconv.Itoa(*hostPort),
		"-proto", *proto)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()
	cmd.ExtraFiles = append(cmd.ExtraFiles, f)
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Pdeathsig: syscall.SIGKILL,
	}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("error while starting %s: %w", realProxy, err)
	}

	sshFlags := []string{"-N", "-o", "StrictHostKeyChecking=no", "-p", diuidParentPort}
	sshFlags = append(sshFlags, fmt.Sprintf("-R%s:%d:0.0.0.0:%d", *hostIP, *hostPort, *hostPort))
	sshFlags = append(sshFlags, fmt.Sprintf("user@%s", diuidParentHost))
	sshCmd := exec.Command("ssh", sshFlags...)
	sshCmd.Env = os.Environ()
	sshCmd.SysProcAttr = &syscall.SysProcAttr{
		Pdeathsig: syscall.SIGKILL,
	}
	if err := sshCmd.Start(); err != nil {
		return fmt.Errorf("error while starting ssh %s:", err)
	}
	defer sshCmd.Process.Kill()
	log.Printf("Executing SSH command: %s", sshCmd.String())

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, os.Interrupt)
	<-ch
	if err := cmd.Process.Kill(); err != nil {
		return fmt.Errorf("error while killing %s: %w", realProxy, err)
	}
	return nil
}