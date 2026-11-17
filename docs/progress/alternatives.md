# Alternatives report (A1)

## 2026-11-17: report done
- Output: `docs/design/A1-alternatives/report.html` (score matrix, coverage, icons, cards, migration sketches, risks).
- Recommendation: migrate to i3status-rust in stages (side-by-side bar for a week, ~4-5 h). Score 42/45 vs 34 for barista as is, 37 for barista hardened.
- Key facts: soumya92/barista archived 2024-06-25; the barista.run domain expired (301 to expireddomains.com), and builds only work because proxy.golang.org caches the pinned pseudo-version. The final commit declares module `github.com/soumya92/barista`.
- Icon root cause: nvidia/nvidia.go:67,69 use `mdi-*` and vol/vol.go:18,30 use `ion-*`, but main.go loads only material and typicons. barista returns an empty node for an unknown provider, so those icons are blank. typicons is loaded but unused.
- Other findings: ccusage runs `npx ccusage@latest` every 5 s (Node start, unpinned); clipboard reads the full clipboard every 2 s just to get its size.
- Proposed backlog items (for the main session to file, depending on the user's verdict): (1) load mdi + fix GPU and volume icons; (2) rewrite or vendor the barista module path; (3) pin and slow down ccusage polling; (4) cheaper clipboard polling; (5) i3status-rust side-by-side trial if migration is approved.
