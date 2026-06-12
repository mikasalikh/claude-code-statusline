# claude-code-statusline

> Model · git branch · context usage · tokens spent · rate limits — a tidy, colored status line for [Claude Code](https://claude.com/claude-code).

![demo](assets/demo.svg)

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Shell: bash](https://img.shields.io/badge/shell-bash-89e051.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey.svg)

[Русская версия →](README.ru.md)

A single dependency-light bash script. No daemons, no Node, no API calls — everything is read
from the JSON payload Claude Code already pipes to its status line hook, plus the session
transcript on disk.

## What you get

| Segment | Example | Meaning |
|---|---|---|
| Model | `Fable 5` | The model serving the session |
| Branch | `⎇ develop*` | Git branch in the session's working dir; `*` = uncommitted changes; detached HEAD shows the short commit hash |
| Context | `ctx 41.9k/1M · left 958.1k` | Context window: used / total, and how many tokens remain |
| Spent | `spent 166.2k` | "Fresh" tokens consumed this session: input (cache reads excluded) + output |
| 5-hour limit | `5h 2%→01:10` | Rolling 5-hour rate limit: used % and local reset time |
| Weekly limit | `7d 52%→Wed 05:00` | Weekly rate limit: used % and reset day/time |

Context and limit segments are traffic-light colored: **green** < 60%, **yellow** 60–84%,
**red** ≥ 85% — the thing that needs attention jumps out on its own.

Segments degrade gracefully: anything your Claude Code version or login type doesn't provide
simply disappears instead of breaking the line.

## Install

One-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/mikasalikh/claude-code-statusline/main/install.sh | bash
```

From source:

```bash
git clone https://github.com/mikasalikh/claude-code-statusline.git
cd claude-code-statusline && ./install.sh
```

The installer copies `statusline.sh` to `~/.claude/statusline.sh` and wires it into
`~/.claude/settings.json` (a `settings.json.bak` backup is written first; every other setting
is preserved). No restart needed — the line appears on the next conversation update.

Manual install, if you prefer to see every move:

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/mikasalikh/claude-code-statusline/main/statusline.sh \
  -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

…then add to `~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
```

## Requirements

- **bash**, **jq**, **awk** — `jq` is the only thing you're likely to be missing
  (`brew install jq` / `apt install jq`)
- **git** — optional, only for the branch segment
- **Claude Code ≥ 2.1.x** for the full set of segments (see compatibility below)

## How it works

Claude Code invokes the `statusLine` command on every conversation update (at most once per
300 ms) and pipes a JSON payload to stdin. The script reads:

- `model.display_name` — model segment
- `workspace.current_dir` — where to ask git about the branch
- `context_window.*` — window size, used tokens, used percentage
- `rate_limits.five_hour` / `rate_limits.seven_day` — used % and reset timestamps
- `transcript_path` — session transcript (JSONL); the **spent** counter sums
  `input + cache_creation + output` over it. Cache *reads* are excluded on purpose:
  they cost ~10% of the regular price and would inflate the number roughly tenfold.

One `jq` pass extracts every field (`@sh`-quoted, safe to `eval`), so the script stays fast.

## Compatibility

| Environment | Status |
|---|---|
| macOS (BSD `date`) | ✅ |
| Linux (GNU `date`) | ✅ |
| Windows via WSL / Git Bash | ✅ |
| Claude Code ≥ 2.1.x | all segments |
| Older Claude Code | model · branch · spent (no `context_window` / `rate_limits` in payload) |
| Subscription login (Pro / Max) | all segments |
| API-key login | rate-limit segments hidden (not in payload) |

## Customize

It's a ~100-line bash script — edit it, that's the point.

- **Disable colors:** set the standard [`NO_COLOR`](https://no-color.org) env var.
- **Thresholds:** the green/yellow/red cutoffs live in `pct_color()`.
- **Reorder / drop segments:** the line is assembled at the bottom of the script,
  one `line="$line$sep..."` block per segment — delete or reorder freely.
- **Time format:** the `fmt_ts` calls use `%H:%M` (5h) and `%a %H:%M` (7d).

To see what your Claude Code version actually sends (fields vary between releases), dump the
payload and design from there:

```bash
# add near the top of statusline.sh, watch the file, remove when done
printf '%s' "$input" > /tmp/cc-payload.json
```

## Troubleshooting

- **No line at all** — check `statusLine` in `~/.claude/settings.json`, `chmod +x` on the
  script, and run it by hand: `echo '{}' | ~/.claude/statusline.sh` (should print at least `?`).
- **No limit segments** — you're logged in with an API key, or your Claude Code is older than
  the `rate_limits` payload field (`claude --version`).
- **`spent` feels slow on very long sessions** — it scans the whole transcript JSONL; if it
  ever bothers you, delete the `spent` block.
- **Reset times look wrong** — timestamps are rendered in your local timezone via `date`;
  the script tries GNU syntax first, then BSD.

## Uninstall

```bash
./install.sh --uninstall
# or, without a clone:
curl -fsSL https://raw.githubusercontent.com/mikasalikh/claude-code-statusline/main/install.sh | bash -s -- --uninstall
```

Removes the `statusLine` key from settings (backup kept) and deletes the script.

## License

[MIT](LICENSE)
