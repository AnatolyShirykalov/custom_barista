package main

import (
	"fmt"

	"github.com/AnatolyShirykalov/custom_barista/kbdlayout"
)

func main() {
	layout, mods, err := kbdlayout.GetLayout()
	if err != nil {
		panic(err)
	}
	fmt.Println("layout:", layout, "mods:", mods)
	//kbdlayout.Switch(1)
	kbdlayout.SwitchToNext()
	kbdlayout.Subscribe(func(layout string, mods uint8) {
		fmt.Println("layout:", layout, "mods:", mods)
	})

	//select {}
}
