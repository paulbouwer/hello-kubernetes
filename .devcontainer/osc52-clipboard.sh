#!/usr/bin/env bash
# Copy standard input to the host clipboard with the terminal's OSC 52
# escape sequence. Installed as xclip, because gh looks for xclip to copy
# its one-time code. The devcontainer has no clipboard that reaches the
# host, but the terminal does. OSC 52 can't read the clipboard, so paste
# (-o or -out) fails.
# Usage: echo text | xclip -selection clipboard
set -euo pipefail

for arg in "$@"; do
  case "$arg" in
    -o | -out)
      echo "xclip: paste isn't supported; this xclip copies with OSC 52 only" >&2
      exit 1
      ;;
  esac
done

if ! { : >/dev/tty; } 2>/dev/null; then
  echo "xclip: no terminal to send the OSC 52 copy to" >&2
  exit 1
fi

printf '\e]52;c;%s\a' "$(base64 -w0)" >/dev/tty
