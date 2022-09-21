package main

import (
	"barista.run/bar"
	"github.com/AnatolyShirykalov/custom_barista/kbdlayout"
)

func main() {
	//layout := kbdlayout.New()
	layout := kbdlayout.Get()

	panic(bar.Run(
		layout,
	))
}
