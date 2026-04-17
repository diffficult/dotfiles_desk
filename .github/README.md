# dotfiles_desk

> My desktop, in Git. Bare repo, home directory work tree, plenty of mileage.

This is my personal dotfiles repo, stored as a bare Git repository with
`$HOME` as the work tree.

It is not a framework, and it is not trying to be a polished one-command setup
for strangers on the internet. It is the actual machine I use. Right now the
repo tracks 659 files across 472 commits.

The current center of gravity is Hyprland on Arch Linux, but older XFCE and
i3-era pieces are still here because I still steal from them.

## 🧭 at a glance

- Active desktop: Hyprland + Waybar
- Main terminal: Kitty
- Shell: Zsh with Prezto
- Editor mix: Zed, Vim, Nano
- File managers: Yazi, Ranger, lf, Nemo
- Media stack: mpv, mpd, ncmpcpp
- Repo style: bare Git repo in `~/.dotfiles.git`

## 📁 what is tracked

### desktop and window manager

- `~/.config/hypr`
  Modular Hyprland config split into monitors, environment, general settings,
  rules, autostart, plugins, keybindings, and per-app rule files.
- `~/.config/waybar`
  Dual-monitor Waybar setup with custom modules and scripts for calendar,
  weather, updates, CPU, GPU, disk, and notifications.
- `~/.local/bin/hypr_scripts`
  Lock screen, screenshot, wallpaper, DPMS, and idle-management helpers.

### shell and terminal

- `~/.config/zsh`, `~/.aliasrc`, `~/.config/functions`
  Shell setup built around Prezto, FZF, bat, navi, pay-respects, shared aliases,
  and custom helper functions.
- `~/.config/tmux`, `~/.config/kitty`, `~/.config/wezterm`
  Terminal and tmux setup. Kitty is the main terminal. Tmux is based on
  `gpakosz/.tmux` with a custom Tokyo Night-style theme.

### editors and file managers

- `~/.config/yazi`, `~/.config/ranger`, `~/.config/lf`
  File manager configs. Yazi is the newest setup. Ranger and lf are still kept
  working.
- `~/.config/zed`, `~/.vimrc`, `~/.config/nano`
  Editor configs. Zed and Vim get the most attention right now.

### media and extras

- `~/.config/mpv`, `~/.config/mpd`, `~/.config/ncmpcpp`
  Media playback stack with mpv, mpd, and ncmpcpp.
- `~/.local/bin`
  A large pile of shell utilities, desktop scripts, experiments, and old tools
  that still earn their place.
- `~/.config/xfce4`, `~/.local/bin/xfce4-applets`
  Older XFCE configs and panel applets that I have not thrown away.

## 🖥️ current setup

The active desktop looks roughly like this:

- Window manager: Hyprland
- Bar: Waybar
- Notifications: swaync
- App launcher: rofi
- Terminals: Kitty and WezTerm
- Shell: Zsh with Prezto
- Multiplexer: tmux
- File managers: Yazi, Ranger, lf, Nemo
- Editor: Zed, plus Vim for the old reliable path
- Media: mpv, mpd, ncmpcpp

There are also a few machine-specific touches baked into the config:

- A video lock screen flow built around `hyprlock`, `mpvpaper`, and local aerial
  videos under `/opt/ATV4`
- A time-based `hypridle` switcher that swaps between day and night configs
- Waybar calendar scripts that talk to Google Calendar
- Weather scripts using Open-Meteo
- Wallpaper handling through `awww` and Quickshell helpers

## 📝 recent changes

The recent commit history is mostly small desktop-facing work rather than big
rewrites. The last stretch of commits has focused on:

- Hyprland lockscreen and DPMS fixes
- switching wallpaper handling from `swww` to `awww`
- reworking the Waybar calendar module and its helper scripts
- tweaks to mpd and ncmpcpp
- small editor and theme changes in Zed
- shell alias cleanups and rofi power menu fixes

If you browse the log, that pattern shows up elsewhere too. This repo moves in
small increments.

## ⚠️ dependencies and caveats

This repo assumes a lot. Some examples I found while reviewing it:

- Arch-style package names and tooling such as `pacman`, `yay`, and `paru`
- Hyprland-related tools such as `uwsm`, `hyprpm`, `hypridle`, `hyprlock`,
  `awww`, `mpvpaper`, `swaync`, `clipse`, and `footclient`
- Desktop apps and services such as `dropbox`, `megasync`, `syncthing-gtk`,
  `openrgb`, and `gnome-keyring-daemon`
- local-only files expected at runtime, such as `~/.config/functions/.secrets`,
  `~/.config/waybar/calendar_cred.json`, and cached Google auth tokens
- custom directories like `/opt/ATV4` and `~/Pictures/backgrnds`

So no, I would not call this plug-and-play.

## 📦 bare repo notes

The repo itself lives in `~/.dotfiles.git`, and I manage it with this alias:

```bash
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles.git/ --work-tree=$HOME'
```

The bare repo is configured with `status.showUntrackedFiles = no`, which keeps
the noise down when the work tree is the whole home directory.

Useful commands:

```bash
dotfiles status -uall
dotfiles add .config/hypr/hyprland.conf
dotfiles commit -m "tweak hyprland keybindings"
dotfiles push origin master
```

This README lives at `.github/README.md` on purpose, so GitHub will render it
without forcing a visible `~/README.md` into the home directory.

## 🚚 bootstrap on a new machine

If you want to use the same bare-repo layout:

```bash
git clone --bare git@github.com:diffficult/dotfiles_desk.git "$HOME/.dotfiles.git"
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles.git/ --work-tree=$HOME'
dotfiles checkout
dotfiles config status.showUntrackedFiles no
dotfiles submodule update --init --recursive
```

Submodules currently used here:

- `~/.config/oh-my-tmux`
- `~/.config/yazi/flavors/tokyo-night.yazi`

If checkout complains about existing files in `$HOME`, move the conflicting ones
out of the way first and retry.

## 🙂 final note

This repo is mainly for me. If it helps someone else steal a tmux color, a
Hyprland trick, or a weird little shell function, even better.
