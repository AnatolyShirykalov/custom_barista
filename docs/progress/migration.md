# Migration to i3status-rust (D3)

## 2026-11-17: D3 spec done (bar-designer)
- Output: `docs/design/D3-i3status-rust/spec.md` (block map in main.go order, verbatim `config.toml`, script I/O contracts, 15-row test table, i3 snippet for `bar-rs` at the top with Mod3, acceptance checks), `questions.html` + `img/` (mocks rendered with Symbols Nerd Font Mono: no tofu).
- User step: neither i3status-rust nor a Nerd Font is installed → `sudo pacman -S i3status-rust ttf-nerd-fonts-symbols-mono`.
- Icons: every block has a distinct glyph with a verified codepoint; GPU = md-expansion_card U+F08AE (the default md-monitor is vague).
- Found while speccing: barista's disk IO widget never shows (diskio asks for `cryptroot`, the kernel name is `dm-0`); the click paths use `/home/anatolii/...` (wrong user).
- Waste fixes: ccusage pinned `ccusage@20.0.51`, every 60 s instead of 5 s (measured about 2 CPU-s per run, so about 0.4 of a core before); clipboard checks TARGETS first, never reads images, reads text capped at 1 MiB, every 5 s.
- Questions for the user (3): GPU glyph, freq histogram vs average, music/weather. Defaults are the recommended answers; spec section 6 gives the exact edits for the other answers.
- Accepted losses (spec section 7): no separate urgent level, no red non-US layout, temp shows the max only.
