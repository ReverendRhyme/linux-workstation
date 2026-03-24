#!/usr/bin/env bash
set -euo pipefail

echo "[+] Installing Ansible..."
sudo apt update
sudo apt install -y ansible git

echo "[+] Running playbook..."
ansible-playbook -i ansible/inventory.yml ansible/site.yml --ask-become-pass
