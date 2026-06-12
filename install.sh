#!/usr/bin/env bash
# Installer for claude-code-statusline.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mikasalikh/claude-code-statusline/main/install.sh | bash
#   ./install.sh                # from a local clone
#   ./install.sh --uninstall    # remove the status line (settings backup is kept)
#
# Respects CLAUDE_CONFIG_DIR (defaults to ~/.claude).
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/mikasalikh/claude-code-statusline/main"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SCRIPT_PATH="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

uninstall() {
  if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
    cp "$SETTINGS" "$SETTINGS.bak"
    jq 'del(.statusLine)' "$SETTINGS.bak" > "$SETTINGS"
    info "removed statusLine from $SETTINGS (backup: $SETTINGS.bak)"
  fi
  if [ -f "$SCRIPT_PATH" ]; then
    rm -f "$SCRIPT_PATH"
    info "removed $SCRIPT_PATH"
  fi
  info "uninstalled"
  exit 0
}

[ "${1:-}" = "--uninstall" ] && uninstall

command -v jq >/dev/null 2>&1 || err "jq is required — install it first:
  macOS:         brew install jq
  Debian/Ubuntu: sudo apt install jq
  Fedora:        sudo dnf install jq
  Arch:          sudo pacman -S jq"

mkdir -p "$CLAUDE_DIR"

# Prefer the file next to this script (local clone), otherwise download from GitHub.
src_dir=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)
if [ -n "$src_dir" ] && [ -f "$src_dir/statusline.sh" ] && [ -f "$src_dir/install.sh" ]; then
  cp "$src_dir/statusline.sh" "$SCRIPT_PATH"
  info "installed $SCRIPT_PATH (from local clone)"
else
  curl -fsSL "$REPO_RAW/statusline.sh" -o "$SCRIPT_PATH" || err "download failed"
  info "installed $SCRIPT_PATH (downloaded)"
fi
chmod +x "$SCRIPT_PATH"

# Wire into settings.json, keeping every other setting intact (backup first).
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak"
  jq --arg cmd "$SCRIPT_PATH" '.statusLine = {type: "command", command: $cmd}' \
    "$SETTINGS.bak" > "$SETTINGS"
  info "configured statusLine in $SETTINGS (backup: $SETTINGS.bak)"
else
  jq -n --arg cmd "$SCRIPT_PATH" '{statusLine: {type: "command", command: $cmd}}' > "$SETTINGS"
  info "created $SETTINGS with statusLine"
fi

info "done — the status line appears on the next conversation update (no restart needed)"
