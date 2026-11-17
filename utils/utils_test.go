package utils

import (
	"path/filepath"
	"testing"
)

func TestScript(t *testing.T) {
	t.Setenv("HOME", "/home/x")
	if got, want := Script("a.sh"), filepath.Join("/home/x", "scripts", "a.sh"); got != want {
		t.Errorf("got %q, want %q", got, want)
	}
	t.Setenv("HOME", "")
	if got, want := Script("a.sh"), filepath.Join("scripts", "a.sh"); got != want {
		t.Errorf("fallback got %q, want %q", got, want)
	}
}
