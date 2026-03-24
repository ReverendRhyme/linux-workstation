#!/usr/bin/env bash
# Gaming module
# Installs gaming stack: Steam, Heroic, MangoHud, etc.
# LEGACY: Ansible role `gaming` is the canonical install path.

install_gaming() {
    log_section "Gaming Stack"
    
    # Update first
    sudo apt update -qq
    
    # Install apt packages
    log_info "Installing gaming packages..."
    install_apt_from_file "$REPO_DIR/config/packages/gaming.txt"
    
    # Install flatpak apps
    log_info "Installing gaming flatpaks..."
    install_flatpak "com.heroicgameslauncher.hgl"
    install_flatpak "net.davidotek.pupgui2"
    install_flatpak "com.discordapp.Discord"
    install_flatpak "com.obsproject.Studio"
    install_flatpak "org.videolan.VLC"
    
    log_info "Gaming stack installed"
}
