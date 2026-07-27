# Local Prezto Runcoms

This directory contains the active Zsh runcoms for this system. The files are managed by the `dotfiles` bare repository and are symlinked from `$HOME`.

## Structure

| File | Role |
|------|------|
| `zshenv` | Minimal environment bootstrap for every Zsh invocation. |
| `zprofile` | Login-shell environment, XDG paths, structural `PATH`, language/tool locations. |
| `zshrc` | Interactive shell integrations, aliases, functions, widgets, FZF, AI helpers, app completions. |
| `zpreztorc` | Prezto module list and module configuration. |
| `zlogin` | Login-shell post-start hooks and optional TTY output. |
| `zlogout` | Logout hooks. |
| `README.md` | Local map of the runcom layout and keybindings. |
| `MODULES.md` | Custom module inventory and source locations. |

## Load Order

Zsh reads these files in this order for the common shell types:

| Shell type | Files read |
|------------|------------|
| Every Zsh process | `zshenv` |
| Login shell | `zshenv`, `zprofile`, `zshrc`, `zlogin` |
| Interactive non-login shell | `zshenv`, `zshrc` |
| Logout from login shell | `zlogout` |

Prezto itself is loaded from `zshrc` through `${ZDOTDIR:-$HOME}/.zprezto/init.zsh`. Module selection comes from `zpreztorc`.

## Ownership Rules

| Area | Owner |
|------|-------|
| Structural `PATH` | `zprofile` |
| Completion initialization | Prezto `completion` module |
| FZF base setup | Custom `fzf` module |
| Command-not-found handler | `find-the-command` from `zshrc` |
| Shared aliases/functions | `~/.aliasrc` and `~/.config/functions/*` |
| Interactive widgets | `zshrc` and custom modules |

`zshrc` ends with `typeset -gU path` so late interactive initializers cannot reintroduce duplicate `PATH` entries.

## Keybindings

These are the effective bindings loaded in the default interactive keymap.

| Binding | Widget | Function |
|---------|--------|----------|
| `Ctrl-X l` | `clear-keep-buffer` | Clear the screen while preserving the current command buffer. |
| `Ctrl-X c` | `copy-command` | Copy the current command buffer. |
| `Ctrl-X Ctrl-X` | `__pr_inline` | Inline `pay-respects` correction helper. |
| `Alt-e` | `_aichat_zsh` | Rewrite the current command buffer through `aichat -e`. |
| `Ctrl-G` | `_navi_widget` | Open Navi cheatsheets and insert the selected command. |
| `Alt-a` | `fzf_alias` | Search shell aliases with FZF. |
| `Ctrl-T` | `fzf-file-widget` | Insert files selected with FZF. |
| `Alt-c` | `fzf-cd-widget` | Change directory using FZF. |
| `Ctrl-R` | `fzf-history-widget` | Search shell history with FZF. |
| `Ctrl-P` | `history-substring-search-up` | Search backward through matching history. |
| `Ctrl-N` | `history-substring-search-down` | Search forward through matching history. |
| `Up` | `history-substring-search-up` | Search backward through matching history. |
| `Down` | `history-substring-search-down` | Search forward through matching history. |
| `Space` | `abbr-expand-and-insert` | Expand a `zsh-abbr` abbreviation before inserting a space. |

## FZF Git Keybindings

`fzf-git.sh` adds Git-specific widgets under the `Ctrl-G` prefix.

| Binding | Widget | Function |
|---------|--------|----------|
| `Ctrl-G f` / `Ctrl-G Ctrl-F` | `fzf-git-files-widget` | Select Git-tracked files. |
| `Ctrl-G b` / `Ctrl-G Ctrl-B` | `fzf-git-branches-widget` | Select Git branches. |
| `Ctrl-G t` / `Ctrl-G Ctrl-T` | `fzf-git-tags-widget` | Select Git tags. |
| `Ctrl-G r` / `Ctrl-G Ctrl-R` | `fzf-git-remotes-widget` | Select Git remotes. |
| `Ctrl-G h` / `Ctrl-G Ctrl-H` | `fzf-git-hashes-widget` | Select commit hashes. |
| `Ctrl-G s` / `Ctrl-G Ctrl-S` | `fzf-git-stashes-widget` | Select stashes. |
| `Ctrl-G l` / `Ctrl-G Ctrl-L` | `fzf-git-lreflogs-widget` | Select reflog entries. |
| `Ctrl-G w` / `Ctrl-G Ctrl-W` | `fzf-git-worktrees-widget` | Select worktrees. |
| `Ctrl-G e` / `Ctrl-G Ctrl-E` | `fzf-git-each_ref-widget` | Select refs. |
| `Ctrl-G ?` / `Ctrl-G Ctrl-?` | `fzf-git-?list_bindings-widget` | Show the FZF Git binding list. |

## Verification

Use these after changing the runcoms:

```sh
zsh -ic exit
zsh -lic exit
zsh -ic 'typeset -A seen; typeset -a dupes; for d in $path; do if [[ -n ${seen[$d]:-} ]]; then dupes+=("$d"); else seen[$d]=1; fi; done; print -rl -- $dupes'
zsh -ic 'bindkey | rg "clear-keep-buffer|copy-command|fzf-|_navi_widget|__pr_inline|_aichat_zsh|history-substring|abbr"'
```

Expected result: no startup warnings and no duplicate `PATH` output.
