#!/usr/bin/env bash
# Development module
# Installs development tools: Docker, Python, etc.

install_dev() {
    log_section "Development Tools"
    
    # Update first
    sudo apt update -qq
    
    # Install apt packages
    log_info "Installing dev packages..."
    install_apt_from_file "$REPO_DIR/config/packages/dev.txt"
    
    # Add user to docker group
    if command_exists docker && ! groups | grep -q docker; then
        log_info "Adding user to docker group..."
        sudo usermod -aG docker "$USER"
        log_info "You may need to log out and back in for docker access"
    fi
    
    log_info "Development tools installed"
}
