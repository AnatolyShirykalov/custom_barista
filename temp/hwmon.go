package temp

import (
	"os"
	"strconv"
	"strings"
	"time"

	"barista.run/bar"
	"barista.run/colors"
	"barista.run/outputs"
	"barista.run/pango"
	"github.com/AnatolyShirykalov/custom_barista/utils"
)

const tempPath = "/sys/class/hwmon/hwmon1/temp1_input"

type TempModule struct{}

func readTemp() (int, error) {
	data, err := os.ReadFile(tempPath)
	if err != nil {
		return 0, err
	}
	raw := strings.TrimSpace(string(data))
	val, err := strconv.Atoi(raw)
	if err != nil {
		return 0, err
	}
	return val / 1000, nil
}

func (m *TempModule) Stream(sink bar.Sink) {
	for range time.Tick(2 * time.Second) {
		temp, err := readTemp()
		if err != nil {
			sink.Output(outputs.Text("TEMP ERR").Color(colors.Scheme("bad")))
			continue
		}
		out := outputs.Pango(
			pango.Icon("material-build"), utils.Spacer,
			pango.Textf("%2d℃", temp),
		)
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

func Module() bar.Module {
	return &TempModule{}
}
