#!/usr/bin/env bash
# CAD module
# Installs CAD/3D design tools: Blender, FreeCAD, etc.
# LEGACY: Ansible role `cad` is the canonical install path.

install_cad() {
    log_section "CAD/3D Design Stack"
    
    # Update first
    sudo apt update -qq
    
    # Install apt packages
    log_info "Installing CAD packages..."
    install_apt_from_file "$REPO_DIR/config/packages/cad.txt"
    
    # Install flatpak Blender (latest)
    log_info "Installing Blender flatpak..."
    install_flatpak "org.blender.Blender"
    
    # Install Fusion 360 via cryinkfly's script
    if ! command_exists fusion360; then
        log_info "Installing Fusion 360..."
        if curl -L https://raw.githubusercontent.com/cryinkfly/Autodesk-Fusion-360-for-Linux/main/files/setup/autodesk_fusion_installer_x86-64.sh -o /tmp/fusion_installer.sh 2>/dev/null; then
            chmod +x /tmp/fusion_installer.sh
            sudo /tmp/fusion_installer.sh --install --default
            rm -f /tmp/fusion_installer.sh
            log_info "Fusion 360 installation complete"
        else
            log_warn "Fusion 360 installation failed - requires active license"
        fi
    else
        log_info "Fusion 360 (already installed)"
    fi
    
    log_info "CAD stack installed"
}
