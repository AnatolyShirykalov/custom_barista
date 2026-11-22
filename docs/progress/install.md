# install.sh (apply setup for another user)

2026-11-17: `install.sh` at repo root, template `i3status-rust/i3/bars.conf.tmpl` (tokens @BIN@ @CONFDIR@ @REPO@ @MOD@; reusable by item 2b).
- Path ties found: `config.toml`/`compact.toml` use `~/projects/custom_barista/...` (script commands) -> generated copies in `~/.config/custom_barista/` with REPO substituted; `barcycle.sh` already path-independent; Go `utils.Script` uses `~/scripts` (home-relative, fine); the i3 blocks use /data/go/bin and the repo path -> template.
- `~/scripts/clipboard_menu.sh`, `open_calender.sh` are not in the repo (clipboard one also needs a server on port 9847): install.sh warns when missing.
- Tested: `--dry-run` on the live config (no change), real run with HOME in a temp dir (GOBIN there): markers added, old bars removed with `--yes`, old barcycle binding commented, second run no change, duplicate `$mod+i` failed `i3 -C` and the backup was restored.
- Flags: `--dry-run`, `--no-restart`, `--yes`. Without a tty old bars are kept (warning); an old barcycle binding is commented out automatically.
- Not covered: `i3 -C` needs `i3` in PATH (skipped otherwise); outputs DP-0/DP-2 are hardcoded in the template.

## 2026-11-22: i3 block moves to ~/.config/i3/config.local

- Why: the setup repo now owns `~/.i3/config` (anatoly: symlink into setup's `dotfiles/shared`, anatolii: copy overwritten by setup's install); it ends with `include ~/.config/i3/config.local`.
- `install.sh` step 4: block written by new `scripts/i3block.sh FILE BLOCK [BACKUP]` (`-n` = print only) into `${XDG_CONFIG_HOME:-~/.config}/i3/config.local`: replace in place or append, create file/dir, write via `printf >` so a symlink stays a link (backup `config.local.bak-<stamp>` next to the link, not in the target repo). Block lines use `~` (include, barcycle, hover-run). `~/.i3/config` is only read: warns on an old custom_barista block, `bar {}` blocks, a missing config.local include; never creates `~/.config/i3/config`. `bars.conf` stays `~/.i3/bars.conf`. Validation `i3 -C -c <main config>`; on failure prints the i3 errors, restores (or removes a newly created) config.local and bars.conf, exit 1 (checked by hand with a duplicate `$mod+i`).
- Dropped: old bar {} removal and `$mod+i` commenting prompts (they edited the main config); `ask()` gone, `--yes` still accepted.
- test.sh i1-i4 (install.sh copy without .git in a temp HOME): create, idempotent rerun, symlinked file keeps link + other lines, old block in ~/.i3/config only warned; main config byte-equal throughout. 175 pass.
- Deployed as anatoly: config.local still a symlink, only the block's paths changed (`/home/anatoly` -> `~`); i3 -C ok, both bars i3status-rs, hover daemon up, no ERR.
- anatolii: missing hover-run line is not intended; install.sh writes it unconditionally since T1c (ef80755, 2026-11-20; HOVER=0 is read by hover-run.sh at runtime), so anatolii's block predates T1c. Rerunning install.sh as anatolii adds it (and drops /home paths).
