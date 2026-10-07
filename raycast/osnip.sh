#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Optimized Snip
# @raycast.mode silent
# @raycast.packageName osnip
# @raycast.icon ✂️
# @raycast.description Snip a screen region, shrink it to a WebP under 100 KB, copy it to the clipboard
# @raycast.author spiritanand
# @raycast.authorURL https://github.com/spiritanand

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

if ! command -v osnip >/dev/null; then
  echo "osnip is not installed"
  exit 1
fi

exec osnip
