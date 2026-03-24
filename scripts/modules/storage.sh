#!/usr/bin/env bash
# Storage module
# Configures drive mounts and storage layout
# LEGACY: Ansible role `storage` is the canonical install path.

MOUNT_GAMES="${MOUNT_GAMES:-/mnt/games}"
MOUNT_STORAGE="${MOUNT_STORAGE:-/mnt/storage}"
MOUNT_BACKUPS="${MOUNT_BACKUPS:-/mnt/backups}"

install_storage() {
    log_section "Storage Configuration"
    
    # Run drive recommendation
    log_info "Running drive detection..."
    if [[ -x "$REPO_DIR/scripts/drive-recommend.sh" ]]; then
        bash "$REPO_DIR/scripts/drive-recommend.sh" --detect || true
    fi
    
    # Create mount points
    log_info "Creating mount points..."
    ensure_dir "$MOUNT_GAMES"
    ensure_dir "$MOUNT_STORAGE"
    ensure_dir "$MOUNT_BACKUPS"
    
    # Check for existing mounts
    if ! mountpoint -q "$MOUNT_GAMES" 2>/dev/null; then
        log_warn "$MOUNT_GAMES not mounted - run drive-recommend.sh to configure"
    fi
    
    if ! mountpoint -q "$MOUNT_STORAGE" 2>/dev/null; then
        log_warn "$MOUNT_STORAGE not mounted - run drive-recommend.sh to configure"
    fi
    
    log_info "Storage configuration complete"
}

configure_drive_mounts() {
    local drive="$1"
    local mount="$2"
    local label="$3"
    
    log_section "Configuring $label Mount"
    
    # Get UUID
    local uuid
    uuid=$(sudo blkid -s UUID -o value "$drive" 2>/dev/null)
    
    if [[ -z "$uuid" ]]; then
        log_error "Could not get UUID for $drive"
        return 1
    fi
    
    log_info "Drive: $drive"
    log_info "UUID: $uuid"
    log_info "Mount: $mount"
    
    # Create mount point
    ensure_dir "$mount"
    
    # Add to fstab
    add_to_fstab "$uuid" "$mount"
    
    # Mount
    if mountpoint -q "$mount"; then
        log_info "$mount already mounted"
    else
        log_info "Mounting $mount..."
        sudo mount "$mount" || log_warn "Failed to mount $mount"
    fi
    
    log_info "$label mount configured"
}
