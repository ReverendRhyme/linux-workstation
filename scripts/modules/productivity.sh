#!/usr/bin/env bash
# Productivity module
# Installs productivity stack: Office, cloud sync, communication

install_productivity() {
    log_section "Productivity Stack"
    
    # Update first
    sudo apt update -qq
    
    # Install apt packages
    log_info "Installing productivity packages..."
    install_apt_from_file "$REPO_DIR/config/packages/productivity.txt"
    
    # Install flatpak apps
    log_info "Installing productivity flatpaks..."
    install_flatpak "com.1password.1Password"
    install_flatpak "com.slack.Slack"
    install_flatpak "us.zoom.Zoom"
    install_flatpak "md.obsidian.Obsidian"
    install_flatpak "com.spotify.Client"
    
    log_info "Productivity stack installed"
}
