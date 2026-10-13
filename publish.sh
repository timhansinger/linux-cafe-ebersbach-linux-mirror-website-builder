#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Install prerequisites
apt install pandoc

# MARKDOWN=index.md
MARKDOWN=index-german.md
CSS="github-markdown-light.css"
TARGET="/srv/apt-mirror/mirror"

install -d "$TARGET"

# pandoc --list-highlight-styles
pandoc -s \
  --template=github-template.html \
  --highlight-style=pygments \
  --metadata title="Linux Mirror Setup" \
  -c style.css \
  "$SCRIPT_DIR/$MARKDOWN" \
  -o "$TARGET/index.html"

install -m 644 "$SCRIPT_DIR/setup.sh" "$TARGET/setup.sh"
install -m 644 "$SCRIPT_DIR/$CSS" "$TARGET/style.css"
