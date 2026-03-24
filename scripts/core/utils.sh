#!/usr/bin/env bash
# Core utility library
# Provides reusable functions for installation and state checking

# Check if package is installed (apt)
is_apt_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Check if package is installed (flatpak)
is_flatpak_installed() {
    flatpak list 2>/dev/null | grep -q "$1"
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Install apt package (idempotent)
install_apt() {
    local pkg="$1"
    if is_apt_installed "$pkg"; then
        log_info "✓ $pkg (already installed)"
        return 0
    fi
    log_info "Installing $pkg..."
    if sudo apt install -y "$pkg" 2>/dev/null; then
        log_info "✓ $pkg installed"
        return 0
    else
        log_warn "✗ $pkg installation failed"
        return 1
    fi
}

# Install multiple apt packages from file (idempotent)
install_apt_from_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "Package file not found: $file"
        return 1
    fi
    
    local failed=0
    while IFS= read -r pkg || [[ -n "$pkg" ]]; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        install_apt "$pkg" || ((failed++))
    done < "$file"
    
    return $failed
}

# Install flatpak app (idempotent)
install_flatpak() {
    local app="$1"
    if is_flatpak_installed "$app"; then
        log_info "✓ $app (flatpak already installed)"
        return 0
    fi
    log_info "Installing flatpak $app..."
    if flatpak install -y flathub "$app" 2>/dev/null; then
        log_info "✓ $app installed"
        return 0
    else
        log_warn "✗ $app flatpak installation failed"
        return 1
    fi
}

# Install multiple flatpak apps from file
install_flatpak_from_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "Flatpak file not found: $file"
        return 1
    fi
    
    local failed=0
    while IFS= read -r app || [[ -n "$app" ]]; do
        [[ -z "$app" || "$app" =~ ^# ]] && continue
        install_flatpak "$app" || ((failed++))
    done < "$file"
    
    return $failed
}

# Download and install AppImage
install_appimage() {
    local url="$1"
    local name="$2"
    local dest="${3:-/opt}"
    
    if [[ -f "$dest/$name" ]]; then
        log_info "✓ $name (already installed)"
        return 0
    fi
    
    log_info "Downloading $name..."
    if curl -L -o "/tmp/$name" "$url" 2>/dev/null; then
        chmod +x "/tmp/$name"
        sudo mv "/tmp/$name" "$dest/"
        log_info "✓ $name installed to $dest/"
        return 0
    else
        log_error "Failed to download $name"
        return 1
    fi
}

# Create directory if not exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        sudo mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

# Add to fstab (idempotent - checks if entry exists)
add_to_fstab() {
    local uuid="$1"
    local mount="$2"
    local fs="${3:-ext4}"
    
    if grep -q "$mount" /etc/fstab 2>/dev/null; then
        log_info "✓ $mount (fstab entry exists)"
        return 0
    fi
    
    echo "UUID=$uuid $mount $fs defaults,nofail 0 2" | sudo tee -a /etc/fstab
    log_info "Added $mount to fstab"
}

# Run command as user (not root)
run_as_user() {
    local cmd="$1"
    sudo -u "$SUDO_USER" bash -c "$cmd" 2>/dev/null || eval "$cmd"
}
