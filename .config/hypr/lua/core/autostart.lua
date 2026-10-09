local exec_once = {
  "hyprpm reload -n &",
  "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &",
  "eval $(gnome-keyring-daemon --start) &",
  "uwsm app -- swaync",
  "/usr/libexec/xdg-desktop-portal-hyprland &",
  "/usr/libexec/xdg-desktop-portal &",
  "pactl load-module module-switch-on-connect &",
  "uwsm app -- clipse -listen",
  "uwsm app -- /home/rx/.config/hypr/scripts/waybar-with-lua-shim.sh",
  "uwsm app -- qs",
  "systemctl --user start skwd-walld.service",
  "awww-daemon &",
  "uwsm app -- /usr/lib/geoclue-2.0/demos/agent",
  "(sleep 10 && uwsm app -- openrgb --startminimized --profile default) &",
  "uwsm app -- env -u DISPLAY -u WAYLAND_DISPLAY dropbox-cli start",
  "(for _ in $(seq 1 20); do busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher IsStatusNotifierHostRegistered >/dev/null 2>&1 && break; sleep 1; done; uwsm app -- env QT_QPA_PLATFORM=xcb megasync) &",
  "uwsm app -- syncthing-gtk &",

  -- >>> warmind-launcher >>>
  -- Managed block: warmind-deploy owns every line between these markers and
  -- rewrites them on each deploy. $HOME is resolved by Lua at runtime.
  "uwsm app -- qs -n -d -c " .. os.getenv("HOME") .. "/.config/warmind/launcher",
  "uwsm app -- qs -n -d -c " .. os.getenv("HOME") .. "/.config/warmind/modules/ytactions",
  -- <<< warmind-launcher <<<
}

for _, cmd in ipairs(exec_once) do
  hl.on("hyprland.start", function()
    hl.dispatch(hl.dsp.exec_cmd(cmd))
  end)
end
