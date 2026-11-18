# Design workstream

## 2026-11-18 D5 page v2 (picture per proposal)
- User: old page hard to work with, needs more pictures. Rebuilt `docs/design/D5-bar-review/questions.html`: one section per decision (F1-F8 with their P fix, options B/A/C), BEFORE/AFTER pairs for DP-0 and DP-2, full bars as two 1x halves, small regions 2x, click to enlarge; radio for A/B/C + checkboxes P2-P5 feed the answer line.
- BEFORE: live crops 21:10 (bar up 5 min after the U1b redeploy, no restart caught). AFTER: real i3bar + i3status-rs in Xvfb with temp config copies (`render/render.sh CFG WIDTH OUT`, status_command `env DISPLAY=:0` so kbd/clip/sound read the real session; i3 needs its own `ipc-socket` and `env -u I3SOCK`). No hand mocks.
- F1/F2 marked resolved by U1 (P1 dropped). Measured: P2 -84 px DP-0 / -48 px DP-2, P4 -12 px, A -276 px, B -330 px (6 separators instead of 12), B DP-2 -145 px.
- Observed: the U1b fixed 7-cell slot leaves a wide gap after `0h09m` while the mark is off; under option B (usage+clip merged) it reads as a hole. Candidate follow-up, not on the page as a pick.
- Remaining: user picks → widget-builder spec.

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

### U1 review (bar-designer, 2026-11-18): accepted, no fixes
- Tests 87/87; live `time claude-usage.sh` 0.15 s; strip width 33 for live, stale, unknown (`?%`) and max values.
- Bar crops 3 min apart (img/review-width.png): separators and neighbours aligned, `cache` dim, icon and glyphs render.
- Token: no part of the access token in ~/.cache/claude-usage (api.json, rate_limits.json, lock); no `set -x`/`Bearer $` in argv; header fed by builtin printf to `curl -H @-`.
- Statusline output identical to `.bak-u1` for the same input; second `./install.sh --yes` keeps exactly one marker line.
- Acceptance 6 replaced by an independent jq recompute (group_by dedupe, own price lookup): 118.95M / $67.34 vs bar 119.0M / $67.4 (gap = haiku >100K tier, which the one-off ignored).
- Deviation, accepted: dim on API `stale` only when the newest data is also older than 300 s (fresh tap data is not dimmed by an old 401); better than the spec's literal rule.
