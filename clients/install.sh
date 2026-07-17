#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$HOME/.codex-huihui" "$HOME/.claude-huihui" "$HOME/.local/bin"

ln -sfn "$repo_dir/clients/codex/config.toml" "$HOME/.codex-huihui/config.toml"
ln -sfn "$repo_dir/clients/codex/model-catalog.json" "$HOME/.codex-huihui/model-catalog.json"
ln -sfn "$repo_dir/clients/codex/codex-huihui" "$HOME/.local/bin/codex-huihui"
ln -sfn "$repo_dir/clients/claude/claude-huihui" "$HOME/.local/bin/claude-huihui"
