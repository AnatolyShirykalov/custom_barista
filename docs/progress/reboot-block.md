# Reboot block

2026-11-27 R1b: after reboot into 7.3.6 the block showed "Invalid JSON": reboot-needed.sh printed nothing and config.toml uses `json = true`. Fix: the nothing-needed path prints `{"text":""}` (hidden by hide_when_empty). All other paths (kernel, boot, relogin, ERR) already emit JSON; `list` mode is plain text for hover. test.sh rb4 now asserts valid JSON with empty text. Smoke of config.toml and compact.toml: no errors, no reboot block shown.
