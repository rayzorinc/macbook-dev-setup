#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap script supports macOS only." >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Apple's Command Line Tools. Complete the macOS prompt, then rerun this script."
  xcode-select --install
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew was installed but is not on PATH. Open a new shell and rerun this script." >&2
  exit 1
fi

brew update
brew install ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i localhost, playbook.yml
