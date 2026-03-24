#!/usr/bin/env bash
# Security module
# Installs security tools: UFW firewall, fail2ban, etc.
# LEGACY: Ansible role `security` is the canonical install path.

install_security() {
    log_section "Security Stack"
    
    # Update first
    sudo apt update -qq
    
    # Install security packages
    log_info "Installing security packages..."
    install_apt "ufw"
    install_apt "fail2ban"
    install_apt "apt-listbugs"
    
    # Configure UFW defaults
    log_info "Configuring UFW firewall..."
    if ! sudo ufw status | grep -q "Status: active"; then
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw enable
        log_info "UFW firewall enabled"
    else
        log_info "UFW firewall already active"
    fi
    
    # Configure fail2ban
    log_info "Configuring fail2ban..."
    if [[ ! -f /etc/fail2ban/jail.local ]]; then
        sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
        sudo systemctl enable fail2ban
        sudo systemctl start fail2ban
        log_info "fail2ban enabled"
    else
        log_info "fail2ban already configured"
    fi
    
    log_info "Security stack installed"
}
