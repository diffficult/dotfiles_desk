# 🛠️ ZSH Third-Party Modules Documentation

Up to date third party modules I'm using in `zsh` with `prezto` ✨

## 📦 Module Overview

| 📝 Module Name | 🔗 Repository URL |
|------------|----------------|
| ask-zsh | https://github.com/diffficult/ask-zsh |
| fabric | https://github.com/diffficult/fabric-zsh |
| fzf | https://github.com/lildude/fzf-prezto (local copy) |
| fzf-alias | https://github.com/thirteen37/fzf-alias |
| pi-cmd | local module (no upstream) |
| zsh-abbr | https://github.com/olets/zsh-abbr |

## ⚙️ Module Configurations

### 🔍 ask-zsh
> Interactive command-line tool for searching shell commands.

Symlinked in from `~/dev/mygits/ask-zsh` (not stored in `dotfiles`).

#### Load module on `zpreztorc`

```zsh

# prezto modules
 zstyle ':prezto:load' pmodule \
   'environment' \
   'terminal' \
   'editor' \
   ...
   'ask-zsh' \
   ...
   'prompt'

```

### 🧰 fabric
> fabric is an open-source framework for augmenting humans using AI.

Symlinked in from `~/dev/mygits/fabric-zsh` (not stored in `dotfiles`).

#### Load module on `zpreztorc`

```zsh

# prezto modules
 zstyle ':prezto:load' pmodule \
   'environment' \
   'terminal' \
   'editor' \
   ...
   'fabric' \
   ...
   'prompt'

```

### 🎯 fzf
> Prezto wrapper around [junegunn's fzf](https://github.com/junegunn/fzf) (MIT, Colin Seymour): detects the install, wires completion/keybindings, and applies `zstyle` defaults.

Local copy tracked in `dotfiles` at `~/.config/zsh/modules/fzf`. The stale `.git` indirection inside it is intentionally untracked.

#### Load module on `zpreztorc`

```zsh

# prezto modules
 zstyle ':prezto:load' pmodule \
   'environment' \
   'terminal' \
   'editor' \
   ...
   'fzf' \
   'fzf-alias' \
   ...
   'prompt'

```

#### How it splits with `zshrc`

The module owns shell integration (`fzf.plugin.zsh` finds `FZF_BASE`, sources completion/keybindings unless disabled via `zstyle`). `zshrc` owns the look and data sources:

```zsh

export FZF_BASE=/usr/share/fzf

# Tokyo Night color theme for FZF
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
--color=fg:#c0caf5,bg:#1a1b26,hl:#ff9e64 \
--color=fg+:#c0caf5,bg+:#292e42,hl+:#ff9e64 \
--color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff \
--color=marker:#9ece6a,spinner:#9ece6a,header:#9ece6a"

# FD integration for FZF
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# BAT/eza previews + fzf-git.sh + _fzf_comprun live in zshrc too
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

```

### ⚡ fzf-alias
> Fuzzy alias finder and executor. Press `Alt-a` to search aliases through FZF.

Tracked in `dotfiles` at `~/.config/zsh/modules/fzf-alias` (upstream: https://github.com/thirteen37/fzf-alias, `.git` itself untracked). Requires `fzf`.

#### Load module on `zpreztorc`

```zsh

# prezto modules
 zstyle ':prezto:load' pmodule \
   'environment' \
   'terminal' \
   'editor' \
   ...
   'fzf' \
   'fzf-alias' \
   ...
   'prompt'

```

### ✨ pi-cmd
> Local module: type a request in plain words, press `Alt-e`, and the buffer is rewritten with the `pi -p` result (`opencode-go/qwen3.8-flash` by default, no tools/extensions).

Tracked in `dotfiles` at `~/.config/zsh/modules/pi-cmd`. Replaces the retired `aichat-ng` module (still on disk, untracked, not loaded). Requires the `pi` command at runtime.

#### Load module on `zpreztorc`

```zsh

# prezto modules
 zstyle ':prezto:load' pmodule \
   'environment' \
   'terminal' \
   'editor' \
   ...
   'ask-zsh' \
   'pi-cmd' \
   'prompt'

```

#### Optional `zstyle` knobs

```zsh
zstyle ':prezto:module:pi-cmd' model 'opencode-go/qwen3.8-flash'
zstyle ':prezto:module:pi-cmd' system-prompt '...'
zstyle ':prezto:module:pi-cmd' extra-args '--thinking minimal'
```

### ✨ zsh-abbr
> ZSH abbreviation manager.

#### Load module on `zpreztorc`

```zsh
zstyle ':prezto:load' pmodule \
   'environment' \
   ...
   'history-substring-search' \
   'zsh-abbr' \
   ...
   'prompt'


```

## 📥 Installation

Local modules live in `~/.config/zsh/modules` and are tracked in the `dotfiles` bare repo (`dotfiles` alias). Exceptions: `ask-zsh` and `fabric` are symlinks into `~/dev/mygits/*` and stay out of `dotfiles`.

Current `zpreztorc` order:

```zsh
environment
terminal
editor
history
directory
spectrum
utility
ssh
git
completion
syntax-highlighting
history-substring-search
zsh-abbr
autosuggestions
fzf
fzf-alias
zoxide
fabric
ask-zsh
pi-cmd
prompt
```

## 🔄 Maintenance

`fzf` / `fzf-alias` / `pi-cmd` update through `dotfiles` like any other tracked file:

```sh
dotfiles status
dotfiles add .config/zsh/modules/fzf-alias/fzf-alias.plugin.zsh
dotfiles commit -m "✨ feat(zsh): ..."
dotfiles push
```

Upstream checks for the non-dotfiles sources:

```sh
git -C ~/.zprezto/contrib remote -v
git -C ~/.config/zsh/modules/zsh-abbr remote -v
git -C ~/.config/zsh/modules/fzf-alias remote -v
git -C ~/dev/mygits/fabric-zsh remote -v
git -C ~/dev/mygits/ask-zsh remote -v
```

---
*Made with 💝 for the mentally unstable terminal user*
