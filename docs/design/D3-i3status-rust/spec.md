# D3: i3status-rust trial bar, spec

Status: spec (bar-designer, 2026-11-17). Builder item: roadmap "D3 build trial bar". Reviewer: "D3 review".
Decision page (3 questions, local only): `docs/design/D3-i3status-rust/questions.html`. Defaults below are the recommended answers. If the user picks another option, apply the matching "If the user picks B/C" line. Nothing else changes.

User decision (2026-11-17): trial i3status-rust as a second bar for about a week, then switch. Main pain: icons are not specific enough, and the GPU widget had no icon. Icon specificity is the top criterion, so every block below names its exact glyph.

## 0. Facts checked (2026-11-17)

| Fact | Evidence |
|---|---|
| i3status-rust is **not installed**. Arch has `extra/i3status-rust 0.40.1-2` (deps libpipewire, libpulse, lm_sensors). | `i3status-rs` not found; `pacman -Si` |
| **No Nerd Font installed.** `~/.fonts` has only material, typicons, PragmataPro, win. Package to use: `extra/ttf-nerd-fonts-symbols-mono 3.5.1` (monospace cells keep widths stable). | `fc-list \| grep -i nerd` empty |
| All codepoints below come from Nerd Fonts `glyphnames.json` (v3.4.0). The md range has been stable since v3.0. Glyphs were rendered with Symbols Nerd Font Mono plus PragmataPro Mono 18: no tofu (`img/proposed.png`). | scratch render |
| The default `material-nf` icon for `gpu` is `md-monitor` U+F0379. That is vague (it reads as "display"), so we override it. There is no `md-gpu` glyph. | `files/icons/material-nf.toml` v0.40.1 |
| Today, the GPU and volume icons are blank (`mdi-*` and `ion-*` providers are never loaded), and the **disk IO widget is missing**: barista asks diskio for `cryptroot`, but the root fs is `/dev/mapper/cryptroot` = `dm-0`. | screenshot `img/today.png`, `findmnt`, `/proc/diskstats` |
| The `ccusage` cost per run is about 2 CPU-seconds (`npx -y ccusage@20.0.51 …`: 1.29 s user + 0.68 s sys). At a 5 s interval that is about 0.4 of a core all the time. At 60 s it is about 0.03. | `time` run |
| Machine: 32 logical CPUs, 92 GiB RAM (MemTotal 96429832 kB), no battery (`/sys/class/power_supply` empty), k10temp inputs Tctl/Tccd1/Tccd2, NICs `eno1` and `wlp5s0`. Layouts `us,ru` with `grp:caps_toggle`. `xdotool` is present, `xkb-switch` is not. | system |
| The current bar is `bar-0` in `~/.i3/config` (lines 223-229): bottom, `mode hide`, `modifier Mod3`. Bar font `pango:PragmataPro 18`. | `~/.i3/config` |
| Click scripts in barista point to `/home/anatolii/scripts/…`, which is wrong (the user is `anatoly`). The real paths are `~/scripts/clipboard_menu.sh` and `~/scripts/open_calender.sh`. | `ls` |

## 1. Options for the overall approach

| | Option | Verdict |
|---|---|---|
| **A** | Built-in blocks wherever one exists, `custom` + small scripts only for freq histogram, ccusage, clipboard. Theme `native` with our 4 colors. | **Recommended.** Least code to own; built-ins survive upgrades (the A1 finding). |
| B | Port every widget as a `custom` script (full control of pango per segment, keeps per-layout red, 3 temps, urgent). | Against: recreates the maintenance load we are leaving; ~10 scripts forking every 2 s. |
| C | Built-ins only, drop freq histogram / ccusage / clipboard. | Against: loses widgets the user built and uses (ccusage, clipboard menu). |

## 2. Prerequisites (user step, needs sudo)

```
sudo pacman -S i3status-rust ttf-nerd-fonts-symbols-mono
fc-cache -f
```
The builder cannot run sudo. If `i3status-rs --version` fails, the builder stops and reports this line as a user step.

## 3. File layout

```
i3status-rust/config.toml          # section 6, verbatim
i3status-rust/scripts/freq.sh      # section 5.1
i3status-rust/scripts/ccusage.sh   # section 5.2
i3status-rust/scripts/clip.sh      # section 5.3
i3status-rust/scripts/test.sh      # runs the test table (section 8) against testdata/
i3status-rust/scripts/testdata/    # fixtures
```
No symlink: i3 passes the repo path explicitly. Scripts are `#!/usr/bin/env bash`, `set -u`, executable, and use only bash, awk, jq, xclip, timeout and npx.

## 4. Block map (main.go order is kept)

Colors map from `colors.Scheme` in main.go to i3status-rust states: **Idle** = normal text `#ffffff`; **Info** = `dim-icon` `#777777`; **Good** = `good` `#66dd66`; **Warning** = `degraded` `#dddd66`; **Critical** = `bad` `#dd6666`. Barista's "urgent" (red background) has no separate state and merges into Critical (see section 7).

| # | barista | i3status-rust block | Icon (name, codepoint) | Format → example | Interval | Thresholds → state | Click / scroll |
|---|---|---|---|---|---|---|---|
| 1 | kbdlayout | `keyboard_layout`, driver `xkbevent` | md-keyboard U+F030C (`keyboard`, default) | ` ^icon_keyboard $layout ` → `⌨ US` | event | none (always Idle) | left: `xdotool key ISO_Next_Group` |
| 2 | load | `load` | **md-gauge U+F029A** (override `cogs`, per block) | ` $icon $1m.eng(w:4) $15m.eng(w:4) ` → `2.15 1.27` | 3 | per-core 1m: info 0.25, warning 0.25, critical 0.5 (= 8 / 16 of 32 cores, as in barista) | none |
| 3 | temp (k10temp) | `temperature`, chip `k10temp-*`, inputs Tctl, Tccd1, Tccd2 | md-thermometer_low/-/high U+F10C3/U+F050F/U+F10C2 (default progression) | ` $icon $max ` → `68°` | 2 | good 0, idle 60, info 60, warning 70: ≤60 Idle, ≤70 Warning, >70 Critical | left: next_format (`format_alt` = ` $icon $min $average $max `) |
| 4 | freq | `custom` → `freq.sh`, json | **md-flash U+F0241** (new icon name `cpu_freq`) | histogram, pango → `22 0 4 3 2 1` | 2 | script sets Idle; per-bucket colors as in barista | none |
| 5 | mem | `memory` | md-memory U+F035B (`memory_mem`, default) | ` $icon $mem_avail.eng(prefix:Gi,w:3) ` → `84GiB` | 3 | warning_mem 97.8, critical_mem 98.9 (used % = avail < 2 GiB / < 1 GiB of 92 GiB) | none |
| 6a | dsk space | `disk_space`, path `/` | md-harddisk U+F02CA (`disk_drive`, default) | ` $icon $available.eng(prefix:G,w:3) ` → `582GB` | 20 | info_type available, alert_unit `GB`, warning 100, alert 30 | none |
| 6b | dsk io (broken today) | `disk_iostats`, device `dm-0` | **md-swap_vertical U+F04E2** (per-block override of `disk_drive`) | ` $icon $speed_read.eng(prefix:K,w:4) $speed_write.eng(prefix:K,w:4) ` | 2 | Idle | none |
| 7 | nvidia | `nvidia_gpu`, gpu_id 0 | **md-expansion_card U+F08AE** (per-block override of `gpu`) | ` $icon $temperature $vram_used.eng(prefix:Mi,w:4) ` → `36° 568MiB` | 2 | idle 60, good 60, info 60, warning 70: ≤60 Idle, ≤70 Warning, >70 Critical | defaults (left on VRAM toggles used/total) |
| 8a | netm en* | `net`, device `^en` | md-ethernet U+F0200; up/down md-upload U+F0552 / md-download U+F01DA (defaults) | ` $icon ^icon_net_up $speed_up.eng(prefix:K,w:4) ^icon_net_down $speed_down.eng(prefix:K,w:4) $ip ` | 2 | inactive_format ` $icon down `, missing_format `""` | none |
| 8b | netm wl* | `net`, device `^wl` | net_wireless progression (default md-wifi_strength_*) | ` $icon $ssid $signal_strength ^icon_net_up $speed_up.eng(prefix:K,w:4) ^icon_net_down $speed_down.eng(prefix:K,w:4) ` | 2 | inactive_format `""`, missing_format `""` (hidden unless connected) | none |
| 9 | batt | `battery` | `bat` progression (default) | ` $icon $percentage ` | 60 | defaults; missing_format `""` (desktop: hidden) | none |
| 10 | vol | `sound`, driver `auto` | volume progression md-volume_low/medium/high U+F057F/U+F0580/U+F057E; muted md-volume_mute U+F075F (defaults) | ` $icon {$volume.eng(w:3)\|MUT} ` → `70%` / `MUT` | event | muted = Warning (block built-in) | left: `pavucontrol`; right: toggle mute (default); wheel: ±5 % (default), `max_vol = 100` |
| 11 | ccusage | `custom` → `ccusage.sh`, json, `hide_when_empty` | **md-creation U+F0674** (sparkles, new name `ccusage`) | `53% 53.3M CH 96% 1h46m` | **60** (was 5) | % > 90 Critical, > 70 Warning, else Good | left: refresh (`update = true`) |
| 12 | clipboard | `custom` → `clip.sh`, json | **md-clipboard_text_outline U+F0A38** (new name `clipboard`) | `78B` / `img` / `empty` | **5** (was 2) | empty = Info (dim), else Idle | left: `~/scripts/clipboard_menu.sh` + `update = true` |
| 13 | ltime | `time` | md-calendar U+F00ED + md-clock_outline U+F0150, both dim via `icons_format` | ` ^icon_calendar $timestamp.datetime(f:'%a %Y-%m-%d') ^icon_time $timestamp.datetime(f:'%H:%M:%S') ` | 1 | Idle | left: `~/scripts/open_calender.sh` |

All icons are now different from each other. The GPU (expansion card) cannot be mistaken for RAM (md-memory, a chip), and disk IO cannot be mistaken for disk space.

## 5. Custom block scripts (I/O contract)

Every script prints exactly one JSON object `{"icon": "...", "state": "...", "text": "..."}` on stdout and exits 0, even on error. Errors become `state: "Critical"` with a short text, so the block never shows i3status-rust's own error box.

### 5.1 freq.sh (parity with freq/freq.go)
- Arg 1 (optional, for tests): the cpu sysfs root, default `/sys/devices/system/cpu`. The script reads `cpu[0-9]*/cpufreq/scaling_cur_freq` (kHz) in **one** `awk` call.
- bucket = (kHz + 500000) / 1000000, integer division. Bucket 0 is ignored. L = max(6, highest bucket).
- twoDigit = number of buckets 1..L with a count ≥ 10. The output starts with `min(L,6) - twoDigit` spaces (keeps the width fixed), then the counts for buckets 1..L, joined by single spaces. Each count is wrapped as `<span color='C'>n</span>`, where C for buckets 1..6 is `#4a9eff #5bc0de #5cb85c #f0ad4e #ff8c42 #d9534f`, and `#ff0000` above 6.
- Output: `{"icon":"cpu_freq","state":"Idle","text":"<pango>"}`. If no file is readable: `{"icon":"cpu_freq","state":"Critical","text":"FREQ ERR"}`.

### 5.2 ccusage.sh (fixes the barista waste)
- Command: `timeout 30 npx -y ccusage@20.0.51 blocks --active --token-limit max --json`. The version is **pinned** (no `@latest`, no npm fetch each run). The 60 s interval in the config cuts the cost about 12 times. Env `CCUSAGE_JSON=<file>` (tests) reads the file instead of running npx.
- Take the first block with `isActive && !isGap`. If there is none, or totalTokens and projection.totalTokens are both 0: print `{"text":""}`, and `hide_when_empty` hides the block.
- Text parts are joined by single spaces and empty parts are skipped:
  1. pct = totalTokens / tokenLimitStatus.limit × 100, only if limit > 0 (`null` is common). Below 1: `%.1f%%`, otherwise `%.0f%%`.
  2. tokens: ≥1e6 `%.1fM`, ≥1e3 `%.1fK`, else the integer.
  3. `CH %.0f%%` = cacheRead / (input + cacheCreation + cacheRead) × 100, if the denominator is > 0 and the result is > 0.
  4. projection.remainingMinutes > 0: `XhYm` if hours > 0, else `Ym`.
- state: pct > 90 Critical, pct > 70 Warning, else Good. `icon: "ccusage"`.
- npx fails, times out or prints bad JSON: `{"icon":"ccusage","state":"Critical","text":"cc err"}`.

### 5.3 clip.sh (cheap check)
- First `xclip -o -selection clipboard -t TARGETS` (lists the types only, does not transfer the data).
  - Fails or is empty: `{"icon":"clipboard","state":"Info","text":"empty"}`.
  - Any target matches `^image/`: `{"icon":"clipboard","state":"Idle","text":"img"}`. **The data is not read.**
  - Otherwise: n = `xclip -o -selection clipboard | head -c 1048577 | wc -c` (capped at 1 MiB + 1). Text: n = 0 → `empty` (Info); n < 1024 → `nB`; n < 1048576 → `%.1fK`; n > 1048576 → `>1M`. State Idle.
- Env `CLIP_TARGETS` / `CLIP_DATA` (tests) replace the two xclip calls.

## 6. config.toml (verbatim; the builder pastes this)

```toml
# i3status-rust 0.40.x, trial bar for D3. Spec: docs/design/D3-i3status-rust/spec.md
[theme]
theme = "native"
[theme.overrides]
idle_fg = "#ffffff"
info_fg = "#777777"      # dim-icon
good_fg = "#66dd66"      # good
warning_fg = "#dddd66"   # degraded
critical_fg = "#dd6666"  # bad

[icons]
icons = "material-nf"
[icons.overrides]
cpu_freq = "\U000F0241"   # md-flash
ccusage = "\U000F0674"    # md-creation
clipboard = "\U000F0A38"  # md-clipboard_text_outline

[[block]]
block = "keyboard_layout"
driver = "xkbevent"
format = " ^icon_keyboard $layout "
[[block.click]]
button = "left"
cmd = "xdotool key ISO_Next_Group"

[[block]]
block = "load"
format = " $icon $1m.eng(w:4) $15m.eng(w:4) "
interval = 3
info = 0.25
warning = 0.25
critical = 0.5
[block.icons_overrides]
cogs = "\U000F029A"       # md-gauge

[[block]]
block = "temperature"
chip = "k10temp-*"
inputs = ["Tctl", "Tccd1", "Tccd2"]
format = " $icon $max "
format_alt = " $icon $min $average $max "
interval = 2
good = 0
idle = 60
info = 60
warning = 70

[[block]]
block = "custom"
command = "~/projects/custom_barista/i3status-rust/scripts/freq.sh"
json = true
interval = 2

[[block]]
block = "memory"
format = " $icon $mem_avail.eng(prefix:Gi,w:3) "
interval = 3
warning_mem = 97.8
critical_mem = 98.9

[[block]]
block = "disk_space"
path = "/"
format = " $icon $available.eng(prefix:G,w:3) "
info_type = "available"
alert_unit = "GB"
warning = 100.0
alert = 30.0
interval = 20

[[block]]
block = "disk_iostats"
device = "dm-0"
format = " $icon $speed_read.eng(prefix:K,w:4) $speed_write.eng(prefix:K,w:4) "
interval = 2
[block.icons_overrides]
disk_drive = "\U000F04E2" # md-swap_vertical

[[block]]
block = "nvidia_gpu"
gpu_id = 0
format = " $icon $temperature $vram_used.eng(prefix:Mi,w:4) "
interval = 2
idle = 60
good = 60
info = 60
warning = 70
[block.icons_overrides]
gpu = "\U000F08AE"        # md-expansion_card (Q1 answer A)

[[block]]
block = "net"
device = "^en"
format = " $icon ^icon_net_up $speed_up.eng(prefix:K,w:4) ^icon_net_down $speed_down.eng(prefix:K,w:4) $ip "
inactive_format = " $icon down "
missing_format = ""
interval = 2

[[block]]
block = "net"
device = "^wl"
format = " $icon $ssid $signal_strength ^icon_net_up $speed_up.eng(prefix:K,w:4) ^icon_net_down $speed_down.eng(prefix:K,w:4) "
inactive_format = ""
missing_format = ""
interval = 2

[[block]]
block = "battery"
format = " $icon $percentage "
missing_format = ""
interval = 60

[[block]]
block = "sound"
driver = "auto"
format = " $icon {$volume.eng(w:3)|MUT} "
max_vol = 100
[[block.click]]
button = "left"
cmd = "pavucontrol"

[[block]]
block = "custom"
command = "~/projects/custom_barista/i3status-rust/scripts/ccusage.sh"
json = true
interval = 60
hide_when_empty = true
[[block.click]]
button = "left"
update = true

[[block]]
block = "custom"
command = "~/projects/custom_barista/i3status-rust/scripts/clip.sh"
json = true
interval = 5
[[block.click]]
button = "left"
cmd = "~/scripts/clipboard_menu.sh"
update = true

[[block]]
block = "time"
format = " ^icon_calendar $timestamp.datetime(f:'%a %Y-%m-%d') ^icon_time $timestamp.datetime(f:'%H:%M:%S') "
interval = 1
icons_format = "<span color='#777777'>{icon}</span>"
[[block.click]]
button = "left"
cmd = "~/scripts/open_calender.sh"
```

Fixed fallbacks (the builder applies them only if the check in section 9 fails; no other changes):
- F1: `$layout` is not `us`/`ru` (for example "English (US)"). Add `[block.mappings]` that maps exactly the strings shown to `"US"` and `"RU"`.
- F2: `icons_format` markup shows as literal text. Delete that line (the icons are then white).
- F3: the left click on the layout does not switch. Replace the cmd with `xdotool key Caps_Lock` (`grp:caps_toggle`).
- F4: `disk_iostats` shows `×` for `dm-0`. Use `device = "nvme0n1"` and report it.

### Answers other than the recommended ones (questions.html)
- Q1 = B: `gpu = "\U000F0FB2"` (md-expansion_card_variant). Q1 = C: `gpu = "\U000F061A"` (md-chip).
- Q2 = B: replace the freq custom block with `block = "cpu"`, `format = " ^icon_cpu_freq $frequency.eng(w:4) "`, `interval = 2`, `info_cpu = 101`, `warning_cpu = 101`, `critical_cpu = 101` (always Idle). Do not write freq.sh.
- Q3 = B: after the clipboard block add `block = "music"`, `format = " $icon {$combo.str(max_w:25,rot_interval:0.5) $play |}"`, `[[block.click]] button = "left" action = "play_pause"`. Q3 = C: also add `block = "weather"`, `format = " $icon $temp "`, `autolocate = true`, `interval = 900`, `[block.service] name = "metno"` (no API key).

## 7. Known differences from barista (accepted; the reviewer does not flag them)

| Barista today | Trial bar | Why accepted |
|---|---|---|
| urgent (red background) for temp > 90, load > 32, mem < 0.5 G | merges into Critical (red text) | i3status-rust has 5 states; we keep 3 accents plus dim |
| layout red when not US; CAPS shown | always Idle; no CAPS | Caps is the layout toggle key here; a custom block just for the color is not worth a script |
| temp shows Tctl, Tccd1, Tccd2 | shows max; click shows min/avg/max | coloring was already by the max |
| load colored on 1m **or** 15m | 1m only | block limit |
| mem green when > 12 GiB free | Idle | with 92 GiB it was always green, so it carried no information |
| clipboard green | Idle (white); dim when empty | green is reserved for "good" |
| disk space shows used (1243 GB) | shows **available** (582 GB) with warnings | the free space is what you act on |
| wifi shown when the link is admin-up but has no carrier | hidden unless connected | removes the noise "wlp5s0 UP 0 B/s" |
| disk IO missing (bug) | shown | fixed |

## 8. Test table (`scripts/test.sh`; plain text after stripping `<span…>` tags)

| # | Script | Input | Expected text | state |
|---|---|---|---|---|
| 1 | freq | 4 cpus: 1400000, 3600000, 3600000, 5100000 | `      1 0 0 2 1 0` (6 leading spaces) | Idle |
| 2 | freq | 12 cpus at 2000000 | `     0 12 0 0 0 0` (5 leading spaces) | Idle |
| 3 | freq | 1 cpu at 7200000 | `      0 0 0 0 0 0 1`; last span `#ff0000` | Idle |
| 4 | freq | empty dir | `FREQ ERR` | Critical |
| 5 | ccusage | active, total 53258416, limit null, input 1000 / cacheCreation 3000 / cacheRead 96000, remaining 106 | `53.3M CH 96% 1h46m` | Good |
| 6 | ccusage | as #5, limit 100000000 | `53% 53.3M CH 96% 1h46m` | Good |
| 7 | ccusage | as #5, limit 60000000 | `89% 53.3M CH 96% 1h46m` | Warning |
| 8 | ccusage | as #5, limit 55000000, remaining 40 | `97% 53.3M CH 96% 40m` | Critical |
| 9 | ccusage | `{"blocks":[]}` | `` (empty) | (any) |
| 10 | ccusage | invalid JSON | `cc err` | Critical |
| 11 | clip | TARGETS empty | `empty` | Info |
| 12 | clip | TARGETS `UTF8_STRING`, data `hello` | `5B` | Idle |
| 13 | clip | TARGETS `UTF8_STRING`, 2048 bytes | `2.0K` | Idle |
| 14 | clip | TARGETS `TARGETS\nimage/png`, CLIP_DATA unset | `img`, and the data command is never run | Idle |
| 15 | clip | 2 MiB of data | `>1M` | Idle |

All outputs must pass `jq -e .` (valid JSON).

## 9. i3 config snippet (second trial bar)

Insert into `~/.i3/config` right after the existing `bar { … }` (ends at line 229). Do not touch `bar-0`. Both bars appear while Mod3 is held: barista at the bottom, the trial bar at the top, for a side-by-side comparison.
```
bar {
  id bar-rs
  position top
  hidden_state hide
  mode hide
  modifier Mod3
  font pango:PragmataPro Mono, Symbols Nerd Font Mono 18
  status_command i3status-rs ~/projects/custom_barista/i3status-rust/config.toml
  tray_output none
}
```
Then run `i3-msg restart`.

## 10. Acceptance checks (builder runs them, reviewer re-checks)

1. `i3status-rs --version` prints 0.40.x. `fc-list ':charset=f08ae' family` lists "Symbols Nerd Font Mono".
2. `i3-msg -t get_bar_config` lists `bar-0` and `bar-rs`.
3. `timeout 5 i3status-rs i3status-rust/config.toml < /dev/null 2>&1 | head -c 4000` shows JSON, and `grep -ci error` = 0.
4. `i3status-rust/scripts/test.sh` passes all 15 rows (quiet output, summary line).
5. Screenshot: dock `bar-rs` temporarily (`i3-msg 'bar mode dock bar-rs'`, then `import -window root`, then `bar mode hide bar-rs`), crop the top 40 px of DP-0. Check: no tofu boxes; all 13 widgets show their icon from section 4; the GPU shows md-expansion_card; the disk IO block is present; the order matches section 4.
6. Clicks: the layout click switches US↔RU; volume left opens pavucontrol, wheel changes the volume, right mutes (`MUT` in yellow); clipboard opens the yad menu; the clock opens the calendar.
7. Cost: over 5 minutes, ccusage runs at most 6 times (`ps`-sample or a log line in the script under `CCUSAGE_DEBUG=1` only). Copying an image does not make clip.sh read the image data (row 14).
8. Barista `bar-0` still runs unchanged.

## 11. What does not change
- Widget order (main.go order). It can be revisited after the trial week, in the "Switch" item.
- Color values (`#6d6 #dd6 #d66 #777`) and the freq bucket colors.
- Barista stays running as `bar-0` until the "Switch to i3status-rust" item.
