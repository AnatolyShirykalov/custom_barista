# D4 rs polish: spec

Scope: the 4 backlog items "Design (i3status-rust trial bars)" (look pass 2026-11-17). Files: `i3status-rust/config.toml`, `scripts/{freq,ccusage,clip,gpu,test}.sh`, then `scripts/gen-compact.sh` to regenerate `compact.toml`. Today: `img/today_L.png`, `img/today_R.png`; mocks: `img/icons_dim.png`, `img/gap_after.png`, `img/units_*.png`, `img/io_*.png`. Two questions are the user's (units, IO markers): `questions.html`; defaults below are the recommended answers, build those unless the user picks otherwise.

## 1. Icon color: dim all icons (picked)
Options: A one global dim rule (picked: matches barista `dim-icon` #777, one setting); B undim time (rejected: icons then compete with values); C per-block `icons_format` (rejected: 13 copies to keep in sync).
- Add top level, before `[theme]`: `icons_format = "<span color='#777777'>{icon}</span>"`.
- Delete the `icons_format = ...` line in the `time` block.
- Covers `$icon`, `^icon_*` (net arrows, keyboard, calendar, time) and custom-block JSON `icon`. Icons stay #777 in Warning/Critical; only the value takes the state color (as barista load/temp).

## 2. Icon-value gap: pad goes after the value (picked)
Rule: a value starts one space after its icon; fixed-width padding moves to the end of the text (same total length). Options: A trailing pad (picked); B pad before the icon (rejected: the icon then jumps away from the separator); C no pad (rejected: width jitter).
- `freq.sh`: build counts first, then append the pad: `print s sprintf("%" pad "s", "")` (start `s=""`; keep `pad` formula; pad 0 allowed).
- `ccusage.sh`: keep the per-field pads, after `join(" ")` move leading spaces to the end: `| join(" ") | length as $n | sub("^ +"; "") | . + (" " * ($n - length) // "")`.
- `clip.sh`: `printf '%-5s'` instead of `'%5s'`.
- `eng(w:N)` blocks (load, temp, mem, disk, io, net, battery, sound) stay right-aligned: eng has no right-pad option (`pad_with` sets only the char); the gap there is at most 1 char.
- Edge: if i3status-rs/i3bar trims trailing spaces (screenshot shows block shrinking), use U+2007 figure space as the pad char.

## 3. Disk IO markers (question 2; default A)
A (recommended) dim letters `R`/`W` as icon overrides, so they get the global dim: in `[icons.overrides]` add `disk_read = "R"`, `disk_write = "W"`; format ` $icon ^icon_disk_read $speed_read.eng(p:k,w:3) ^icon_disk_write $speed_write.eng(p:k,w:3) `. B glyphs md-eye_outline `"\U000F06D0"` / md-pencil `"\U000F03EB"` (render checked, no tofu) in the same two override keys. Against B: two more pictograms in a row of icons, read the eye as "visible". Against arrows (net style): same arrows as net, confusable.

## 4. Units (question 1; default A)
One convention for mem, disk, GPU mem, disk IO and (for consistency) net speeds: eng-style 3-digit number (`w:3`) + unit, one family.

| Value | A decimal SI (recommended) | B binary IEC |
|---|---|---|
| memory | `$mem_avail.eng(p:G,w:3)` → ` 75GB` | `eng(p:Gi,w:3)` → ` 70GiB` (today, w kept) |
| disk_space | `$available.eng(p:G,w:3)` → `616GB` (today) | `eng(p:Gi,w:3)` → `574GiB`; `alert_unit = "GiB"`, thresholds 93.0 / 28.0 |
| disk IO | `eng(p:k,w:3)` → `0.0kB`, `796kB`, `3.9MB` | `eng(p:Ki,w:3)` → `0.0KiB` |
| net up/down (both blocks) | `eng(p:k,w:3)` (today `p:K,w:4`) | `eng(p:Ki,w:3)` |
| GPU mem (`gpu.sh`) | GB = MiB×1.048576/1000 | GiB = MiB/1024 |

GPU mem number in `gpu.sh`, eng-like: `v = <GB or GiB>; s = (v < 9.95) ? sprintf("%.1f", v) : sprintf("%3d", int(v + 0.5))`; text `sprintf("%2d° %s%s", t, s, unit)` (unit `GB`/`GiB`).
Against B: eng switches binary prefix at 1024, so 1000-1023 KiB/MiB print 4 digits and the IO/net width jitters by 1 char; units are 1 char longer. Against A: RAM reads 75GB where `free -h` says 70Gi.

## Builder checklist
1. config.toml edits 1-4 (A defaults unless the user answered otherwise); `scripts/gen-compact.sh`; `git diff compact.toml` shows the same edits minus dropped blocks.
2. Scripts: freq/ccusage/clip trailing pad; gpu.sh new mem format.
3. test.sh rows: freq1 `1 0 0 2 1 0      ` (pad trailing; same for freq2/3), cc5 `53.3M CH  96% 1h46m      `, cc6-8 lose the leading space and gain one trailing, clip helper trims trailing (`gsub(" +$";"")`), gpu1/gpu3 `34° 5.0GB` (A) or `34° 4.7GiB` (B); add `gpu4`: `99, 16303` → `99°  17GB` (A) / `99°  16GiB` (B); existing width rows (ccwidth, clipwidth, gpuwidth) unchanged and passing.
4. `scripts/test.sh` all pass; `i3status-rs` smoke: `timeout 5 i3status-rs i3status-rust/config.toml | head -c 3000` has no `Error`.
5. Switch to rs bars (barcycle), screenshot DP-0 and DP-2 3× over 6 s, restore the previous bar state.

## Acceptance checks
- Every icon (incl. net arrows, R/W) is #777 in the screenshot; load/temp values still red when hot.
- freq, ccusage, clip, gpu values start one space after the icon; block right edges fixed across the 3 shots (±0 px).
- Disk IO shows markers and 3-digit numbers; no `kB`/`KiB`/`MiB` mix across mem/disk/IO/net/GPU.
- test.sh pass, compact.toml in sync, no tofu, DP-2 still fits.

## Decisions (user, 2026-11-17)
- Q1 units: A, decimal GB/MB/kB with `eng(w:3)`.
- Q2 disk IO markers: A, dim letters R/W via icon overrides `disk_read`/`disk_write`.

## Review (designer, 2026-11-17): accepted
Commit e884777 + review fix (test.sh). Checks:
| Check | Result |
|---|---|
| Icons #777 (incl. net arrows, R/W) | pass: JSON shows every icon in `<span color='#777777'>`; screenshots dim |
| Load/temp red when hot | pass: block `color` #DD6666 (load 74/32 cores > critical 0.5; temp 80°), icon stays #777 |
| freq/ccusage/clip/gpu one space after icon | pass |
| Right edges fixed across 3 shots | pass: separator x identical on DP-0 (12) and DP-2 (9) |
| Disk IO markers, 3-digit numbers, one unit family | pass: `R 0.0kB W 2.0kB`, mem 74GB, disk 616GB, net kB, GPU 1.2GB |
| test.sh, compact sync, no tofu, DP-2 fits | pass: 38/0 after fix; gen-compact in sync; no tofu; DP-2 has free room left |
Fix made in review: the freq3 last-color check counted only failures (builder 38 vs rerun 37); now counts a pass. R/W only on DP-0 is intended (compact drops disk_iostats). Live configs equal install.sh output.
Cosmetic note (no fix): on DP-2 freq's trailing pad plus mem's right-aligned ` 74GB` leave a wide gap between the two; per spec (eng has no right pad).
