//go:build windows

package printer

import (
	"context"
	"fmt"
	"net"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/dynops/bcwms-print-agent/config"
)

// windowsBackend separates driver-rendered PDF jobs from raw warehouse data.
// PDF uses a configured non-interactive renderer; ZPL/ESC-POS/RAW use TCP 9100.
type windowsBackend struct {
	handle     string
	host       string
	port       int
	pdfCommand string
	pdfArgs    []string
}

func newBackend(cfg *config.Config) Backend {
	return &windowsBackend{
		handle:     cfg.PrinterHandle,
		host:       firstNonEmpty(cfg.RawAddress, cfg.PrinterHandle),
		port:       9100,
		pdfCommand: cfg.PDFCommand,
		pdfArgs:    append([]string(nil), cfg.PDFArgs...),
	}
}

func (b *windowsBackend) Print(format string, payload []byte, copies int) error {
	if strings.EqualFold(format, "PDF") {
		return b.printPDF(payload, copies)
	}
	return b.printRaw(payload, copies)
}

func (b *windowsBackend) printRaw(payload []byte, copies int) error {
	if b.host == "" {
		return fmt.Errorf("rawAddress or printerHandle (host[:port]) not set")
	}
	host, port := splitHostPort(b.host)
	if port == 0 {
		port = b.port
	}
	address := net.JoinHostPort(host, strconv.Itoa(port))
	if copies <= 0 {
		copies = 1
	}
	for i := 0; i < copies; i++ {
		conn, err := net.DialTimeout("tcp", address, 5*time.Second)
		if err != nil {
			return fmt.Errorf("dial %s: %w", address, err)
		}
		if err := conn.SetWriteDeadline(time.Now().Add(30 * time.Second)); err != nil {
			conn.Close()
			return fmt.Errorf("set write deadline: %w", err)
		}
		if _, err := conn.Write(payload); err != nil {
			conn.Close()
			return err
		}
		conn.Close()
	}
	return nil
}

func (b *windowsBackend) printPDF(payload []byte, copies int) error {
	if b.pdfCommand == "" {
		return fmt.Errorf("PDF printing on Windows requires pdfCommand/pdfArgs; raw TCP 9100 is only used for ZPL, ESC/POS and RAW")
	}
	if b.handle == "" {
		return fmt.Errorf("printerHandle (Windows printer name) not set")
	}
	if !containsPlaceholder(b.pdfArgs, "{file}") {
		return fmt.Errorf("pdfArgs must contain the {file} placeholder")
	}
	if !containsPlaceholder(b.pdfArgs, "{printer}") {
		return fmt.Errorf("pdfArgs must contain the {printer} placeholder")
	}
	if copies <= 0 {
		copies = 1
	}

	tempFile, err := os.CreateTemp("", "bcwms-print-*.pdf")
	if err != nil {
		return fmt.Errorf("create temporary PDF: %w", err)
	}
	tempPath := tempFile.Name()
	defer os.Remove(tempPath)
	if _, err := tempFile.Write(payload); err != nil {
		tempFile.Close()
		return fmt.Errorf("write temporary PDF: %w", err)
	}
	if err := tempFile.Close(); err != nil {
		return fmt.Errorf("close temporary PDF: %w", err)
	}

	for copyNo := 0; copyNo < copies; copyNo++ {
		args := expandPDFArgs(b.pdfArgs, tempPath, b.handle)
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		cmd := exec.CommandContext(ctx, b.pdfCommand, args...)
		out, runErr := cmd.CombinedOutput()
		cancel()
		if ctx.Err() == context.DeadlineExceeded {
			return fmt.Errorf("PDF print command timed out")
		}
		if runErr != nil {
			return fmt.Errorf("PDF print command failed: %v output=%s", runErr, string(out))
		}
	}
	return nil
}

func containsPlaceholder(args []string, placeholder string) bool {
	for _, arg := range args {
		if strings.Contains(arg, placeholder) {
			return true
		}
	}
	return false
}

func expandPDFArgs(args []string, filePath, printerName string) []string {
	expanded := make([]string, len(args))
	for i, arg := range args {
		arg = strings.ReplaceAll(arg, "{file}", filePath)
		arg = strings.ReplaceAll(arg, "{printer}", printerName)
		expanded[i] = arg
	}
	return expanded
}

func splitHostPort(handle string) (string, int) {
	if host, portText, err := net.SplitHostPort(handle); err == nil {
		port, parseErr := strconv.Atoi(portText)
		if parseErr == nil {
			return host, port
		}
	}
	if strings.HasPrefix(handle, "[") && strings.HasSuffix(handle, "]") {
		return strings.TrimSuffix(strings.TrimPrefix(handle, "["), "]"), 0
	}
	if strings.Count(handle, ":") > 1 {
		return handle, 0
	}
	parts := strings.SplitN(handle, ":", 2)
	if len(parts) == 2 {
		port, _ := strconv.Atoi(parts[1])
		return parts[0], port
	}
	return handle, 0
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}
