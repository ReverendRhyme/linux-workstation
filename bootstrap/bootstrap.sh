#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "[+] Installing Ansible..."
sudo apt update
sudo apt install -y ansible git

echo "[+] Running playbook..."
ansible-playbook -i "$REPO_DIR/ansible/inventory.yml" "$REPO_DIR/ansible/site.yml" --ask-become-pass
