#!/usr/bin/env bash
# 3D Printing module
# Installs slicers: OrcaSlicer, Bambu Studio, etc.

install_printing() {
    log_section "3D Printing Stack"
    
    # Update first
    sudo apt update -qq
    
    # Install apt packages
    log_info "Installing 3D printing packages..."
    install_apt_from_file "$REPO_DIR/config/packages/printing.txt"
    
    # OrcaSlicer (AppImage)
    log_info "Installing OrcaSlicer..."
    local orca_url="https://github.com/SoftFever/OrcaSlicer/releases/latest/download/OrcaSlicer-linux-x86_64-1.10.0-release-full.AppImage"
    install_appimage "$orca_url" "OrcaSlicer.AppImage" "/opt"
    
    # Bambu Studio (AppImage)
    log_info "Installing Bambu Studio..."
    local bambu_url="https://github.com/bambulab/BambuStudio/releases/latest/download/bambustudio-linux-gnu-mobile-gtk4-x86_64.AppImage"
    install_appimage "$bambu_url" "BambuStudio.AppImage" "/opt"
    
    # CHITUBOX (AppImage)
    log_info "Installing CHITUBOX..."
    local chitu_url="https://www.gridspace.it/download/CHITUBOX%20Linux%20x64%20v1.10.0.AppImage"
    install_appimage "$chitu_url" "CHITUBOX.AppImage" "/opt"
    
    log_info "3D printing stack installed"
}
