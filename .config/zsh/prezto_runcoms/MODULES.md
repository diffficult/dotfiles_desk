# Custom Prezto Modules

This file documents the non-upstream modules active in `zpreztorc`. Standard Prezto modules still come from `~/.zprezto/modules`.

## Module Search Paths

`zpreztorc` enables these extra module directories:

| Path | Purpose |
|------|---------|
| `~/.zprezto/contrib` | External Prezto-compatible modules from `belak/prezto-contrib`. |
| `~/.config/zsh/modules` | Local and third-party custom modules for this machine. |

## Active Custom Modules

| Module | Load location | Backing source | Purpose |
|--------|---------------|----------------|---------|
| `fzf` | `~/.config/zsh/modules/fzf` | Local copy of an FZF Prezto module | Owns FZF shell integration, completion, keybindings, preview defaults, and `FZF_DEFAULT_COMMAND`. |
| `fzf-alias` | `~/.config/zsh/modules/fzf-alias` | <https://github.com/thirteen37/fzf-alias> | Adds `Alt-a` alias search through FZF. |
| `zsh-abbr` | `~/.config/zsh/modules/zsh-abbr` | <https://github.com/olets/zsh-abbr> | Fish-style abbreviations that expand in the command buffer. |
| `zoxide` | `~/.zprezto/contrib/zoxide` | <https://github.com/belak/prezto-contrib> | Integrates `zoxide` directory jumping into Prezto. |
| `fabric` | `~/.config/zsh/modules/fabric` -> `~/dev/mygits/fabric-zsh` | <https://github.com/diffficult/fabric-zsh> | Adds Fabric completions, helper functions, pattern/model/session discovery, and cache helpers. |
| `ask-zsh` | `~/.config/zsh/modules/ask-zsh` -> `~/dev/mygits/ask-zsh` | <https://github.com/diffficult/ask-zsh> | Adds an AI-assisted command generator for Zsh/Prezto. |
| `pi-cmd` | `~/.config/zsh/modules/pi-cmd` | Local module | Adds `Alt-e` to rewrite the current command buffer through `pi -p` (`opencode-go/qwen3.8-flash`, no tools/extensions). |

## Active Module Order

Current `zpreztorc` order:

```zsh
environment
terminal
editor
history
spectrum
utility
ssh
completion
syntax-highlighting
history-substring-search
zsh-abbr
fzf
fzf-alias
zoxide
fabric
ask-zsh
pi-cmd
prompt
```

## Notes

| Module | Note |
|--------|------|
| `fzf` | Completion is enabled from the module. Manual sourcing from `zshrc` was removed to avoid duplicate setup. |
| `command-not-found` | Intentionally not loaded. The system currently uses `find-the-command` from `/usr/share/doc/find-the-command/ftc.zsh`. |
| `fabric` | The active path is a symlink into `~/dev/mygits/fabric-zsh`. |
| `ask-zsh` | The active path is a symlink into `~/dev/mygits/ask-zsh`. |
| `pi-cmd` | Local-only module. It requires the `pi` command to be available at runtime. |

## Update Checks

Use these commands to inspect module sources:

```sh
git -C ~/.zprezto/contrib remote -v
git -C ~/.config/zsh/modules/zsh-abbr remote -v
git -C ~/.config/zsh/modules/fzf-alias remote -v
git -C ~/dev/mygits/fabric-zsh remote -v
git -C ~/dev/mygits/ask-zsh remote -v
```

The local `fzf` module has a stale `.git` indirection in this system and is not currently managed by the `dotfiles` bare repository.
