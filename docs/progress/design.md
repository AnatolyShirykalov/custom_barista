# Design workstream

## 2026-11-18 D5 bar design review (spec/investigation)
- Screenshots of both real bars (import -window root, crops in `docs/design/D5-bar-review/img/today-*.png`); mocks A/B/C rendered with pango (PragmataPro Mono + Symbols Nerd Font Mono 18). Note: magick `-gravity` before `pango:` rotates glyphs; set it only after.
- Findings F1-F8: ccusage green when limit unknown (state Good on `$pct == null`); cryptic "CH"; "B" unit on 7 values; static IP 15 cells; clip pad 5 → 41 px vs 17 px before separator; scattered controls; 13 equal separators; DP-2 year.
- Verified on 0.40.1: `eng(hide_unit:true)` prints "89G"; `merge_with_next` accepted.
- freq→mem gap on DP-2 after b5c2eb5: 29 px vs 17 px for other blocks, extra 12 px = 1 space (pad 1 of max 3; worst 36 px). Slightly over i3's 9 px separator gap; kept for stable width.
- Decision page `docs/design/D5-bar-review/questions.html`: A polish (S), B polish + regroup with merge_with_next (M, recommended), C quiet dim bar (L); picks P1-P5. Edge case for B: gen-compact drops disk/io/ccusage on DP-2, so merge flags must still end on the right block there.
- Remaining: user pick → spec for widget-builder.
