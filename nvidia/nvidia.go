package nvidia

import (
	"bytes"
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

func readGpuStats() (temp, vramUsed, vramTotal int, err error) {
	cmd := exec.Command("nvidia-smi",
		"--query-gpu=temperature.gpu,memory.used,memory.total",
		"--format=csv,noheader,nounits")
	var out bytes.Buffer
	cmd.Stdout = &out
	err = cmd.Run()
	if err != nil {
		return
	}
	fields := strings.Split(strings.TrimSpace(out.String()), ", ")
	if len(fields) != 3 {
		err = exec.ErrNotFound
		return
	}
	temp, err = strconv.Atoi(fields[0])
	if err != nil {
		return
	}
	vramUsed, err = strconv.Atoi(fields[1])
	if err != nil {
		return
	}
	vramTotal, err = strconv.Atoi(fields[2])
	return
}

func (m *NvidiaModule) Stream(sink bar.Sink) {
	for range time.Tick(2 * time.Second) {
		temp, used, total, err := readGpuStats()
		if err != nil {
			sink.Output(outputs.Text("GPU ERR").Color(colors.Scheme("bad")))
			continue
		}
		// Compose output: temperature + VRAM usage
		out := outputs.Pango(
			pango.Icon("mdi-thermometer"), utils.Spacer,
			pango.Textf("%2d℃", temp), utils.Spacer,
			pango.Icon("mdi-memory"), utils.Spacer,
			pango.Textf("%d/%d MiB", used, total),
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
