package clipboard

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"barista.run/bar"
	"barista.run/base/click"
	"barista.run/colors"
	"barista.run/outputs"
)

type ClipboardModule struct{}

func getClipboardContent() (string, error) {
	cmd := exec.Command("xclip", "-o", "-selection", "clipboard")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(output), nil
}

func setClipboardContent(content string) error {
	cmd := exec.Command("xclip", "-selection", "clipboard")
	cmd.Stdin = strings.NewReader(content)
	return cmd.Run()
}

func (m *ClipboardModule) Stream(sink bar.Sink) {
	// Initial update
	m.updateClipboard(sink)

	// Update every 2 seconds
	for range time.Tick(2 * time.Second) {
		m.updateClipboard(sink)
	}
}

func (m *ClipboardModule) updateClipboard(sink bar.Sink) {
	content, err := getClipboardContent()
	if err != nil {
		sink.Output(outputs.Text("clip: error").Color(colors.Scheme("bad")))
		return
	}

	// Calculate size
	size := len(content)
	sizeStr := ""
	if size == 0 {
		sizeStr = "empty"
	} else if size < 1024 {
		sizeStr = fmt.Sprintf("%dB", size)
	} else if size < 1024*1024 {
		sizeStr = fmt.Sprintf("%.1fK", float64(size)/1024)
	} else {
		sizeStr = fmt.Sprintf("%.1fM", float64(size)/(1024*1024))
	}

	out := outputs.Text(fmt.Sprintf("📋 %s", sizeStr)).
		Color(colors.Scheme("good")).
		OnClick(click.RunLeft(`/home/anatoly/scripts/clipboard_menu.sh`))

	sink.Output(out)
}


func Get() bar.Module {
	return &ClipboardModule{}
}