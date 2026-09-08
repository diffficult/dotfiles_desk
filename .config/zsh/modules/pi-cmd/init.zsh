# pi-cmd — generate a shell one-liner from the current buffer via `pi`.
#
# Usage: type what you want in plain words, press Alt+e, a braille
# spinner trails the buffer while pi thinks, then the buffer is
# replaced with the generated command (output only, no explanation).
#
# Customization via zstyle (all optional):
#   zstyle ':prezto:module:pi-cmd' model 'opencode-go/qwen3.8-flash'
#   zstyle ':prezto:module:pi-cmd' system-prompt '...'
#   zstyle ':prezto:module:pi-cmd' extra-args '--thinking minimal'

_pi_cmd_zsh() {
  # No `[1] pid` / `done` job noise while pi runs in the background.
  setopt localoptions nomonitor
  if [[ -z "$BUFFER" ]]; then
    return 0
  fi

  if (( ! $+commands[pi] )); then
    zle -M "pi-cmd: 'pi' not found on PATH"
    return 1
  fi

  local _old=$BUFFER
  local model system_prompt shell_name os_name query
  zstyle -s ':prezto:module:pi-cmd' model model || model='opencode-go/qwen3.8-flash'
  shell_name=${SHELL:t}
  [[ -n "$shell_name" ]] || shell_name='zsh'
  os_name=$(uname -s)
  zstyle -s ':prezto:module:pi-cmd' system-prompt system_prompt || system_prompt="Write ONE ${shell_name} (${os_name}) command for the request. Output ONLY the command, nothing else: no fences, no prose, no '\$ ' prefix. Prefer rg over grep, fd over find. Quote paths. Never cd."
  # Give pi working-directory context the buffer alone lacks.
  query="$_old [cwd: $PWD]"

  local -a extra_args
  zstyle -a ':prezto:module:pi-cmd' extra-args extra_args || extra_args=()

  local outf errf pid
  outf=$(mktemp "${TMPDIR:-/tmp}/pi-cmd.out.XXXXXX") || return 1
  errf=$(mktemp "${TMPDIR:-/tmp}/pi-cmd.err.XXXXXX") || { rm -f "$outf"; return 1; }

  # Ctrl-C mid-wait: kill pi, clean up, abort the widget.
  TRAPINT() {
    unfunction TRAPINT 2>/dev/null
    kill $pid 2>/dev/null
    rm -f "$outf" "$errf"
    echoti cnorm 2>/dev/null
    return 130
  }

  pi -p \
    --model "$model" \
    --no-session \
    --no-tools \
    --no-extensions \
    --no-skills \
    --no-prompt-templates \
    --no-themes \
    --no-context-files \
    --system-prompt "$system_prompt" \
    "${extra_args[@]}" \
    -- "$query" >|"$outf" 2>|"$errf" &
  pid=$!

  # Braille sweep U+2840..U+28FF trailing the buffer while pi runs.
  # (`pi -p` prints nothing until done, so there is no partial
  # output to type out — spinner only, then instant replace.)
  local -a frames
  local c
  for (( c = 0x2840; c <= 0x28FF; c++ )); do
    frames+=("${(#)c}")
  done
  local i=0 n=${#frames}
  echoti civis 2>/dev/null
  while kill -0 $pid 2>/dev/null; do
    (( i = (i + 1) % n ))
    BUFFER="$_old ${frames[i+1]}"
    zle -R
    sleep 0.08
  done
  unfunction TRAPINT 2>/dev/null
  echoti cnorm 2>/dev/null

  local ret output err
  wait $pid
  ret=$?
  output=$(<$outf)
  err=$(<$errf)
  rm -f "$outf" "$errf"

  if [[ $ret -eq 0 && -n "$output" ]]; then
    # Strip markdown fences and leading prompt chars, trim each line.
    output=$(printf '%s\n' "$output" | sed -e '/^[[:space:]]*```/d' -e 's/^[[:space:]]*[$%❯>][[:space:]]\{1,\}//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    # Drop leading/trailing blank lines (keeps intentional inner ones).
    local -a lines=("${(@f)output}")
    while (( ${#lines} > 0 )) && [[ -z ${lines[1]} ]]; do
      lines[1]=()
    done
    while (( ${#lines} > 0 )) && [[ -z ${lines[-1]} ]]; do
      lines[-1]=()
    done
    output="${(F)lines}"
  fi

  if [[ $ret -eq 0 && -n "$output" ]]; then
    BUFFER=$output
    zle end-of-line
  else
    BUFFER=$_old
    if [[ -n "$err" ]]; then
      zle -M "pi error: ${err[1,80]}"
    elif [[ -n "$output" ]]; then
      zle -M "pi error: ${output[1,80]}"
    else
      zle -M "pi failed (exit $ret)"
    fi
  fi
}
zle -N _pi_cmd_zsh
bindkey '\ee' _pi_cmd_zsh
