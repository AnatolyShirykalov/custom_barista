# Recurring checks log

Dated notes from each recurring check (see the "Recurring checks" table in `docs/ROADMAP.md`).

## 2026-11-17 — Context diet (set up)

Disabled for this project in `.claude/settings.local.json` (personal): claude.ai Gmail, Google Calendar and Google Drive connectors (`deniedMcpServers`); skills docx, pptx, xlsx, pdf, google-workspace, morning, concerts, import-memory, deep-research (`skillOverrides: off`). Reason: unrelated to a Go i3 status bar. Re-enable by deleting the entries.
Kept: Claude Docs connector, web/image design skills, Chrome browser tools.
To confirm: run `/context` in the next session — whether project `skillOverrides` hides user/plugin skills and whether denied connectors drop out of the tool list.
