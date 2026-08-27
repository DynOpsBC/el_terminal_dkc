//go:build windows

package printer

import "testing"

func TestExpandPDFArgs(t *testing.T) {
	got := expandPDFArgs(
		[]string{"-print-to", "{printer}", "-silent", "{file}"},
		`C:\\Temp\\job.pdf`,
		`Warehouse A4`,
	)
	want := []string{"-print-to", "Warehouse A4", "-silent", `C:\\Temp\\job.pdf`}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("arg %d = %q, want %q", i, got[i], want[i])
		}
	}
}

func TestSplitHostPortSupportsIPv6(t *testing.T) {
	host, port := splitHostPort(`[2001:db8::10]:9100`)
	if host != `2001:db8::10` || port != 9100 {
		t.Fatalf("splitHostPort = %q,%d", host, port)
	}
}
