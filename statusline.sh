#!/usr/bin/env bash
# shellcheck disable=SC2154  # payload variables are assigned via the eval'd jq output below
#
# claude-code-statusline — a status line for Claude Code:
#   model · git branch (+ dirty marker) · context window usage · session tokens · 5h/7d rate limits
#
# Claude Code pipes a JSON payload to this script on stdin and renders the output
# at the bottom of the terminal UI. ANSI colors are supported as-is.
#
#   https://github.com/mikasalikh/claude-code-statusline
#   Payload reference: https://code.claude.com/docs/en/statusline

input=$(cat)

command -v jq >/dev/null 2>&1 || { printf 'claude-code-statusline: jq not found — install jq'; exit 0; }

# --- colors (honors NO_COLOR, https://no-color.org) ---------------------------
if [ -n "${NO_COLOR:-}" ]; then
  RST=""; DIM=""; CYAN_B=""; MAGENTA=""; BLUE=""; GREEN=""; YELLOW=""; RED=""
else
  esc=$'\033'
  RST="${esc}[0m"; DIM="${esc}[2m"
  CYAN_B="${esc}[1;36m"; MAGENTA="${esc}[35m"; BLUE="${esc}[34m"
  GREEN="${esc}[32m"; YELLOW="${esc}[33m"; RED="${esc}[31m"
fi

# usage % -> color: <60 green, 60–84 yellow, >=85 red
pct_color() {
  if [ "${1:-0}" -ge 85 ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "${1:-0}" -ge 60 ] 2>/dev/null; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

# 12345 -> "12.3k", 1000000 -> "1M"
fmt_tok() {
  awk -v n="${1:-0}" 'BEGIN {
    if (n>=1000000) { m=n/1000000; printf (m==int(m) ? "%dM" : "%.1fM"), m }
    else if (n>=1000) { k=n/1000;  printf (k==int(k) ? "%dk" : "%.1fk"), k }
    else printf "%d", n }'
}

# unix timestamp -> local time; GNU date (-d @ts) first, BSD/macOS date (-r ts) as fallback
fmt_ts() {
  date -d "@$1" +"$2" 2>/dev/null || date -r "$1" +"$2" 2>/dev/null
}

# --- payload: one jq pass for every field (@sh-quoted -> safe to eval) ---------
# Fields missing from older Claude Code versions resolve to defaults and their
# segments are silently skipped below.
eval "$(printf '%s' "$input" | jq -r '
  @sh "model=\(.model.display_name // "?")",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "transcript=\(.transcript_path // "")",
  @sh "ctx_size=\(.context_window.context_window_size // 0)",
  @sh "ctx_pct=\(.context_window.used_percentage // "")",
  @sh "ctx_in=\(.context_window.total_input_tokens // 0)",
  @sh "ctx_out=\(.context_window.total_output_tokens // 0)",
  @sh "rl5=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "rl5_at=\(.rate_limits.five_hour.resets_at // "")",
  @sh "rl7=\(.rate_limits.seven_day.used_percentage // "")",
  @sh "rl7_at=\(.rate_limits.seven_day.resets_at // "")"
')"

# --- git branch (detached HEAD -> short hash) + dirty marker -------------------
branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
[ -z "$branch" ] && branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
dirty=""
if [ -n "$branch" ] && [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null | head -1)" ]; then
  dirty="${YELLOW}*"
fi

# --- session spend: "fresh" tokens summed over the transcript ------------------
# input + cache_creation + output; cache READS are excluded on purpose — they
# cost ~10% of the regular price and would inflate the number ~10x.
spent=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  spent=$(jq -rs '[.[] | .message.usage? // empty
    | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.output_tokens // 0)]
    | add // 0' "$transcript" 2>/dev/null)
fi

# --- assemble the line ----------------------------------------------------------
sep="${DIM} | ${RST}"
line="${CYAN_B}${model}${RST}"

[ -n "$branch" ] && line="$line$sep${MAGENTA}⎇ ${branch}${dirty}${RST}"

if [ "$ctx_size" -gt 0 ] 2>/dev/null; then
  used=$((ctx_in + ctx_out))
  left=$((ctx_size - used))
  c=$(pct_color "$ctx_pct")
  line="$line$sep${c}ctx $(fmt_tok "$used")/$(fmt_tok "$ctx_size") · left $(fmt_tok "$left")${RST}"
fi

[ -n "$spent" ] && line="$line$sep${BLUE}spent $(fmt_tok "$spent")${RST}"

if [ -n "$rl5" ]; then
  seg="$(pct_color "$rl5")5h ${rl5}%${RST}"
  t5=$(fmt_ts "$rl5_at" '%H:%M'); [ -n "$t5" ] && seg="$seg${DIM}→${t5}${RST}"
  line="$line$sep$seg"
fi
if [ -n "$rl7" ]; then
  seg="$(pct_color "$rl7")7d ${rl7}%${RST}"
  t7=$(fmt_ts "$rl7_at" '%a %H:%M'); [ -n "$t7" ] && seg="$seg${DIM}→${t7}${RST}"
  line="$line$sep$seg"
fi

printf '%s' "$line"
