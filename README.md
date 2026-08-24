# MU/TH/UR

MU/TH/UR is a compact interactive Bash baseline with a restrained operator-console theme. It configures history, XDG paths, completion, safe file operations, shell presentation, a few system helpers, and optional modern tools without taking over unrelated applications.

This baseline intentionally contains no AI profile manager or chat integration. It also avoids automatic directory changes, automatic key loading, duplicated aliases, rollback files, generated reports, and migration scaffolding.

## Install

Clone the repository to `~/.config/mu-th-ur`, run `~/.config/mu-th-ur/install.sh`, then start a fresh Bash session. The installer preserves a regular existing `~/.bashrc` as a timestamped backup and links this repository's `bashrc` into place.

## Core commands

- `mother-status`, `mother-reload`, `mother-disconnect`: status and session controls.
- `airlock`: revoke sudo and request a session lock when `loginctl` is available.
- `uplink-status`, `uplink-add`, `uplink-reset`: explicit SSH identity controls.
- `start-ssh-agent`: start a dedicated agent only when requested; it never prompts for or loads a key.
- `mkcd`, `up`, `ll`, `search`: navigation, listing, and search helpers.
- `gs`, `gd`, `gl`: the retained high-frequency Git shortcuts.
- `net-local`, `net-public`, `scan-proc`, `scan-disk`, `path`: small diagnostics.

Aliases are limited to `..`, `...`, interactive `cp`/`mv`/`rm`, and conditional replacements for `ls` and `cat` when `eza` or `bat` is installed.

Set `MOTHER_BANNER=1` to show `mother-status` when an interactive shell starts. The default is quiet. Starship and zoxide are enabled when installed; zoxide keeps the restored Ctrl+F directory search binding.

## Validate

Run `bash tests/validate.sh`.

## License

Apache-2.0. See `LICENSE`.
