package vol

import (
	"barista.run/bar"
	"barista.run/colors"
	"barista.run/modules/volume"
	"barista.run/modules/volume/alsa"
	"barista.run/outputs"
	"barista.run/pango"
	"github.com/AnatolyShirykalov/custom_barista/utils"
)

func Get() *volume.Module {
	return volume.New(alsa.DefaultMixer()).Output(func(v volume.Volume) bar.Output {
		if v.Mute {
			return outputs.
				Pango(pango.Icon("ion-volume-off"), "MUT").
				Color(colors.Scheme("degraded"))
		}
		iconName := "mute"
		pct := v.Pct()
		if pct > 66 {
			iconName = "high"
		} else if pct > 33 {
			iconName = "low"
		}
		return outputs.Pango(
			pango.Icon("ion-volume-"+iconName),
			utils.Spacer,
			pango.Textf("%2d%%", pct),
		)
	})
}
