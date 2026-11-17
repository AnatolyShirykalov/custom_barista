package nvidia

import (
	"fmt"
	"math"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"barista.run/bar"
	"barista.run/colors"
	"barista.run/outputs"
	"barista.run/pango"
	"github.com/AnatolyShirykalov/custom_barista/utils"
)

type NvidiaModule struct{}

func Module() bar.Module {
	return &NvidiaModule{}
}

// parseGpuStats parses one csv line "temp, vram" (values may be int, float
// or "[N/A]"); a field that is not a number is an error. With several GPUs
// nvidia-smi prints one line each; only the first is used.
func parseGpuStats(out string) (temp, vramUsed int, err error) {
	line, _, _ := strings.Cut(strings.TrimSpace(out), "\n")
	fields := strings.Split(line, ",")
	if len(fields) != 2 {
		return 0, 0, fmt.Errorf("want 2 fields, got %d", len(fields))
	}
	var vals [2]int
	for i, f := range fields {
		v, perr := strconv.ParseFloat(strings.TrimSpace(f), 64)
		if perr != nil {
			return 0, 0, perr
		}
		vals[i] = int(math.Round(v))
	}
	return vals[0], vals[1], nil
}

func readGpuStats() (temp, vramUsed int, err error) {
	out, err := exec.Command("nvidia-smi",
		"--query-gpu=temperature.gpu,memory.used",
		"--format=csv,noheader,nounits").Output()
	if err != nil {
		return
	}
	return parseGpuStats(string(out))
}

func (m *NvidiaModule) Stream(sink bar.Sink) {
	for range time.Tick(2 * time.Second) {
		temp, used, err := readGpuStats()
		if err != nil {
			reason := "GPU parse"
			if _, ok := err.(*exec.Error); ok {
				reason = "GPU n/a"
			} else if _, ok := err.(*exec.ExitError); ok {
				reason = "GPU smi"
			}
			sink.Output(outputs.Text(reason).Color(colors.Scheme("dim-icon")))
			continue
		}
		// Compose output: temperature + VRAM usage
		out := outputs.Pango(
			pango.Icon("mdi-thermometer"), utils.Spacer,
			pango.Textf("%2d℃", temp), utils.Spacer,
			pango.Icon("mdi-memory"), utils.Spacer,
			pango.Textf("%d MiB", used),
		)

		// Color based on temperature
		switch {
		case temp > 90:
			out.Urgent(true)
		case temp > 70:
			out.Color(colors.Scheme("bad"))
		case temp > 60:
			out.Color(colors.Scheme("degraded"))
		}
		sink.Output(out)
	}
}
