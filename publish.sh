#!/bin/bash
set -e

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
  "/opt/linux-mirror-site/$MARKDOWN" \
  -o "$TARGET/index.html"

install -m 644 /opt/linux-mirror-site/setup.sh "$TARGET/setup.sh"
install -m 644 "/opt/linux-mirror-site/$CSS" "$TARGET/style.css"
