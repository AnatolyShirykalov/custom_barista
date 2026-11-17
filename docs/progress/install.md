# install.sh (apply setup for another user)

2026-11-17: `install.sh` at repo root, template `i3status-rust/i3/bars.conf.tmpl` (tokens @BIN@ @CONFDIR@ @REPO@ @MOD@; reusable by item 2b).
- Path ties found: `config.toml`/`compact.toml` use `~/projects/custom_barista/...` (script commands) -> generated copies in `~/.config/custom_barista/` with REPO substituted; `barcycle.sh` already path-independent; Go `utils.Script` uses `~/scripts` (home-relative, fine); the i3 blocks use /data/go/bin and the repo path -> template.
- `~/scripts/clipboard_menu.sh`, `open_calender.sh` are not in the repo (clipboard one also needs a server on port 9847): install.sh warns when missing.
- Tested: `--dry-run` on the live config (no change), real run with HOME in a temp dir (GOBIN there): markers added, old bars removed with `--yes`, old barcycle binding commented, second run no change, duplicate `$mod+i` failed `i3 -C` and the backup was restored.
- Flags: `--dry-run`, `--no-restart`, `--yes`. Without a tty old bars are kept (warning); an old barcycle binding is commented out automatically.
- Not covered: `i3 -C` needs `i3` in PATH (skipped otherwise); outputs DP-0/DP-2 are hardcoded in the template.
