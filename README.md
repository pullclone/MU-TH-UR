# MU/TH/UR

MU/TH/UR is a compact interactive Bash baseline with an operator-console theme. It configures history, XDG paths, completion, interactive file-operation prompts, shell presentation, and a few system helpers. Modern tools are enabled when installed; the installer does not install packages.

## Compatibility

Linux is the primary environment. The core configuration targets Bash 3.2 and later, including Bash on macOS and BSD. It is not a zsh, fish, or POSIX `sh` configuration. On systems with another default shell, launch Bash explicitly to use it.

Linux diagnostics retain their existing tools. Helpers report unavailable capabilities or failures when the host lacks a compatible command; basic compatibility does not require replacement aliases or extra platform packages. Screen-lock requests require a working `loginctl` session. Optional tools have their own platform and Bash-version requirements.

CI targets Linux, macOS with system Bash and Homebrew Bash when installed, and FreeBSD 15.1. OpenBSD and NetBSD are not CI targets. Consult the latest CI result before treating a platform as verified.

## Install

Clone this repository to `~/.config/mu-th-ur`, then run:

```bash
bash "$HOME/.config/mu-th-ur/install.sh"
```

The installer links `~/.bashrc` to the repository. It preserves an existing regular file or symlink as `~/.bashrc.before-mu-th-ur.TIMESTAMP.RANDOM`, prints that backup path, and leaves symlink targets unchanged. Reinstalling the same link is a no-op. Directory destinations and special files are refused. Keep the repository in place while the link is installed.

The installer does not change login profiles. A Bash login shell reads the first available file among `~/.bash_profile`, `~/.bash_login`, and `~/.profile`; it needs to source `~/.bashrc`. Add this once to the existing selected profile, after any preferences you want MU/TH/UR to inherit:

```bash
if [ -n "${BASH_VERSION:-}" ] && [ -r "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
```

If none of those profiles exists, create `~/.bash_profile` containing the snippet. Creating a new `.bash_profile` when a `.profile` already exists would cause Bash to skip that `.profile`. See [Bash startup files](https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files).

Start a fresh Bash session, or run `source "$HOME/.bashrc"` from an existing interactive Bash shell.

System startup settings are loaded once per shell so reloading MU/TH/UR preserves initialized prompts. Start a fresh shell after changing system startup files.

## Configuration and optional tools

- `MOTHER_BANNER=1` shows system status on startup; the default is quiet.
- `MOTHER_MODE` is a cosmetic status label, defaulting to `SAFE`. It does not enforce a security policy.
- Existing `HISTSIZE`, `HISTFILESIZE`, `HISTTIMEFORMAT`, and `HISTCONTROL` settings are respected. When unset, history defaults to 1,000,000 in-memory entries and a 2,000,000-line history file. Set `HISTSIZE` and `HISTFILESIZE` before sourcing to choose other limits; system defaults may already set them. New commands are appended after each prompt; existing sessions do not automatically import one another's history.
- Set `VISUAL` and `EDITOR` to your preferred installed editor before sourcing.
- `eza`, `bat`, `figlet`, `starship`, and `zoxide` are optional. Starship and zoxide initialize once per shell, so reloading does not duplicate their hooks. Open a fresh shell to reload their initialization after an update. `zoxide` enables the Ctrl+F directory-search binding; its interactive picker also needs `fzf`. Icons need a suitable font.
- Git helpers need `git`; SSH helpers need OpenSSH's `ssh-agent` and `ssh-add`; `net-public` needs `curl` and contacts `https://ifconfig.me` when invoked. Sudo-cache controls require `sudo`.

System bash-completion is used when available and compatible. For an existing Homebrew installation, the following can load its completion package from your Bash startup configuration. It skips Bash versions below 4.2 and does nothing if the loader is absent:

```bash
if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2) )) &&
   [[ -z ${BASH_COMPLETION_VERSINFO:-} && -n ${HOMEBREW_PREFIX:-} &&
      -r $HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh ]]; then
    source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
fi
```

Use this after your existing Homebrew environment setup. See [upstream bash-completion guidance](https://github.com/scop/bash-completion#macos-os-x). Completion is optional; the baseline works without it.

## Core commands

- `mother-status`, `mother-reload`, `mother-disconnect`: status, reload, and sudo-cache controls.
- `airlock`: invalidate the sudo cache and request a session lock when supported. A successful request is not confirmation that a desktop is locked.
- `uplink-status`, `uplink-add`, `uplink-reset`: explicit SSH identity controls.
- `start-ssh-agent`: start or reuse a dedicated agent only when requested; it never prompts for or loads a key. Concurrent starts decline while another invocation is starting the agent; retry afterward.
- `mkcd`, `up`, `ll`, `search`: navigation, listing, and search helpers.
- `gs`, `gd`, `gl`: Git shortcuts.
- `net-local`, `net-public`, `scan-proc`, `scan-disk`, `path`: diagnostics. `scan-disk` includes hidden entries.

`mkcd DIRECTORY` creates and enters that exact path, independent of `CDPATH`. `up` moves one directory upward by default; `up COUNT` accepts one positive integer argument.

`search` passes arguments directly to ripgrep when installed, retaining its full option set. Otherwise, its recursive grep fallback supports individually supplied `-n`, `-i`, `-l`, `-w`, and `-F` options, `-e PATTERN`, and `--` to end option parsing. Common forms are `search -n PATTERN PATH`, `search -n -- PATTERN PATH`, and `search -n -e PATTERN -- PATH`. The fallback defaults paths to the current directory and uses extended regular expressions unless `-F` is supplied. Regex syntax and ignored-file filtering depend on the backend; use `-F` for shared literal matching. Other ripgrep options require ripgrep to be installed.

If an interrupted SSH-agent start leaves a lock directory, first confirm that no start is still running. The empty lock directory named in the error can then be removed with `rmdir` before retrying.

Aliases remain `..`, `...`, interactive `cp`/`mv`/`rm`, and conditional `ls`/`cat` replacements when `eza`/`bat` is installed. Interactive prompts are a convenience; options such as `rm -f` can override them. Use `command ls` or `command cat` when you need the original command's behavior.

## Restore or uninstall

First inspect `readlink "$HOME/.bashrc"` and confirm that it is the MU/TH/UR link you intend to remove. Remove that symlink with `command rm -- "$HOME/.bashrc"`. This leaves the repository and any earlier configuration backup intact.

To restore a previous configuration, move the exact backup printed by the installer back to `~/.bashrc` after removing the MU/TH/UR link:

```bash
command mv -- "$HOME/BACKUP_NAME_FROM_INSTALL_OUTPUT" "$HOME/.bashrc"
```

Replace the placeholder with the actual backup name, including its leading dot. A symlink backup restores the original link itself. If no earlier configuration existed, no backup is needed and `.bashrc` can remain absent. Remove only a profile-sourcing snippet you added and no longer want; do not delete an existing profile. Open a fresh shell to discard MU/TH/UR's in-memory settings.

## Validate

Run `bash tests/validate.sh`. With ShellCheck installed, also run:

```bash
shellcheck -s bash bashrc install.sh tests/*.sh
```

The GitHub Actions workflow runs validation on the listed platforms and ShellCheck on Linux. Actions are pinned to release commit IDs and run with read-only repository permissions; update those pins when adopting newer action releases.

## License

Apache-2.0. See `LICENSE`.
