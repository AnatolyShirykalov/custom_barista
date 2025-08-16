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
	"github.com/AnatolyShirykalov/custom_barista/ccusage"
	"github.com/AnatolyShirykalov/custom_barista/clipboard"
	"github.com/AnatolyShirykalov/custom_barista/dsk"
	"github.com/AnatolyShirykalov/custom_barista/kbdlayout"
	"github.com/AnatolyShirykalov/custom_barista/load"
	"github.com/AnatolyShirykalov/custom_barista/ltime"
	"github.com/AnatolyShirykalov/custom_barista/mem"
	"github.com/AnatolyShirykalov/custom_barista/netm"
	"github.com/AnatolyShirykalov/custom_barista/nvidia"
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

	// Input/Interface
	modules = append(modules, kbdlayout.Get())

	// CPU stats grouped together
	modules = append(modules, load.Get())
	modules = append(modules, temp.Module())

	// System resources
	modules = append(modules, mem.Get())

	// Storage
	modules = dsk.AddTo(modules)

	// GPU
	modules = append(modules, nvidia.Module())

	// Network
	modules = netm.AddTo(modules)

	// Power
	modules = append(modules, batt.Get())

	// Applications
	modules = append(modules, ccusage.Get())
	modules = append(modules, clipboard.Get())

	// Time (always last)
	modules = append(modules, ltime.Get())

	panic(barista.Run(modules...))
}
