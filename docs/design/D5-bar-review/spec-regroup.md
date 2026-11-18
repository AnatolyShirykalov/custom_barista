# D5-R spec: regroup the bar + 7d mark always visible

Roadmap item 8. User picks 2026-11-18: "regrouping only" from D5 option B (block order + `merge_with_next` groups), no
polish (P2/P3/P5 dropped: "we have enough space"); clipboard block already removed (eb1abc0). Usage 7d mark: "don't
hide it", always show `7d NN%`, colour only above 70 / 90. For `widget-builder`; no choice is left open.

All values below were applied to a scratch copy of the repo: `bash scripts/test.sh` gave `pass=94 fail=0`, and both bars
were rendered with `render/render.sh` (real i3bar + i3status-rs 0.40.1 in Xvfb).

## 1. Options

### Grouping
| | Option | Separators DP-0 / DP-2 | Verdict |
|---|---|---|---|
| **R1** | **Option B order and groups, without clip** (below) | 11 → 6 / 8 → 5 | **recommended**: this is what the user picked; controls sit by the clock, monitors read as CPU / storage / GPU / net |
| R2 | Today's order, merges only (load, temp, memory, disk_space) | 11 → 7 / 8 → 6 | against: drops the order half of the pick; keyboard stays far left, volume/usage scattered |
| R3 | R1 + usage merged into the net or controls group | 5 / 5 | against: usage is unrelated to either; `hide_when_empty` usage means a merged net group would glue onto the controls group whenever there is no 5h window |

### 7d mark at ≤ 70 %
| | Option | Verdict |
|---|---|---|
| **M1** | **Whole mark dim `#777777`** (`7d 48%`, `7d  ?%`) | **recommended**: idle info stays dim; only yellow/red draw the eye, one accent per state |
| M2 | Dim `7d` label, value in block colour (like `cache 95%`) | against: the value takes the 5h state colour, so a yellow 5h block shows a yellow `7d 45%` that looks like a weekly warning |
| M3 | Plain (block colour) | against: same as M2, and it competes with the 5h numbers |

## 2. Block order and groups (config.toml, DP-0)

Reorder the `[[block]]` sections of `config.toml` to exactly this sequence (each block keeps all its current lines and
clicks unchanged); `*` = add `merge_with_next = true` as the line directly after its `block = "..."` line.

| # | block (identify by) | merge | group |
|---|---|---|---|
| 1 | `load` | * | CPU |
| 2 | `temperature` | * | CPU |
| 3 | custom `freq.sh` | | CPU (end) |
| 4 | `memory` | * | storage |
| 5 | `disk_space` | * | storage |
| 6 | `disk_iostats` | | storage (end) |
| 7 | custom `gpu.sh` | | GPU |
| 8 | `net` `device = "^wl"` | * | net |
| 9 | `net` `device = "^en"` | | net (end) |
| 10 | custom `claude-usage.sh` | | usage |
| 11 | `keyboard_layout` | * | controls |
| 12 | `battery` | * | controls |
| 13 | `sound` | | controls (end) |
| 14 | `time` | | clock |

7 `merge_with_next` lines in config.toml. Header (`icons_format`, `[theme]`, `[icons]`) unchanged. For a custom block the
flag goes after `block = "custom"` (before `command`). Example:

```toml
[[block]]
block = "load"
merge_with_next = true
format = " $icon $1m.eng(w:4) $15m.eng(w:4) "
```

Visible on this desktop (wifi down, no battery): DP-0 `CPU | storage | GPU | net | usage | kbd+sound | clock` = 6
separators. Inside a group the blocks keep their own leading/trailing space (2 cells between them, no line).

## 3. DP-2: scripts/gen-compact.sh must change

gen-compact drops `disk_space`, `disk_iostats`, `claude-usage`. Without a change `memory` keeps its flag and glues onto
GPU. Rule (generic, not a hard-coded name): **when a dropped block has no `merge_with_next` (it ended its group), the
last kept block before it loses its `merge_with_next` line.** Replace the `awk` program in `gen()` with:

```sh
  awk '
    # a kept block whose group ends on a dropped block loses its merge flag (memory on DP-2)
    function flush() {
      if (buf == "") return
      if (!drop) { printf "%s", prev; prev = buf } else if (!merged) sub(/\nmerge_with_next = true\n/, "\n", prev)
      buf = ""; drop = 0; merged = 0 }
    /^\[\[block\]\]$/ { flush() }
    /^block = "(disk_space|disk_iostats)"/ || /^command = .*claude-usage\.sh"/ { drop = 1 }
    /^merge_with_next = true$/ { merged = 1 }
    /^format = .*\$ip/ { sub(/ \$ip /, " ") }
    { buf = buf $0 "\n" }
    END { flush(); printf "%s", prev }' "$d/config.toml"
```

and extend the header comment: `...the usage block and the net $ip;` + new line `# a block merged into a group whose
rest is dropped loses merge_with_next.` Result: compact.toml has 5 flags (load, temperature, net ^wl, keyboard_layout,
battery); DP-2 shows `CPU | memory | GPU | net | kbd+sound | clock` = 5 separators. Regenerate with
`scripts/gen-compact.sh`, never hand-edit.

## 4. Usage 7d mark always visible (scripts/claude-usage.sh, M1)

Replace the whole `... ) as $wm` line in `render()` with:

```jq
    | (if $w == null then ("7d  ?%" | dim) else (([$w + 0.5 | floor, 99] | min | tostring) | pad(2)) as $v | if $w > 90 then "<span foreground=\"#dd6666\">7d " + $v + "%</span>" elif $w > 70 then "<span foreground=\"#dddd66\">7d " + $v + "%</span>" else ("7d " + $v + "%" | dim) end end) as $wm
```

| 7d utilization | shows | colour | block state |
|---|---|---|---|
| unknown (no seven_day, or its window expired) | `7d  ?%` | dim #777777 | unchanged (from 5h) |
| 0 … 70 (incl. 70.4 → `70%`, rounding as today) | `7d NN%` (pad 2: `7d  0%`) | dim #777777 | unchanged |
| > 70 | `7d NN%` | #dddd66 (degraded) | unchanged |
| > 90 | `7d NN%`, ≥ 99.5 shows `99` | #dd6666 (bad) | Critical (as today) |

Always 6 cells, so the block width is the same as today's blank slot (no jitter, no hole after the time-left).
State logic untouched.

explain.sh `ccusage` text: replace the line `7d NN% at the end: weekly limit above 70% (yellow), above 90% (red, whole
block red).` with `7d NN% at the end: weekly limit; grey up to 70%, yellow above, red above 90% (whole block red), ?% =
unknown.` (still 6 lines; `explain` test requires ≤ 6).

## 5. test.sh changes (verified green in scratch: pass=94 fail=0)

| row | change |
|---|---|
| `sp7` | `sp7=" 7d  ?% "` (u1-u10, u13, u21, u4a/u4b now expect the unknown mark) |
| u1 | add after it: `jq -r .text <<<"$o" \| grep -q '#777777">7d  ?%'` → else `FAIL u1: 7d unknown dim` |
| u12 | expected `"?%   4.4M \$5.85 cache 69% -h--m 7d  ?%  "` |
| u18 | `w7 70; o=$(un); check u18 "$o" "53%  $body 7d 70% " Good` + grep `'#777777">7d 70%'` → `FAIL u18: 7d dim` |
| u19, u20 | unchanged |
| u21 | unchanged text (`$sp7` now carries the unknown mark) |
| u22 new | `w7 0.3; check u22 "$(un)" "53%  $body 7d  0% " Good` |
| u23 new | `w7 100; check u23 "$(un)" "53%  $body 7d 99% " Critical` |
| groups new | after the `config.toml patterns changed` row: `merge_with_next = true` count is 7 in config.toml and 5 in compact.toml, else `FAIL groups: merge_with_next count` |
| compact new | awk over compact.toml: no `merge_with_next` inside the `memory` block, else `FAIL compact: memory still merged` |

```sh
# D5-R groups: 7 merge flags on DP-0 (6 separators), 5 on DP-2; memory must not glue onto gpu on DP-2
[ "$(grep -c '^merge_with_next = true$' "$d/../config.toml")" == 7 ] && [ "$(grep -c '^merge_with_next = true$' "$d/../compact.toml")" == 5 ] && pass=$((pass+1)) || { echo "FAIL groups: merge_with_next count"; fail=$((fail+1)); }
awk '/^\[\[block\]\]$/ { b = "" } /^block = / { b = $0 } /^merge_with_next/ && b ~ /memory/ { f = 1 } END { exit f }' "$d/../compact.toml" && pass=$((pass+1)) || { echo "FAIL compact: memory still merged"; fail=$((fail+1)); }
```
Negative check done: adding the flag back to memory in compact.toml fails both rows (plus the sync row).
The existing `config.toml patterns changed` count (4) still holds after the reorder.

## 6. Click events after merge (verified on 0.40.1)

Ran i3status-rs 0.40.1 with load* + custom* + time and fed i3bar-style click events on stdin: each merged block keeps
its own `instance` (`0:`, `1:`, `2:`) in the JSON (`"separator":false,"separator_block_width":0` on merged ones), and a
middle click on each ran that block's own `cmd`. So per-block `explain.sh` popups and left clicks (kbd switch,
pavucontrol, usage refresh, calendar) keep working.

## 7. Edge cases

| case | result | action |
|---|---|---|
| wifi down / absent (desktop) | `^wl` empty; its flag is harmless, `^en` ends the group | none |
| battery absent (desktop) | empty; kbd merges onto sound | none |
| no 5h window (usage `{"text":""}`, hide_when_empty) | usage alone, net ends its own group; nothing glues | none |
| laptop with no `^en` device (`missing_format = ""`) | the last group member is empty, so wifi glues onto usage (DP-0) / kbd (DP-2) without a line (tested: an empty next block passes the merge on) | accepted, cosmetic; not on this machine (eno1) |
| `net ^en` inactive | shows ` $icon down `, group intact | none |
| temperature chip error | error text inside the CPU group | none |
| 7d window expired (`resets_at` past) | `7d  ?%` dim | as table §4 |

## 8. Expected sizes (measured on the renders)

| bar | separators | status width |
|---|---|---|
| DP-0 3840 | 11 → 6 | 2685 → 2640 px (−45 = 5 × 9 px separator gap) |
| DP-2 2560 | 8 → 5 | 1596 → 1569 px (−27) |

The 7d mark adds no width (it fills today's blank 6-cell slot).

## 9. Before / after renders (Xvfb, 1x)

- DP-0 left half: `img/r-dp0-1.png` (top before, bottom after)
- DP-0 right half: `img/r-dp0-2.png` (after shows `7d 48%` dim, `US` + volume next to the clock)
- DP-2: `img/r-dp2.png`

Glyphs render (no tofu) in all three.

## 10. Acceptance checks (reviewer)

1. `bash scripts/test.sh | tail -3` → `fail=0`, pass = previous + 4 (u1 dim, u18 dim, u22, u23) + 2 (groups, compact).
2. config.toml block order equals §2; exactly 7 flags, each directly after its `block =` line; no other line changed
   except the move (`git diff --stat` shows only reordering + 7 insertions in config.toml).
3. compact.toml regenerated, 5 flags, none in memory; `gen-compact.sh - | cmp - compact.toml` clean.
4. Live screenshot after `./install.sh`: DP-0 strip shows 6 separator lines in the order of §2, DP-2 shows 5; matches
   `img/r-dp0-*.png` / `img/r-dp2.png` bottom rows.
5. Usage block on DP-0 ends with a dim `7d NN%` (or `7d  ?%`), same block width as before.
6. Middle-click on load, temperature, freq, memory, disk, IO, kbd and sound each opens its own explain popup; left click
   on kbd still switches layout.
7. No P2/P3/P5 changes: units `GB`/`kB` and the IP still shown, DP-2 date keeps the year.
