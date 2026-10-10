#!/bin/sh
# Open files in the parent Neovim when Yazi is running inside it.
# Otherwise start a normal blocking nvim in this terminal.
set -eu

if [ "$#" -eq 0 ]; then
  echo "nvim-open.sh: no files given" >&2
  exit 1
fi

if [ -n "${NVIM:-}" ]; then
  nvim --server "$NVIM" --remote "$@"
  exit 0
fi

exec nvim "$@"
