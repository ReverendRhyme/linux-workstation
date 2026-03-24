#!/usr/bin/env bash
set -e
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y
flatpak update -y
