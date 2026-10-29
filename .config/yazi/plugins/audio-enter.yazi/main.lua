--- @since 25.5.31
--- @sync entry

local audio_exts = {
	mp3 = true,
	ogg = true,
	oga = true,
	wav = true,
	wave = true,
}

local paplay_exts = {
	ogg = true,
	oga = true,
	wav = true,
	wave = true,
}

local paplay_mimes = {
	["audio/ogg"] = true,
	["audio/wav"] = true,
	["audio/wave"] = true,
	["audio/x-wav"] = true,
	["audio/x-pn-wav"] = true,
}

-- Shared with audio-hover.yazi.
local function state_dir()
	return (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/yazi-audio"
end

local function read_line(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local line = f:read("*l")
	f:close()
	return line
end

local function stop_playback()
	local dir = state_dir()
	local pid = read_line(dir .. "/pid")

	if pid and pid:match("^%d+$") then
		-- SIGTERM is enough for both mpv and paplay/ffplay.
		os.execute("kill " .. pid .. " 2>/dev/null")
	end

	os.remove(dir .. "/pid")
	os.remove(dir .. "/path")
end

local function toggle_command(player)
	return table.concat({
		"sh -c '",
		"state_dir=",
		"${XDG_RUNTIME_DIR:-/tmp}/yazi-audio",
		"; ",
		"pidfile=$state_dir/pid; ",
		"pathfile=$state_dir/path; ",
		"current=$1; ",
		"mkdir -p \"$state_dir\"; ",
		"if [ -f \"$pidfile\" ]; then ",
		"  pid=$(cat \"$pidfile\" 2>/dev/null); ",
		"  if [ -n \"$pid\" ] && kill -0 \"$pid\" 2>/dev/null; then ",
		"    last=$(cat \"$pathfile\" 2>/dev/null); ",
		"    kill \"$pid\" 2>/dev/null || true; ",
		"    rm -f \"$pidfile\" \"$pathfile\"; ",
		"    if [ \"$last\" = \"$current\" ]; then exit 0; fi; ",
		"    for _ in 1 2 3 4 5; do ",
		"      kill -0 \"$pid\" 2>/dev/null || break; ",
		"      sleep 0.05; ",
		"    done; ",
		"  else ",
		"    rm -f \"$pidfile\" \"$pathfile\"; ",
		"  fi; ",
		"fi; ",
		player,
		" -- \"$current\" >/dev/null 2>&1 & ",
		"pid=$!; ",
		"printf '%%s' \"$pid\" > \"$pidfile\"; ",
		"printf '%%s' \"$current\" > \"$pathfile\"",
		"' sh %h",
	}, "")
end

local function play_hovered_audio(file)
	local ext = file.url.ext and string.lower(file.url.ext) or ""
	local mime = file:mime() or ""

	if paplay_exts[ext] or paplay_mimes[mime] then
		ya.emit("shell", { toggle_command("paplay --client-name=yazi-enter-audio"), orphan = true })
	else
		ya.emit("shell", { toggle_command("ffplay -nodisp -autoexit -loglevel error"), orphan = true })
	end
end

local function entry(_, job)
	if job.args and job.args[1] == "stop" then
		stop_playback()
		return
	end

	local hovered = cx.active.current.hovered
	if not hovered then
		return
	elseif hovered.cha.is_dir then
		ya.emit("enter")
		return
	end

	local mime = hovered:mime() or ""
	local ext = hovered.url.ext and string.lower(hovered.url.ext) or ""
	if mime:match("^audio/") or audio_exts[ext] then
		play_hovered_audio(hovered)
	else
		ya.emit("open", { hovered = true })
	end
end

return { entry = entry }
