# U1 Claude usage block: spec (bar-designer, 2026-11-18)

Replaces `scripts/ccusage.sh` (npx ccusage, about 30 s and a network fetch every run) with a local script
`scripts/claude-usage.sh` that reads the real 5h rate-limit window and sums the local Claude Code logs.
User picks (ROADMAP U1): statusline `rate_limits` cache plus fallback to the OAuth usage endpoint; show
tokens, % colour, time left, cost and cache ratio of the real 5h window. D5 findings handled here: F1 (block
green when nothing is measured) and F2 (cryptic "CH"). The pending D5 A/B/C pick does not touch this spec.
If D5-B is built later, it only adds `merge_with_next` to this block; nothing here changes.

## Options

| | Bar text (DP-0) | Cells | Against |
|---|---|---|---|
| **A (recommended)** | `53%   3.4M $1.85 cache 90% 1h46m` | 33 | (none: all five values the user asked for, fixed width, 8 cells more than today on a 4K bar with room) |
| B | `53% 1h46m`, the rest in the middle-click popup | 10 | User asked for tokens, cost and cache on the bar; the popup is for meaning, not data. |
| C | left click toggles `53% 1h46m` / `3.4M $1.85 cache 90%` | 33 | Hides half the data, takes the refresh click, and must pad to the wider form anyway (no width gain). |

A wins: it is what the user asked for and the only one that shows everything at a glance with one width.
No user choice is needed (layout detail inside the user's own picks), so no decision page.

DP-0 only, as today: DP-2 is already tight (D5 gap work, b5c2eb5) and one usage block is enough on one screen.

## Elements (option A), left to right, fields joined by one space

| # | Field | Width | Format | Example |
|---|---|---|---|---|
| 1 | 5h used % | 4 | round half up, `%` appended, left-padded to 4; unknown `?%` | ` 53%`, `100%`, `  ?%` |
| 2 | window tokens | 6 | existing ccusage.sh rule: `<1e3` integer pad 5 + space; `<1e6` (and k<1000) f1 pad 5 + `K`; else f1 pad 5 + `M` | `  3.4M`, ` 999 `, `200.0K` |
| 3 | window cost USD | 5 | `<9.995` `$x.xx`; `<99.95` `$xx.x`; `<999.5` `$xxx` left-pad to 5; `<9999.5`... see below | `$1.85`, `$41.2`, ` $412`, `$1.2k`, ` $12k` |
| 4 | label `cache` | 5 | dim: `<span foreground='#777777'>cache</span>` (= theme `info_fg`, dim-icon) | `cache` |
| 5 | cache-read ratio | 3 | round half up, capped at 99, `%`, left-pad 3 | `90%`, ` 0%` |
| 6 | time to reset | 5 | `<h>h<mm>m`, minutes floored, mm zero-padded; unknown `-h--m` | `1h46m`, `0h00m`, `5h00m` |

Cost rule, exact: `c < 9.995` → `"$" + 2 decimals`; `c < 99.95` → `"$" + 1 decimal`; `c < 999.5` → `"$" + integer`
left-padded to 5; `c < 9950` → `"$" + f1(c/1000) + "k"`; else `"$" + round(c/1000) + "k"` left-padded to 5
(`$100k` max shown; above that `$999k` cap is fine, never reached).

Whole text: as today, leading spaces are moved to the end (`sub("^ +"; "")` then right-pad to the
pre-trim length), so the visible text starts at the icon and the total stays 33 cells. Width is measured
after stripping pango tags (test.sh `strip`).

Icon: unchanged (`ccusage` icon override, md-creation U+F0674, renders in Symbols Nerd Font Mono; checked).
The icon key and the explain key stay `ccusage` (no config churn); only the script is renamed.

## Values: data sources

### 1. Statusline tap (official source)
New `scripts/claude-rl-tap.sh`: reads the statusline JSON on stdin; if `.rate_limits.five_hour` exists, writes
atomically (`mktemp` in the same dir + `mv`) `${CU_CACHE:-$HOME/.cache/claude-usage/rate_limits.json}`:
`{"ts": <now epoch>, "five_hour": {"pct": <used_percentage>, "resets_at": <epoch>}, "seven_day": {...same or null}}`.
Statusline `resets_at` is Unix epoch seconds (docs: code.claude.com/docs/en/statusline). Without
`rate_limits` (non-subscriber, or before the first response of a session) it writes nothing. It must print
nothing on stdout (statusline prints stdout) and always exit 0.

Ownership: the repo owns the tap script, not a copy of `~/.claude/bin/claude-statusline` (that file is
user-level, shared by all projects, and calls other tools). `install.sh` inserts, idempotently, right after the
`input=$(cat)` line of `~/.claude/bin/claude-statusline`:
```bash
"<repo>/scripts/claude-rl-tap.sh" <<<"$input" >/dev/null 2>&1 || true  # custom_barista: rate_limits tap
```
(`<repo>` = absolute repo path install.sh already uses). Detection by the marker comment; if
`claude-statusline` is missing or has no `input=$(cat)` line, install.sh prints one line
`U1: statusline tap not installed (no ~/.claude/bin/claude-statusline input line); bar uses the API fallback`
and changes nothing. install.sh never edits `~/.claude/settings.json`.

### 2. OAuth usage endpoint (fallback, undocumented)
Used only when the tap cache is missing or older than 300 s, and only when the gate allows.
- Request: `curl -s --max-time 5 -o <body> -w '%{http_code}' -D <hdrs> -H @- https://api.anthropic.com/api/oauth/usage`
  with the two headers fed on stdin (`Authorization: Bearer <token>` and `anthropic-beta: oauth-2025-04-20`),
  so the token never appears in argv (`ps`). Token from `${CU_CREDS:-$HOME/.claude/.credentials.json}`
  `.claudeAiOauth.accessToken`, read into a variable only. Body and header temp files deleted at exit (trap).
- Never refresh or rotate the token, never write it anywhere, never `set -x`, curl stderr to /dev/null.
- If `.claudeAiOauth.expiresAt` (ms) < now: no call, status `stale` (Claude Code refreshes it on next use).
- Response: `five_hour.utilization` (0-100) and `five_hour.resets_at` (ISO 8601, may be null) → normalise to the
  same `{pct, resets_at epoch}` shape (`fromdateiso8601` after stripping fractional seconds and turning `+00:00`
  into `Z`; use `date -d` if jq cannot parse it).
- Gate state `${CU_STATE_DIR:-$HOME/.cache/claude-usage}/api.json`: `{ts_ok, next_at, backoff, status, cred_mtime, five_hour}`.
  | Result | Effect |
  |---|---|
  | 200 | store data, `ts_ok=now`, `status=ok`, `backoff=0`, `next_at=now+180` |
  | 429 | `backoff = min(1800, max(Retry-After header or 0, backoff*2 or 360))`, `next_at=now+backoff`, keep old data |
  | 401/403 | `status=stale`, `cred_mtime=<mtime of creds file>`; no further call until the creds file mtime differs |
  | other / 000 (network) | `next_at=now+300`, keep old data |
- The gate also applies to left-click refresh: clicking never bypasses 180 s.
- `flock -n` on `<state dir>/lock`; if busy, skip the API step and use what is stored.

### 3. Picking the window
Take the newer (by `ts` / `ts_ok`) of the tap cache and the API data. Age = now − that ts.
| Case | Display |
|---|---|
| age ≤ 900 s, resets_at > now | normal; state from pct |
| age > 900 s or API status `stale`, resets_at > now | pct shown dim (span `#777777`), state `Idle` |
| resets_at ≤ now, or API says resets_at null | window over: text `""` (block hidden, as today's cc9) |
| no data at all | pct `?%`, time `-h--m`, tokens/cost/cache over the rolling last 5 h, state `Idle` |

Window start = `resets_at − 18000`.

### 4. Tokens, cost, cache ratio from local logs
- Dirs: `$CU_PROJECTS` if set, else each existing of `$HOME/.config/claude/projects`, `$HOME/.claude/projects`
  (same as ccusage). Files: `find <dirs> -name '*.jsonl' -newermt "@<start>"` (includes `*/subagents/*.jsonl`).
- Pipeline: `xargs -0 grep -h '"usage"'` then one `jq -nR` pass: `[inputs | fromjson? | select(...)]` so
  half-written last lines are skipped. Measured on the real 1.4 GB log dir: 77 files, about 0.1 s.
- Select: `.type=="assistant"`, `.message.usage` present, `.message.model != "<synthetic>"`,
  `start_iso <= .timestamp < resets_iso` (string compare; both as `%FT%T.000Z` UTC; logs use ms + `Z`).
- Dedupe like ccusage: key `.message.id + ":" + .requestId`, keep the first seen (`unique_by` is stable);
  entries missing either id are never merged. (Real logs: 1140 duplicate groups in 5 h, all identical usage.)
- Tokens = Σ `input_tokens + output_tokens + cache_creation_input_tokens + cache_read_input_tokens` (ccusage total).
- Cache ratio = Σ cache_read / Σ (input + cache_creation + cache_read); 0 when the denominator is 0.
- Cost: pricing table in the repo, not the statusline `cost.total_cost_usd` (that is per session and resets per
  session; sessions straddle the window start, so it cannot give a per-window sum). Table file
  `scripts/claude-prices.json`, $ per MTok, prefix match on the model id, longest prefix wins:

  | prefix | in | cache write 5m | cache write 1h | cache read | out |
  |---|---|---|---|---|---|
  | `claude-fable-5-2` | 8 | 10 | 16 | 0.20 | 40 |
  | `claude-opus-5-5` | 4 | 5 | 8 | 0.20 | 20 |
  | `claude-opus-5` | 5 | 6.25 | 10 | 0.50 | 25 |
  | `claude-sonnet-5-5` | 2 | 2.50 | 4 | 0.10 | 10 |
  | `claude-sonnet-5` | 2 | 2.50 | 4 | 0.20 | 10 |
  | `claude-haiku-5-5` | 0.10 | 0.125 | 0.20 | 0.01 | 0.50 |
  | `claude-haiku-5-5` prompt > 100000 | 0.50 | 0.625 | 1 | 0.05 | 2.50 |
  | `default` (unknown model) | 8 | 10 | 16 | 0.20 | 40 (= most expensive row; overestimates rather than hides) |

  Source: platform.claude.com/docs/en/about-claude/pricing (fetched 2026-11-18). Haiku tier: prompt = input +
  cache_creation + cache_read of that request. Cache write split: `.usage.cache_creation.ephemeral_1h_input_tokens`
  and `ephemeral_5m_input_tokens`; if the object is absent, all cache_creation is 5m. `inference_geo == "us"`
  multiplies that entry by 1.1. Fast mode / server tools: ignored (no extra cost counted).

### 5. State (colour)
Raw pct (not rounded): `> 90` Critical, `> 70` Warning, else Good; `Idle` when stale or unknown (D5 F1: green only
when measured). Thresholds confirmed as today's: at 70 % with typically 1-2 h left the user still has time to
slow down; 90 % is "about to be throttled". Script failure (jq missing, internal error): `{"icon":"ccusage","state":"Critical","text":"cc err"}` as today.

## config.toml block (paste over the ccusage block, clicks unchanged)
```toml
[[block]]
block = "custom"
command = "~/projects/custom_barista/scripts/claude-usage.sh"
json = true
interval = 60
hide_when_empty = true
[[block.click]]
button = "left"
update = true
[[block.click]]
button = "middle"
cmd = "~/projects/custom_barista/scripts/explain.sh ccusage"
```
`gen-compact.sh`: drop pattern `ccusage\.sh"` becomes `claude-usage\.sh"` (header comment too); test.sh lines
48-49 use the new name (count stays 4). Delete `scripts/ccusage.sh` and `scripts/testdata/cc_*.json`.

## explain.sh text (key `ccusage`, 5 lines)
```
Claude usage in the current 5h limit window:\nlimit % used, tokens, cost (list price),\ncache = share of input read from cache, time to reset.\nGreen; yellow above 70%; red above 90%; white = no fresh data.\nLeft click: refresh. DP-0 bar only.
```

## Test hooks (no network in tests)
Env: `CU_NOW` (epoch, default `date +%s`), `CU_CACHE`, `CU_STATE_DIR`, `CU_PROJECTS`, `CU_CREDS`, `CU_PRICES`
(default `scripts/claude-prices.json`), `CU_API_FIXTURE=<file>`: first line HTTP status, optional
`retry-after: N` line, blank line, body; when set, curl is never run. test.sh always sets `CU_API_FIXTURE`
(an `000` fixture when the row does not test the API) and a fresh `CU_STATE_DIR` per row.
`claude-usage.sh --render '<json>'` renders `{pct,tok,cost,ch,left,stale}` to the final JSON (for width rows).

## Fixtures `scripts/testdata/u1/` (NOW = 2026-11-18T12:00:00Z = 1795003200)
`resets_at` = 13:46:00Z (1795009560), window start 08:46:00Z. `proj/p1/s1.jsonl` (+ `proj/p1/s1/subagents/a1.jsonl` holding e3):
| id | ts | model | in | out | cc (5m/1h) | cr | counted |
|---|---|---|---|---|---|---|---|
| e1 m1/r1 | 09:00 | claude-opus-5-5 | 1000 | 20000 | 100000 (no cache_creation obj) | 2000000 | yes, $1.304 |
| e1' m1/r1 | 09:00:01 | same as e1 | | | | | dup, no |
| e2 m2/r2 | 10:00 | claude-sonnet-5-5 | 500 | 10000 | 50000 (0/50000) | 1000000 | yes, $0.401 |
| e3 m3/r3 | 11:00 | claude-haiku-5-5 | 200000 | 1000 | 0 | 0 | yes, >100K tier, $0.1025 |
| e4 m4/r4 | 08:00 | claude-opus-5-5 | 999999 | 0 | 0 | 0 | no, before start |
| e5 | 11:30 | `<synthetic>` | 5 | 5 | 0 | 0 | no |
| e6 m6/r6 | 11:40 | claude-future-9 | 0 | 1000 | 0 | 0 | yes, default rate, $0.04 |
| user line containing `"usage"` text, and a truncated last line | | | | | | | no |
Totals: tokens 3383500 → `3.4M`; cost 1.8475 → `$1.85`; cache 3000000/3351500 = 89.5 % → `90%`.
`creds.json`: accessToken `TESTTOKEN-u1`, expiresAt far future.

## Test table (test.sh rows; text compared after `strip`, trailing space kept)
| row | setup | want text | state |
|---|---|---|---|
| u1 | cache ts NOW−60, pct 53 | `53%   3.4M $1.85 cache 90% 1h46m ` | Good |
| u2 | cache pct 70 | `70%   3.4M $1.85 cache 90% 1h46m ` | Good |
| u3 | cache pct 70.4 | `70%   3.4M $1.85 cache 90% 1h46m ` | Warning |
| u4 | cache pct 90 / 95 | `90% ...` / `95% ...` | Warning / Critical |
| u5 | cache ts NOW−600, API 200 utilization 37.0, resets `2026-11-18T13:46:00.123456+00:00` | `37%   3.4M $1.85 cache 90% 1h46m ` | Good; api.json next_at = NOW+180 |
| u6 | as u5 but api.json next_at = NOW+100 (gated), cache NOW−600 pct 53 | `53% ...` (cache used, API not called: fixture 200 with 37 ignored) | Good |
| u7 | cache NOW−600 pct 53, API 429 retry-after 600 | `53% ...` | Good; next_at = NOW+600 |
| u8 | cache NOW−1200 pct 53, API 401 | `53%` dim (span present in raw text) `... 1h46m ` | Idle; status stale |
| u9 | u8 state kept, fixture now 200; same creds mtime | still stale (no call) | Idle |
| u10 | u9 then `touch -d @NOW` creds (new mtime) | `37% ...` | Good |
| u11 | cache resets_at NOW−60, API 000 | `` (empty) | (any) |
| u12 | no cache, API 000, no state: rolling window 07:00-12:00 includes e4 (+999999 tokens, +$3.999996) | `?%   4.4M $5.85 cache 69% -h--m  ` (two trailing spaces; 3000000/4351499 = 68.9 %) | Idle |
| u13 | creds expiresAt in the past, cache NOW−1200 | pct dim, API fixture not read | Idle |
| u14 | token check: after u5..u10, `grep -r TESTTOKEN-u1` over stdout and CU_STATE_DIR | no match | |
| u15 | tap: statusline JSON with rate_limits → stdout empty, cache file `.five_hour.pct==53`, `.five_hour.resets_at==1795009560`, `.ts` numeric; JSON without rate_limits → cache file unchanged | | |
| u16 | width: `--render` for pct {0,5,100,null}, tok {0,5,999,999950,200000,53300000}, cost {0,9.994,9.995,99.96,999.6,1234,12345}, ch {0,100}, left {0,59,299,300} (each varied alone from u1) | strip length always 33 | |
| u17 | `EXPLAIN_DRY=1 explain.sh ccusage` | contains `cache`, not `CH` | |
| u18 | compact rows 48-49 with `claude-usage\.sh` | pass | |
Remove rows cc5-cc10 and the ccwidth loop.

## Acceptance checks (review)
1. `bash scripts/test.sh | tail -5`: all pass; no network during the run (`CU_API_FIXTURE` always set).
2. Real bar on DP-0 after `./install.sh`: text matches the u1 shape, label `cache` dim, no tofu, icon unchanged;
   width constant over 3 refreshes (screenshot crop before/after).
3. Live run time `time scripts/claude-usage.sh` < 0.5 s with a fresh tap cache.
4. `grep -n 'set -x\|Bearer \$' scripts/claude-usage.sh` shows no argv use of the token; token only via `-H @-`.
5. `~/.claude/bin/claude-statusline` has exactly one marker line after a second `./install.sh`; Claude Code
   statusline output is unchanged (tap prints nothing).
6. Tokens of the window within 1 % of `npx ccusage blocks --active` total when its block start equals ours
   (one manual comparison noted in docs/progress/widgets.md; ccusage blocks are floored to the hour, so only
   compare when the real window started on the hour).

## Out of scope
7-day limit indicator (backlog), icon change, DP-2 placement, D5 regrouping.
