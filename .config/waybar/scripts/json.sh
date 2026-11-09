#!/usr/bin/env bash
# One JSON escaper for every Waybar bar script. Sourced, never executed.
#
# Why this file exists: every bar script assembles its payload with string
# interpolation, so a value containing `"`, a `\` or a control character produces
# malformed JSON - and Waybar renders nothing at all for a module that prints
# malformed JSON. The module silently vanishes, with no error anywhere. That is
# the same silent-disappearance shape the deploy engine's verify.sh `rg` bug had,
# in a place nobody would be looking: the seven scripts run every few seconds and
# realistic values (a temperature, a mount point, a GPU name) do not contain
# those characters.
#
# Contract:
#   wb_json_escape VALUE   -> one complete, quoted JSON string
#   wb_json_escape <<< "$V" -> the same, for a value too large to pass as argv
#
# A bar script uses it like this, so the payload is a template plus escaped
# values rather than one interpolated string:
#
#   echo "{\"text\":$(wb_json_escape "$DISPLAY_TEXT"),\"class\":$(wb_json_escape "$CLASS")}"
#
# Escaped: `"`, `\`, and every control character a JSON string cannot hold
# literally (newline, tab, CR, backspace, form feed and the rest, as their short
# escape or \u00XX). A literal backslash-n in a value therefore stays a
# backslash-n after the round trip - it is data, not a line break. That is the
# whole reason a bar script's tooltip is assembled with REAL newlines and
# escaped once at the end: a tooltip written as "\n" already looks like an
# escape sequence, and escaping it here would turn every line break on the bar
# into visible \n text.
#
# No runtime dependency, deliberately. `jq` would be the obvious answer and is
# the wrong one: it would add a dependency to scripts that have none today (and
# weather-openmeteo.sh has to degrade to an error module without jq, so the
# escaper cannot depend on it), and the engine is plain bash by decision. This
# is bash parameter expansion and nothing else - no subprocess per value.
#
# What it does NOT handle, stated rather than implied:
#   * A NUL byte cannot survive a bash variable at all, so it cannot survive
#     here. Bash drops it and warns on assignment; that is a property of the
#     language, not a gap in this file.
#   * Bytes that are not valid UTF-8 are passed through unchanged. A value is
#     already expected to be text; repairing invalid encodings is not this
#     function's job.
#
# Sourced from the script's own directory, via ${BASH_SOURCE[0]} - the same
# derivation expose-toggle.sh and the deploy engine use. Not $HOME, and not a
# path written out by hand: a hardcoded copy is exactly how two bar scripts end
# up with two escapers.

# Escape one value into a complete JSON string, quotes included. Printing the
# closing quote last is what makes the `$( )` capture at the call site safe:
# command substitution strips trailing newlines, and a value that ends in a
# newline here is already escaped rather than lost.
wb_json_escape() {
  local s char escape
  if (($# == 1)); then
    s=$1
  elif (($# == 0)); then
    # `<<<` appends one newline that is not part of the value, so exactly
    # that one is removed and the rest is escaped verbatim. The `printf x`
    # sentinel is what makes "exactly one" possible: without it, command
    # substitution would strip every trailing newline first. A value that
    # genuinely ends in a newline therefore loses one on this path - use
    # the argument form for those, which has no such loss.
    s=$(
      cat
      printf x
    )
    s=${s%x}
    s=${s%$'\n'}
  else
    printf 'wb_json_escape: expected one value, or none for stdin, got %d\n' "$#" >&2
    return 1
  fi

  # Backslash first, or the backslashes introduced by the later rules would be
  # escaped a second time.
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  s=${s//$'\b'/\\b}
  s=${s//$'\f'/\\f}
  # The remaining C0 controls have no short escape, so they become \u00XX.
  # DEL (0x7f) is legal inside a JSON string and is deliberately left alone.
  local code
  for ((code = 1; code < 32; code++)); do
    case $code in
    8 | 9 | 10 | 12 | 13) continue ;;
    esac
    # `%b` with a literal format, not a variable one: shellcheck is right that
    # a variable format string is a bug waiting to happen, and the octal it
    # needs is the one thing here that cannot be a fixed literal.
    char=$(printf '%b' "\\0$(printf '%03o' "$code")")
    escape=$(printf '\\u%04x' "$code")
    s=${s//"$char"/"$escape"}
  done

  printf '"%s"' "$s"
}
