--- @since 25.5.31

-- Plays the hovered audio file while the previewer is active.
--
-- Yazi cancels the previewer (and kills its child process) as soon as the
-- cursor moves to another entry or Yazi exits, so playback lifecycle is
-- handled by the preview system rather than by us.
--
-- The player PID/path are published to the shared `yazi-audio` state dir so
-- audio-enter.yazi can toggle playback with Enter and stop it with Esc/quit.

-- 0.08s debounce: while holding j/k only the file you settle on is played.
local DEBOUNCE = 0.08

-- Kill the previous player (whichever plugin started it), then exec mpv with
-- this shell's PID so the shared pidfile points at the player itself.
local SCRIPT = [[
state_dir=${XDG_RUNTIME_DIR:-/tmp}/yazi-audio
mkdir -p "$state_dir"
if [ -f "$state_dir/pid" ]; then
	old=$(cat "$state_dir/pid" 2>/dev/null)
	case $old in
	''|*[!0-9]*) ;;
	*) kill "$old" 2>/dev/null; sleep 0.03 ;;
	esac
fi
printf '%s' "$$" > "$state_dir/pid"
printf '%s' "$1" > "$state_dir/path"
exec mpv --no-config --no-video --no-terminal --really-quiet --volume=80 \
	--force-window=no --audio-display=no \
	--loop-file=no --loop-playlist=no --keep-open=no --idle=no -- "$1"
]]

local function basename(path)
	return path:match("([^/]+)$") or path
end

local function play(path)
	local cmd = Command("sh")
		:arg("-c")
		:arg(SCRIPT)
		:arg("sh")
		:arg(path)
		:stdin(Command.NULL)
		:stdout(Command.NULL)
		:stderr(Command.NULL)

	local _, err = cmd:status()
	if err then
		ya.err("audio-hover: failed to start mpv: " .. tostring(err))
	end
end

local M = {}

function M:peek(job)
	local path = tostring(job.file.url)

	ya.preview_widget(job, {
		ui.Line("♪ " .. basename(path)):area(job.area),
	})

	-- Let rapid cursor movement cancel this peek before spawning a player.
	ya.sleep(DEBOUNCE)
	play(path)
end

function M:seek() end

return M
