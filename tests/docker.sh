#!/usr/bin/env bash
# Run tests/run.sh in a throwaway Arch Linux container.
# Needs Docker. From Windows, run it from WSL or Git Bash.
# Usage: tests/docker.sh [CONFIG relative to the repo]   (default: tests/ci.json)
set -euo pipefail

REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
CONFIG=${1:-tests/ci.json}

# The repo is mounted read-only and copied in, so the test cannot touch it.
# makepkg refuses to run as root, so the test runs as user "tester" with sudo.
docker run --rm -t -v "$REPO:/src:ro" archlinux:latest bash -euo pipefail -c "
  pacman -Syu --noconfirm --needed sudo git base-devel >/dev/null
  useradd -m tester
  echo 'tester ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/tester
  cp -r /src /home/tester/dotfiles
  chown -R tester:tester /home/tester/dotfiles
  su - tester -c 'cd ~/dotfiles && bash tests/run.sh $CONFIG'
"
