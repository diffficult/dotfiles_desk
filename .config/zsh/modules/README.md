# 🛠️ ZSH Third-Party Modules Documentation

Up to date third party modules I'm using in `zsh` with `prezto` ✨

## 📦 Module Overview

| 📝 Module Name | 🔗 Repository URL |
|------------|----------------|
| aichat | https://github.com/sigoden/aichat |
| ask-zsh | https://github.com/diffficult/ask-zsh |
| fabric | https://github.com/diffficult/fabric-zsh |
| fzf | https://github.com/junegunn/fzf |
| fzf-alias | https://github.com/junegunn/fzf-alias |
| zsh-abbr | https://github.com/olets/zsh-abbr |

## ⚙️ Module Configurations

### 🤖 aichat
> AI-powered command-line chat tool.

#### Load module on `zpreztorc`

```zsh

# prezto modules
 zstyle ':prezto:load' pmodule \
   'environment' \
   'terminal' \
   'editor' \
   ...
   'aichat' \
   'prompt'

```

### 🔍 ask-zsh
> Interactive command-line tool for searching shell commands.

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
> Command-line fuzzy finder.

#### Load module on `zpreztorc`

```zsh

# prezto modules
 zstyle ':prezto:load' pmodule \
   'environment' \
   'terminal' \
   'editor' \
   ...
   'contrib-prompt' \
   'fzf' \
   ...
   'prompt'

```

#### Settings for `zpreztorc`

```zsh

#
# FZF SETTINGS
#

# Since we're using fd in zshrc, we can remove or comment the ag setting
# zstyle ':prezto:module:fzf' fzf-default-command 'ag -l --hidden -g "" --ignore .git'
zstyle ':prezto:module:fzf' disable-key-bindings 'no'
zstyle ':prezto:module:fzf' disable-completion 'yes'
zstyle ':prezto:module:fzf' height '40%'
zstyle ':prezto:module:fzf' preview 'yes'
zstyle ':prezto:module:fzf' tmux 'yes'
zstyle ':prezto:module:fzf' reverse 'yes'
zstyle ':prezto:module:fzf' color-scheme 'JellyX'

```

#### Settings for `zshrc`

```zsh

#
# FZF CONFIGURATION
#
export FZF_BASE=/usr/share/fzf

# Source FZF completion
if [ -f "/usr/share/fzf/completion.zsh" ]; then
  source "/usr/share/fzf/completion.zsh"
fi

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

# FZF completion functions
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# FZF-git integration
source ~/dev/gits/fzf-git.sh/fzf-git.sh

# BAT integration for preview
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced FZF completion customization
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo \$'{}"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "bat -n --color=always --line-range :500 {}" "$@" ;;
  esac
}


```


### ⚡ fzf-alias
> Fuzzy command alias finder and executor.

#### Load module on `zpreztorc`

```zsh

# prezto modules
 zstyle ':prezto:load' pmodule \
   'environment' \
   'terminal' \
   'editor' \
   ...
   'contrib-prompt' \
   'fzf' \
   'fzf-alias' \
   ...
   'prompt'

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

Currently all cloned in `~/.config/zsh/modules`

## 🔄 Maintenance

To update all modules, use your package manager's update command. Keep an eye on the official repositories for updates and breaking changes.

---
*Made with 💝 for the mentally unstable terminal user*
