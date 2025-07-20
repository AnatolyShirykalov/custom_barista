package main

import (
	"barista.run"
	"github.com/AnatolyShirykalov/custom_barista/kbdlayout"
)

func main() {
	//layout := kbdlayout.New()
	layout := kbdlayout.Get()

	panic(barista.Run(
		layout,
	))
}
