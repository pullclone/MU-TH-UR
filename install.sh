#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(CDPATH='' builtin cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source_file="$repo_dir/bashrc"
[[ -n ${HOME:-} && -d $HOME ]] || { printf 'HOME must name an existing directory.\n' >&2; exit 1; }
target="$HOME/.bashrc"
[[ -f $source_file && -r $source_file ]] || { printf 'Cannot read %s\n' "$source_file" >&2; exit 1; }

if [[ -d $target || ( -e $target && ! -f $target && ! -L $target ) ]]; then
    printf 'Refusing unusual destination: %s\n' "$target" >&2
    exit 1
fi
if [[ -L $target && $(command readlink "$target") == "$source_file" ]]; then
    printf 'Already installed: %s -> %s\n' "$target" "$source_file"
    exit 0
fi

backup=''
if [[ -e $target || -L $target ]]; then
    # Reserve a unique sibling name; moving preserves relative symlink targets.
    backup="$(command mktemp "$target.before-mu-th-ur.$(date +%Y%m%d-%H%M%S).XXXXXX")"
    if ! command mv -f -- "$target" "$backup"; then
        command rm -f -- "$backup"
        exit 1
    fi
    printf 'Preserved previous configuration: %s\n' "$backup"
fi

if ! command ln -s -- "$source_file" "$target"; then
    if [[ -n $backup && ! -e $target && ! -L $target ]]; then
        command mv -- "$backup" "$target"
        printf 'Restored previous configuration: %s\n' "$target" >&2
    fi
    exit 1
fi
printf 'Installed MU/TH/UR: %s -> %s\n' "$target" "$source_file"
