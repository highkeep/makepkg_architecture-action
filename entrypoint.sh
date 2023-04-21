#!/bin/bash
set -euo pipefail

# Added builder as seen in edlanglois/pkgbuild-action
# mainly for permissions
useradd builder -m
# When installing dependencies, makepkg will use sudo
# Give user `builder` passwordless sudo access
echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

# Give all users (particularly builder) full access to these files
chmod -R a+rw .

echo "${INPUT_ARCHITECTURE}"
echo "${INPUT_TPLMAKEPKGCONF}"
echo "${INPUT_TPLPACMANCONF}"
echo "${INPUT_PKG}"
echo "${INPUT_UPDATEPKG}"
