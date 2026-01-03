package freq

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"barista.run/bar"
	"barista.run/outputs"
	"barista.run/pango"
	"github.com/AnatolyShirykalov/custom_barista/utils"
	"github.com/lucasb-eyer/go-colorful"
)

type FreqModule struct {
	numCPUs int
}

// Color gradients from cold (blue) to warm (red)
var freqColors = []string{
	"#4a9eff", // 1 GHz - blue
	"#5bc0de", // 2 GHz - light blue
	"#5cb85c", // 3 GHz - green
	"#f0ad4e", // 4 GHz - orange
	"#ff8c42", // 5 GHz - orange-red
	"#d9534f", // 6 GHz - red
}

func readCPUFreq(cpuNum int) (int, error) {
	path := fmt.Sprintf("/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq", cpuNum)
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	raw := strings.TrimSpace(string(data))
	val, err := strconv.Atoi(raw)
	if err != nil {
		return 0, err
	}
	// Convert kHz to GHz and round
	return (val + 500000) / 1000000, nil
}

func (m *FreqModule) Stream(sink bar.Sink) {
	for range time.Tick(2 * time.Second) {
		freqMap := make(map[int]int)
		maxFreq := 0

		for i := 0; i < m.numCPUs; i++ {
			freq, err := readCPUFreq(i)
			if err != nil {
				continue
			}
			freqMap[freq]++
			if freq > maxFreq {
				maxFreq = freq
			}
		}

		if len(freqMap) == 0 {
			sink.Output(outputs.Text("FREQ ERR"))
			continue
		}

		// Determine how many frequency levels to show (minimum 6, expand if needed)
		numLevels := 6
		if maxFreq > 6 {
			numLevels = maxFreq
		}

		// Build colored output
		var parts []interface{}
		parts = append(parts, pango.Icon("material-flash-on"), utils.Spacer)

		// Count how many 2-digit numbers we have to calculate padding
		twoDigitCount := 0
		for freq := 1; freq <= numLevels; freq++ {
			count := freqMap[freq]
			if count >= 10 {
				twoDigitCount++
			}
		}

		// Add padding spaces to keep fixed width (max is 6 two-digit numbers)
		maxTwoDigits := numLevels
		if maxTwoDigits > 6 {
			maxTwoDigits = 6 // reasonable max
		}
		paddingSpaces := maxTwoDigits - twoDigitCount
		for i := 0; i < paddingSpaces; i++ {
			parts = append(parts, pango.Text(" "))
		}

		for freq := 1; freq <= numLevels; freq++ {
			count := freqMap[freq]
			colorIdx := freq - 1

			// Use existing colors for 1-6 GHz, extend with red for higher
			colorHex := "#ff0000" // default red for 7+ GHz
			if colorIdx < len(freqColors) {
				colorHex = freqColors[colorIdx]
			}

			color, _ := colorful.Hex(colorHex)
			parts = append(parts, pango.Text(fmt.Sprintf("%d", count)).Color(color))
			if freq < numLevels {
				parts = append(parts, pango.Text(" "))
			}
		}

		out := outputs.Pango(parts...)
		sink.Output(out)
	}
}

func Module(numCPUs int) bar.Module {
	return &FreqModule{numCPUs: numCPUs}
}
