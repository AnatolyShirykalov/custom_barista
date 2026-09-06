package temp

import (
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"barista.run/bar"
	"barista.run/colors"
	"barista.run/outputs"
	"barista.run/pango"
	"github.com/AnatolyShirykalov/custom_barista/utils"
)

// hwmon indices are not stable across boots or kernel upgrades, so the
// k10temp device is located by name instead of by a hardcoded path.
const hwmonName = "k10temp"

const (
	temp1File = "temp1_input"
	temp3File = "temp3_input"
	temp4File = "temp4_input"
)

type TempModule struct {
	dir string
}

func findHwmon(name string) (string, error) {
	dirs, err := filepath.Glob("/sys/class/hwmon/hwmon*")
	if err != nil {
		return "", err
	}
	for _, dir := range dirs {
		data, err := os.ReadFile(filepath.Join(dir, "name"))
		if err != nil {
			continue
		}
		if strings.TrimSpace(string(data)) == name {
			return dir, nil
		}
	}
	return "", errors.New("hwmon device not found: " + name)
}

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

// read resolves the hwmon directory lazily and re-resolves it whenever a read
// fails, so the module recovers if the device gets renumbered.
func (m *TempModule) read(file string) (int, error) {
	if m.dir == "" {
		dir, err := findHwmon(hwmonName)
		if err != nil {
			return 0, err
		}
		m.dir = dir
	}
	val, err := readTemp(filepath.Join(m.dir, file))
	if err != nil {
		m.dir = ""
	}
	return val, err
}

func (m *TempModule) Stream(sink bar.Sink) {
	for range time.Tick(2 * time.Second) {
		temp1, err1 := m.read(temp1File)
		temp3, err3 := m.read(temp3File)
		temp4, err4 := m.read(temp4File)

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
