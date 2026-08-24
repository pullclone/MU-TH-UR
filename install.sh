#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target="$HOME/.bashrc"
timestamp="$(date +%Y%m%d-%H%M%S)"
if [[ -e $target && ! -L $target ]]; then
    command cp -p -- "$target" "$target.before-mu-th-ur.$timestamp"
fi
command ln -sfn -- "$repo_dir/bashrc" "$target"
printf 'Installed MU/TH/UR: %s -> %s\n' "$target" "$repo_dir/bashrc"
