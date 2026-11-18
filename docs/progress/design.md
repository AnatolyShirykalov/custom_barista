# Design workstream

## 2026-11-18 D5 bar design review (spec/investigation)
- Screenshots of both real bars (import -window root, crops in `docs/design/D5-bar-review/img/today-*.png`); mocks A/B/C rendered with pango (PragmataPro Mono + Symbols Nerd Font Mono 18). Note: magick `-gravity` before `pango:` rotates glyphs; set it only after.
- Findings F1-F8: ccusage green when limit unknown (state Good on `$pct == null`); cryptic "CH"; "B" unit on 7 values; static IP 15 cells; clip pad 5 → 41 px vs 17 px before separator; scattered controls; 13 equal separators; DP-2 year.
- Verified on 0.40.1: `eng(hide_unit:true)` prints "89G"; `merge_with_next` accepted.
- freq→mem gap on DP-2 after b5c2eb5: 29 px vs 17 px for other blocks, extra 12 px = 1 space (pad 1 of max 3; worst 36 px). Slightly over i3's 9 px separator gap; kept for stable width.
- Decision page `docs/design/D5-bar-review/questions.html`: A polish (S), B polish + regroup with merge_with_next (M, recommended), C quiet dim bar (L); picks P1-P5. Edge case for B: gen-compact drops disk/io/ccusage on DP-2, so merge flags must still end on the right block there.
- Remaining: user pick → spec for widget-builder.

## 2026-11-18 U1 Claude usage block (spec)
- Spec `docs/design/U1-usage-block/spec.md`: option A (one 33-cell line `53%   3.4M $1.85 cache 90% 1h46m`, dim "cache" label for D5 F2, Idle when stale/unknown for D5 F1) over B (pct+time only) and C (click toggle). No decision page: layout detail inside the user's picks.
- Sources: repo-owned `scripts/claude-rl-tap.sh`, install.sh inserts one marker line into `~/.claude/bin/claude-statusline` (no copy of that file); OAuth usage fallback gated (180 s, 429 backoff to 1800 s, 401 stale until creds mtime changes, token only via `curl -H @-`).
- Cost from a repo pricing table `scripts/claude-prices.json` (platform pricing page 2026-11-18); statusline `cost.total_cost_usd` rejected (per session, not per window).
- Measured: local log scan of the 5h window (77 files of 1.4 GB) about 0.1 s with find -newermt + grep + one jq pass; 1140 duplicate msg/req groups, all identical usage, so keep-first dedupe is exact.
- Bar screenshot not possible this run (fullscreen window over the DP-0 bar); review takes before/after crops.
- Remaining: widget-builder implements, bar-designer review.
