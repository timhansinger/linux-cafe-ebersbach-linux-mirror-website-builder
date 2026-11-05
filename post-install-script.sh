#!/bin/bash

sudo apt-get update && sudo apt-get install -y git && \
tmp_repo="$(mktemp -d -p "${TMPDIR:-/tmp}" lcafe.XXXXXXXX)" && \
bash -c "trap 'trap - EXIT INT TERM; rm -rf -- $tmp_repo' EXIT INT TERM && \
git clone --depth 1 https://github.com/timhansinger/linux-cafe-ebersbach-linux-mint-cinnamon-post-install-script $tmp_repo && \
bash $tmp_repo/run.sh"
