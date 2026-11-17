package utils

import (
	"os"
	"os/user"
	"path/filepath"

	"barista.run/pango"
)

var Spacer = pango.Text(" ")

func Home(path string) string {
	usr, err := user.Current()
	if err != nil {
		panic(err)
	}
	return filepath.Join(usr.HomeDir, path)
}

// Script returns the path of a helper script in ~/scripts; without a
// resolvable home dir it falls back to a relative path instead of panicking.
func Script(name string) string {
	home, err := os.UserHomeDir()
	if err != nil {
		return filepath.Join("scripts", name)
	}
	return filepath.Join(home, "scripts", name)
}
