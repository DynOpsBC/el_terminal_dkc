//go:build darwin || linux

package printer

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"time"

	"github.com/dynops/bcwms-print-agent/config"
)

type unixBackend struct {
	handle string
}

func newBackend(cfg *config.Config) Backend {
	return &unixBackend{handle: cfg.PrinterHandle}
}

func (b *unixBackend) Print(format string, payload []byte, copies int) error {
	if b.handle == "" {
		return fmt.Errorf("printerHandle not set in config")
	}
	if copies <= 0 {
		copies = 1
	}
	args := []string{"-d", b.handle, "-n", strconv.Itoa(copies)}
	if format == "ZPL" || format == "RAW" || format == "ESCPOS" {
		args = append(args, "-o", "raw")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "lp", args...)
	cmd.Stdin = bytes.NewReader(payload)
	out, err := cmd.CombinedOutput()
	if ctx.Err() == context.DeadlineExceeded {
		return fmt.Errorf("lp command timed out")
	}
	if err != nil {
		return fmt.Errorf("lp failed: %v output=%s", err, string(out))
	}
	return nil
}
