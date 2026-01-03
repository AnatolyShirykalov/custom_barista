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

const (
	temp1Path = "/sys/class/hwmon/hwmon3/temp1_input"
	temp3Path = "/sys/class/hwmon/hwmon3/temp3_input"
	temp4Path = "/sys/class/hwmon/hwmon3/temp4_input"
)

type TempModule struct{}

func readTemp(path string) (int, error) {
	data, err := os.ReadFile(path)
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
		temp1, err1 := readTemp(temp1Path)
		temp3, err3 := readTemp(temp3Path)
		temp4, err4 := readTemp(temp4Path)

		if err1 != nil || err3 != nil || err4 != nil {
			sink.Output(outputs.Text("TEMP ERR").Color(colors.Scheme("bad")))
			continue
		}

		maxTemp := temp1
		if temp3 > maxTemp {
			maxTemp = temp3
		}
		if temp4 > maxTemp {
			maxTemp = temp4
		}

		out := outputs.Pango(
			pango.Icon("material-build"), utils.Spacer,
			pango.Textf("%2d %2d %2d℃", temp1, temp3, temp4),
		)
		switch {
		case maxTemp > 90:
			out.Urgent(true)
		case maxTemp > 70:
			out.Color(colors.Scheme("bad"))
		case maxTemp > 60:
			out.Color(colors.Scheme("degraded"))
		}
		sink.Output(out)
	}
}

func Module() bar.Module {
	return &TempModule{}
}
