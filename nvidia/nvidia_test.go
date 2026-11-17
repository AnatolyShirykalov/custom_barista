package nvidia

import "testing"

func TestParseGpuStats(t *testing.T) {
	cases := []struct {
		in         string
		temp, vram int
		wantErr    bool
	}{
		{"34.82, 462\n", 35, 462, false},
		{"39.70, 1024.0", 40, 1024, false},
		{"41, 500\n", 41, 500, false},
		{"  41 ,  500  ", 41, 500, false},
		{"[N/A], 500", 0, 0, true},
		{"41, [N/A]", 0, 0, true},
		{"41", 0, 0, true},
		{"", 0, 0, true},
	}
	for _, c := range cases {
		temp, vram, err := parseGpuStats(c.in)
		if (err != nil) != c.wantErr || temp != c.temp || vram != c.vram {
			t.Errorf("%q: got %d,%d,%v want %d,%d,err=%v", c.in, temp, vram, err, c.temp, c.vram, c.wantErr)
		}
	}
}
