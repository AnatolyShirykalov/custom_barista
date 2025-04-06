// Copyright 2017 Google Inc. Apache 2.0 License
// Modifications Copyright 2018 glebtv, Apache 2.0 License
// Based on sample-bar

package main

import (
	barista "barista.run"
	"barista.run/bar"
	"barista.run/colors"
	"barista.run/pango/icons/material"
	"barista.run/pango/icons/typicons"
	"github.com/AnatolyShirykalov/custom_barista/batt"
	"github.com/AnatolyShirykalov/custom_barista/dsk"
	"github.com/AnatolyShirykalov/custom_barista/kbdlayout"
	"github.com/AnatolyShirykalov/custom_barista/load"
	"github.com/AnatolyShirykalov/custom_barista/ltime"
	"github.com/AnatolyShirykalov/custom_barista/mem"
	"github.com/AnatolyShirykalov/custom_barista/netm"
	"github.com/AnatolyShirykalov/custom_barista/temp"
	"github.com/AnatolyShirykalov/custom_barista/utils"
)

func main() {
	material.Load(utils.Home(".fonts/material"))
	typicons.Load(utils.Home(".fonts/typicons"))

	colors.LoadFromMap(map[string]string{
		"good":     "#6d6",
		"degraded": "#dd6",
		"bad":      "#d66",
		"dim-icon": "#777",
	})

	modules := make([]bar.Module, 0)

	modules = append(modules, kbdlayout.Get())

	modules = dsk.AddTo(modules)

	modules = append(modules, load.Get())
	modules = append(modules, mem.Get())

	modules = netm.AddTo(modules)

	modules = append(modules, batt.Get())

	modules = append(modules, temp.Module())

	// pacin gsimplecal
	modules = append(modules, ltime.Get())

	panic(barista.Run(modules...))
}
