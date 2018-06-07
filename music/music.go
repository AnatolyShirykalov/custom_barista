package music

import (
	"fmt"
	"time"

	"github.com/glebtv/custom_barista/utils"
	"github.com/soumya92/barista/bar"
	"github.com/soumya92/barista/colors"
	"github.com/soumya92/barista/modules/media"
	"github.com/soumya92/barista/outputs"
	"github.com/soumya92/barista/pango"
	"github.com/soumya92/barista/pango/icons/fontawesome"
)

func truncate(in string, l int) string {
	if len([]rune(in)) <= l {
		return in
	}
	return string([]rune(in)[:l-1]) + "⋯"
}

func hms(d time.Duration) (h int, m int, s int) {
	h = int(d.Hours())
	m = int(d.Minutes()) % 60
	s = int(d.Seconds()) % 60
	return
}

func formatMediaTime(d time.Duration) string {
	h, m, s := hms(d)
	if h > 0 {
		return fmt.Sprintf("%d:%02d:%02d", h, m, s)
	}
	return fmt.Sprintf("%d:%02d", m, s)
}

func mediaFormatFunc(m media.Info) bar.Output {
	if m.PlaybackStatus == media.Stopped || m.PlaybackStatus == media.Disconnected {
		return outputs.Empty()
	}
	artist := truncate(m.Artist, 20)
	title := truncate(m.Title, 40-len(artist))
	if len(title) < 20 {
		artist = truncate(m.Artist, 40-len(title))
	}
	var iconAndPosition pango.Node
	if m.PlaybackStatus == media.Playing {
		iconAndPosition = pango.Span(
			colors.Hex("#f70"),
			fontawesome.Icon("music"),
			utils.Spacer,
			formatMediaTime(m.Position()),
			"/",
			formatMediaTime(m.Length),
		)
	} else {
		iconAndPosition = fontawesome.Icon("music", pango.Color(colors.Hex("#f70"))...)
	}
	return outputs.Pango(iconAndPosition, utils.Spacer, title, " - ", artist)
}

func Get(player string) bar.Module {
	// You need to know your dbus\mrpis player name
	// find your player name via playerctl -l
	// https://github.com/acrisci/playerctl
	// for deadbeef use this plugin:
	// https://aur.archlinux.org/packages/deadbeef-mpris2-plugin/
	return media.New(player).OutputFunc(mediaFormatFunc)
}
