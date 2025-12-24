#!/bin/bash
#
# Mac OS 9 Emulation System Installer
# Idempotent installation script for Debian
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/amcchord/macMaker/main/install.sh | sudo bash
#
# This script can be run multiple times safely:
#   - Fresh install: Full setup with all components
#   - Update: Preserves config, disk images, and screenshots; updates scripts and web interface
#
set -e

# ============================================================================
# Configuration
# ============================================================================
MACEMU_VERSION="1.0.0"
MACEMU_DIR="/opt/macemu"
MACEMU_USER="macemu"
GITHUB_REPO="https://github.com/amcchord/macMaker.git"
GITHUB_BRANCH="main"
ISO_URL="https://mcchord.net/static/macos_921_ppc.iso"
ROM_URL="https://archive.org/download/mac_rom_archive_-_as_of_8-19-2011/mac_rom_archive_-_as_of_8-19-2011.zip"
DISK_SIZE="10G"
DEFAULT_RAM="512"

# ============================================================================
# Colors for output
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# ============================================================================
# SECTION 0: Pre-flight checks
# ============================================================================
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root (use sudo)"
        echo ""
        echo "Usage: curl -fsSL https://raw.githubusercontent.com/amcchord/macMaker/main/install.sh | sudo bash"
        exit 1
    fi
}

check_debian() {
    log_step "Checking operating system..."
    
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot detect operating system. /etc/os-release not found."
        exit 1
    fi
    
    # Source os-release to get OS info
    . /etc/os-release
    
    # Check if it's Debian or a Debian-based distro
    IS_DEBIAN=false
    if [ "$ID" = "debian" ]; then
        IS_DEBIAN=true
    fi
    if [ "$ID_LIKE" = "debian" ]; then
        IS_DEBIAN=true
    fi
    # Also check for ID_LIKE containing debian (e.g., "ubuntu debian")
    case "$ID_LIKE" in
        *debian*) IS_DEBIAN=true ;;
    esac
    
    if [ "$IS_DEBIAN" = false ]; then
        log_error "This installer requires Debian or a Debian-based distribution."
        echo ""
        echo "Detected OS: $PRETTY_NAME"
        echo "Expected: Debian, Ubuntu, or other Debian-based system"
        echo ""
        exit 1
    fi
    
    log_info "Detected OS: $PRETTY_NAME"
}

detect_install_mode() {
    log_step "Detecting installation mode..."
    
    INSTALL_MODE="fresh"
    
    # Check for existing installation markers
    if [ -d "$MACEMU_DIR" ]; then
        if [ -f "$MACEMU_DIR/config/qemu.conf" ]; then
            INSTALL_MODE="update"
            log_info "Existing installation detected - running in UPDATE mode"
            log_info "User configuration, disk images, and screenshots will be preserved"
        else
            log_info "Partial installation detected - running in FRESH mode"
        fi
    else
        log_info "No existing installation - running in FRESH mode"
    fi
}

# ============================================================================
# SECTION 1: Package Installation
# ============================================================================
install_packages() {
    log_step "Installing required packages..."
    
    # Update package lists
    apt-get update
    
    # Install packages - apt-get install is idempotent
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        qemu-system-ppc \
        git \
        xorg \
        openbox \
        plymouth \
        plymouth-themes \
        python3-flask \
        python3-pillow \
        unzip \
        wget \
        curl \
        xinit \
        x11-xserver-utils \
        xdotool \
        netpbm \
        imagemagick \
        socat \
        unclutter \
        sudo
    
    log_info "Packages installed successfully"
}

# ============================================================================
# SECTION 2: Clone or update GitHub repository
# ============================================================================
setup_repository() {
    log_step "Setting up repository from GitHub..."
    
    if [ -d "$MACEMU_DIR/.git" ]; then
        # Existing git repo - pull updates
        log_info "Updating existing repository..."
        cd "$MACEMU_DIR"
        
        # Stash any local changes to tracked files
        git stash --quiet 2>/dev/null || true
        
        # Fetch and reset to match remote
        git fetch origin "$GITHUB_BRANCH"
        git reset --hard "origin/$GITHUB_BRANCH"
        
        log_info "Repository updated to latest version"
    else
        # Fresh clone needed
        if [ -d "$MACEMU_DIR" ]; then
            # Directory exists but not a git repo - back up user data
            log_info "Backing up existing files before clone..."
            
            BACKUP_DIR="/tmp/macemu_backup_$$"
            mkdir -p "$BACKUP_DIR"
            
            # Backup user data directories
            if [ -d "$MACEMU_DIR/config" ]; then
                cp -r "$MACEMU_DIR/config" "$BACKUP_DIR/" 2>/dev/null || true
            fi
            if [ -d "$MACEMU_DIR/disk" ]; then
                cp -r "$MACEMU_DIR/disk" "$BACKUP_DIR/" 2>/dev/null || true
            fi
            if [ -d "$MACEMU_DIR/screenshots" ]; then
                cp -r "$MACEMU_DIR/screenshots" "$BACKUP_DIR/" 2>/dev/null || true
            fi
            if [ -d "$MACEMU_DIR/iso" ]; then
                cp -r "$MACEMU_DIR/iso" "$BACKUP_DIR/" 2>/dev/null || true
            fi
            
            # Remove old directory and clone fresh
            rm -rf "$MACEMU_DIR"
        fi
        
        log_info "Cloning repository from GitHub..."
        git clone --branch "$GITHUB_BRANCH" "$GITHUB_REPO" "$MACEMU_DIR"
        
        # Restore backed up user data if it exists
        if [ -d "/tmp/macemu_backup_$$" ]; then
            log_info "Restoring backed up user data..."
            
            if [ -d "/tmp/macemu_backup_$$/config" ]; then
                cp -r "/tmp/macemu_backup_$$/config"/* "$MACEMU_DIR/config/" 2>/dev/null || true
            fi
            if [ -d "/tmp/macemu_backup_$$/disk" ]; then
                mkdir -p "$MACEMU_DIR/disk"
                cp -r "/tmp/macemu_backup_$$/disk"/* "$MACEMU_DIR/disk/" 2>/dev/null || true
            fi
            if [ -d "/tmp/macemu_backup_$$/screenshots" ]; then
                mkdir -p "$MACEMU_DIR/screenshots"
                cp -r "/tmp/macemu_backup_$$/screenshots"/* "$MACEMU_DIR/screenshots/" 2>/dev/null || true
            fi
            if [ -d "/tmp/macemu_backup_$$/iso" ]; then
                mkdir -p "$MACEMU_DIR/iso"
                cp -r "/tmp/macemu_backup_$$/iso"/* "$MACEMU_DIR/iso/" 2>/dev/null || true
            fi
            
            rm -rf "/tmp/macemu_backup_$$"
            log_info "User data restored successfully"
        fi
        
        log_info "Repository cloned successfully"
    fi
}

# ============================================================================
# SECTION 3: Create macemu user
# ============================================================================
create_user() {
    log_step "Setting up macemu user..."
    
    if id "$MACEMU_USER" &>/dev/null; then
        log_info "User $MACEMU_USER already exists"
    else
        useradd -m -s /bin/bash "$MACEMU_USER"
        log_info "Created user $MACEMU_USER"
    fi
    
    # Add user to necessary groups
    usermod -aG video,audio,input,tty "$MACEMU_USER" 2>/dev/null || true
    
    # Allow macemu user to start X
    if ! grep -q "allowed_users=anybody" /etc/X11/Xwrapper.config 2>/dev/null; then
        mkdir -p /etc/X11
        echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
        echo "needs_root_rights=yes" >> /etc/X11/Xwrapper.config
    fi
    
    log_info "User configuration complete"
}

# ============================================================================
# SECTION 4: Create directory structure
# ============================================================================
create_directories() {
    log_step "Creating directory structure..."
    
    mkdir -p "$MACEMU_DIR/iso"
    mkdir -p "$MACEMU_DIR/rom"
    mkdir -p "$MACEMU_DIR/disk"
    mkdir -p "$MACEMU_DIR/config"
    mkdir -p "$MACEMU_DIR/web/templates"
    mkdir -p "$MACEMU_DIR/web/static"
    mkdir -p "$MACEMU_DIR/scripts"
    mkdir -p "$MACEMU_DIR/screenshots"
    
    chown -R "$MACEMU_USER:$MACEMU_USER" "$MACEMU_DIR"
    
    log_info "Directory structure created"
}

# ============================================================================
# SECTION 5: Download Mac OS 9 ISO
# ============================================================================
download_iso() {
    log_step "Checking Mac OS 9 ISO..."
    
    ISO_PATH="$MACEMU_DIR/iso/macos_921_ppc.iso"
    
    if [ -f "$ISO_PATH" ]; then
        log_info "ISO already exists at $ISO_PATH"
    else
        log_info "Downloading Mac OS 9.2.1 ISO from mcchord.net..."
        wget --progress=bar:force -O "$ISO_PATH" "$ISO_URL"
        chown "$MACEMU_USER:$MACEMU_USER" "$ISO_PATH"
        log_info "ISO downloaded successfully"
    fi
}

# ============================================================================
# SECTION 6: Download and extract ROM files
# ============================================================================
download_rom() {
    log_step "Checking ROM files..."
    
    ROM_ZIP="$MACEMU_DIR/rom/mac_roms.zip"
    ROM_DIR="$MACEMU_DIR/rom"
    
    # Check if we already have a usable ROM
    if [ -f "$ROM_DIR/mac99.rom" ]; then
        log_info "ROM already configured"
        return
    fi
    
    # Download ROM archive if not present
    if [ ! -f "$ROM_ZIP" ]; then
        log_info "Downloading ROM archive..."
        wget -O "$ROM_ZIP" "$ROM_URL"
    fi
    
    # Extract ROMs
    log_info "Extracting ROM files..."
    cd "$ROM_DIR"
    unzip -o "$ROM_ZIP" || true
    
    # Find a suitable New World ROM for mac99
    ROM_FOUND=""
    
    # Search for ROM files - look for Power Mac G3 ROMs specifically for mac99
    for rom_file in "$ROM_DIR"/*G3*.ROM "$ROM_DIR"/*G3*.rom "$ROM_DIR"/*Power*.ROM "$ROM_DIR"/*Power*.rom; do
        if [ -f "$rom_file" ]; then
            size=$(stat -c%s "$rom_file" 2>/dev/null || echo "0")
            if [ "$size" -ge 1000000 ] && [ "$size" -le 5000000 ]; then
                ROM_FOUND="$rom_file"
                log_info "Found potential ROM: $rom_file (size: $size bytes)"
                break
            fi
        fi
    done
    
    # If no G3 ROM found, look for any large ROM file
    if [ -z "$ROM_FOUND" ]; then
        for rom_file in "$ROM_DIR"/*.ROM "$ROM_DIR"/*.rom; do
            if [ -f "$rom_file" ]; then
                size=$(stat -c%s "$rom_file" 2>/dev/null || echo "0")
                if [ "$size" -ge 1000000 ] && [ "$size" -le 5000000 ]; then
                    ROM_FOUND="$rom_file"
                    log_info "Found potential ROM: $rom_file (size: $size bytes)"
                    break
                fi
            fi
        done
    fi
    
    if [ -n "$ROM_FOUND" ]; then
        cp "$ROM_FOUND" "$ROM_DIR/mac99.rom"
        log_info "ROM configured: $ROM_DIR/mac99.rom"
    else
        log_warn "Could not auto-detect ROM. Will attempt to run without explicit ROM file."
        log_warn "QEMU mac99 uses built-in OpenBIOS which may work without ROM."
    fi
    
    chown -R "$MACEMU_USER:$MACEMU_USER" "$ROM_DIR"
}

# ============================================================================
# SECTION 7: Create virtual disk
# ============================================================================
create_virtual_disk() {
    log_step "Checking virtual disk..."
    
    DISK_PATH="$MACEMU_DIR/disk/macos9.qcow2"
    
    if [ -f "$DISK_PATH" ]; then
        log_info "Virtual disk already exists (preserved)"
    else
        log_info "Creating $DISK_SIZE virtual disk..."
        qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
        chown "$MACEMU_USER:$MACEMU_USER" "$DISK_PATH"
        log_info "Virtual disk created"
    fi
}

# ============================================================================
# SECTION 8: Create QEMU configuration (only if not exists)
# ============================================================================
create_qemu_config() {
    log_step "Checking QEMU configuration..."
    
    CONFIG_FILE="$MACEMU_DIR/config/qemu.conf"
    
    if [ -f "$CONFIG_FILE" ]; then
        log_info "QEMU configuration already exists (preserved)"
    else
        log_info "Creating default QEMU configuration..."
        cat > "$CONFIG_FILE" << 'EOF'
# Mac OS 9 QEMU Configuration
# Edit these values and restart the emulator

# Memory in MB (128-1024 recommended)
RAM_MB=512

# Boot device: d=cdrom, c=hard disk
# Use 'd' for initial install, then 'c' after installation
BOOT_DEVICE=d

# Display resolution
SCREEN_WIDTH=1024
SCREEN_HEIGHT=768

# VNC display number (for screenshots)
VNC_DISPLAY=0

# Enable sound (0=disabled, 1=enabled)
SOUND_ENABLED=0
EOF
        chown "$MACEMU_USER:$MACEMU_USER" "$CONFIG_FILE"
        log_info "QEMU configuration created"
    fi
}

# ============================================================================
# SECTION 9: Set executable permissions on scripts
# ============================================================================
setup_scripts() {
    log_step "Setting up emulator scripts..."
    
    # Make all scripts executable
    chmod +x "$MACEMU_DIR/scripts/"*.sh 2>/dev/null || true
    chmod +x "$MACEMU_DIR/scripts/"*.py 2>/dev/null || true
    chmod +x "$MACEMU_DIR/web/app.py" 2>/dev/null || true
    
    # Set ownership
    chown -R "$MACEMU_USER:$MACEMU_USER" "$MACEMU_DIR/scripts"
    chown -R "$MACEMU_USER:$MACEMU_USER" "$MACEMU_DIR/web"
    
    log_info "Emulator scripts configured"
}

# ============================================================================
# SECTION 10: Create Plymouth theme (Mac grey boot)
# ============================================================================
create_plymouth_theme() {
    log_step "Creating Plymouth boot theme..."
    
    THEME_DIR="/usr/share/plymouth/themes/macgrey"
    mkdir -p "$THEME_DIR"
    
    # Create theme script
    cat > "$THEME_DIR/macgrey.script" << 'PLYMOUTH_SCRIPT'
# Mac Grey Plymouth Theme

# Set the grey background color
Window.SetBackgroundTopColor(0.74, 0.74, 0.74);
Window.SetBackgroundBottomColor(0.74, 0.74, 0.74);

# Optional: Add a simple centered logo or message
message_sprite = Sprite();
message_sprite.SetPosition(Window.GetWidth() / 2, Window.GetHeight() / 2, 1);

fun message_callback(text) {
    # Suppress all messages for clean boot
}

Plymouth.SetMessageFunction(message_callback);

fun display_normal_callback() {
    # Normal boot display
}

fun display_password_callback(prompt, bullets) {
    # Password prompt (if needed)
}

Plymouth.SetDisplayNormalFunction(display_normal_callback);
Plymouth.SetDisplayPasswordFunction(display_password_callback);
PLYMOUTH_SCRIPT

    # Create theme descriptor
    cat > "$THEME_DIR/macgrey.plymouth" << 'PLYMOUTH_DESC'
[Plymouth Theme]
Name=Mac Grey
Description=Clean grey boot screen like classic Mac OS
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/macgrey
ScriptFile=/usr/share/plymouth/themes/macgrey/macgrey.script
PLYMOUTH_DESC

    # Set as default theme
    if command -v plymouth-set-default-theme &> /dev/null; then
        plymouth-set-default-theme macgrey || true
    else
        if [ -f /etc/plymouth/plymouthd.conf ]; then
            sed -i 's/^Theme=.*/Theme=macgrey/' /etc/plymouth/plymouthd.conf
        else
            mkdir -p /etc/plymouth
            echo "[Daemon]" > /etc/plymouth/plymouthd.conf
            echo "Theme=macgrey" >> /etc/plymouth/plymouthd.conf
        fi
    fi
    
    # Update initramfs to include the theme
    update-initramfs -u || log_warn "Could not update initramfs"
    
    log_info "Plymouth theme created"
}

# ============================================================================
# SECTION 11: Configure GRUB for silent boot
# ============================================================================
configure_grub() {
    log_step "Configuring GRUB for silent boot..."
    
    GRUB_FILE="/etc/default/grub"
    
    if [ -f "$GRUB_FILE" ]; then
        # Backup original (only if no backup exists)
        if [ ! -f "$GRUB_FILE.macemu.backup" ]; then
            cp "$GRUB_FILE" "$GRUB_FILE.macemu.backup"
        fi
        
        # Update GRUB settings for silent boot
        sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' "$GRUB_FILE"
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash vt.global_cursor_default=0 loglevel=0"/' "$GRUB_FILE"
        
        # Add hidden timeout if not present
        if ! grep -q "GRUB_TIMEOUT_STYLE" "$GRUB_FILE"; then
            echo "GRUB_TIMEOUT_STYLE=hidden" >> "$GRUB_FILE"
        else
            sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' "$GRUB_FILE"
        fi
        
        # Disable recovery menu
        if ! grep -q "GRUB_DISABLE_RECOVERY" "$GRUB_FILE"; then
            echo 'GRUB_DISABLE_RECOVERY="true"' >> "$GRUB_FILE"
        fi
        
        # Set graphics mode
        sed -i 's/^#GRUB_GFXMODE=.*/GRUB_GFXMODE=1024x768/' "$GRUB_FILE"
        if ! grep -q "^GRUB_GFXMODE=" "$GRUB_FILE"; then
            echo "GRUB_GFXMODE=1024x768" >> "$GRUB_FILE"
        fi
        
        # Keep graphics payload through Linux boot
        if ! grep -q "GRUB_GFXPAYLOAD_LINUX" "$GRUB_FILE"; then
            echo "GRUB_GFXPAYLOAD_LINUX=keep" >> "$GRUB_FILE"
        fi
        
        # Update GRUB
        update-grub
        
        log_info "GRUB configured for silent boot"
    else
        log_warn "GRUB configuration file not found"
    fi
}

# ============================================================================
# SECTION 12: Configure auto-login
# ============================================================================
configure_autologin() {
    log_step "Configuring auto-login..."
    
    # Create getty override directory
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    
    # Create auto-login configuration
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $MACEMU_USER --noclear %I \$TERM
EOF
    
    # Create .bash_profile for macemu user to start X automatically
    BASH_PROFILE="/home/$MACEMU_USER/.bash_profile"
    cat > "$BASH_PROFILE" << 'EOF'
# Auto-start X on tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx -- -nocursor 2>/dev/null
fi
EOF
    
    chown "$MACEMU_USER:$MACEMU_USER" "$BASH_PROFILE"
    
    log_info "Auto-login configured"
}

# ============================================================================
# SECTION 13: Configure X session
# ============================================================================
configure_xsession() {
    log_step "Configuring X session..."
    
    # Create .xinitrc for macemu user
    XINITRC="/home/$MACEMU_USER/.xinitrc"
    cat > "$XINITRC" << 'EOF'
#!/bin/bash

# Log file for debugging
exec >> /tmp/xinitrc.log 2>&1
echo "=== Starting X session at $(date) ==="

# Set grey background immediately
xsetroot -solid "#BDBDBD"

# Disable screen blanking and power management
xset s off
xset -dpms
xset s noblank

# Hide cursor after 1 second of inactivity
unclutter -idle 1 -root &

# Start a minimal window manager
openbox &
OPENBOX_PID=$!

# Wait for openbox to start
sleep 2

# Start the emulator in a loop (restart if it crashes)
while true; do
    echo "Starting emulator at $(date)"
    /opt/macemu/scripts/start-emulator.sh
    EXIT_CODE=$?
    echo "Emulator exited with code $EXIT_CODE at $(date)"
    
    # If emulator exits with 0 (user quit), break the loop
    if [ $EXIT_CODE -eq 0 ]; then
        echo "Clean exit, stopping X session"
        break
    fi
    
    # Wait a moment before restarting
    sleep 2
done

# Cleanup
kill $OPENBOX_PID 2>/dev/null
echo "=== X session ended at $(date) ==="
EOF
    
    chown "$MACEMU_USER:$MACEMU_USER" "$XINITRC"
    chmod +x "$XINITRC"
    
    log_info "X session configured"
}

# ============================================================================
# SECTION 14: Create systemd services
# ============================================================================
create_systemd_services() {
    log_step "Creating systemd services..."
    
    # Web interface service
    cat > /etc/systemd/system/macemu-web.service << EOF
[Unit]
Description=Mac OS 9 Emulator Web Interface
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$MACEMU_DIR/web
ExecStart=/usr/bin/python3 $MACEMU_DIR/web/app.py
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload and enable services
    systemctl daemon-reload
    systemctl enable macemu-web.service
    
    # Restart web service to pick up any changes
    systemctl restart macemu-web.service || log_warn "Could not start web service"
    
    log_info "Systemd services configured"
}

# ============================================================================
# SECTION 15: Save version info
# ============================================================================
save_version_info() {
    log_step "Saving version information..."
    
    VERSION_FILE="$MACEMU_DIR/.version"
    cat > "$VERSION_FILE" << EOF
MACEMU_VERSION=$MACEMU_VERSION
INSTALL_DATE=$(date -Iseconds)
INSTALL_MODE=$INSTALL_MODE
EOF
    
    chown "$MACEMU_USER:$MACEMU_USER" "$VERSION_FILE"
    log_info "Version information saved"
}

# ============================================================================
# MAIN INSTALLATION SEQUENCE
# ============================================================================
main() {
    echo ""
    echo "========================================"
    echo "  Mac OS 9 Emulator Installer v$MACEMU_VERSION"
    echo "========================================"
    echo ""
    
    # Pre-flight checks
    check_root
    check_debian
    detect_install_mode
    
    echo ""
    echo "========================================"
    echo "  Starting Installation"
    echo "========================================"
    echo ""
    
    # Core installation steps
    install_packages
    setup_repository
    create_user
    create_directories
    download_iso
    download_rom
    create_virtual_disk
    create_qemu_config
    setup_scripts
    
    # System configuration
    create_plymouth_theme
    configure_grub
    configure_autologin
    configure_xsession
    create_systemd_services
    save_version_info
    
    # Get IP address for display
    IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -z "$IP_ADDR" ]; then
        IP_ADDR="<your-ip>"
    fi
    
    echo ""
    echo "========================================"
    echo -e "  ${GREEN}Installation Complete!${NC}"
    echo "========================================"
    echo ""
    
    if [ "$INSTALL_MODE" = "update" ]; then
        echo "The emulator has been updated to version $MACEMU_VERSION"
        echo ""
        echo "Your configuration, disk images, and screenshots were preserved."
        echo ""
        echo "The web interface has been restarted with the latest changes."
        echo ""
    else
        echo "The Mac OS 9 emulator has been installed successfully!"
        echo ""
        echo "Next steps:"
        echo "  1. Reboot the system to boot into the emulator"
        echo "  2. Access the web interface at http://$IP_ADDR"
        echo "  3. Install Mac OS 9 from the CD-ROM"
        echo "  4. After installation, change boot device to Hard Disk in the web config"
        echo ""
        echo "To test the emulator manually (without reboot):"
        echo "  su - $MACEMU_USER"
        echo "  startx"
        echo ""
    fi
    
    echo "To update in the future, run:"
    echo "  curl -fsSL https://raw.githubusercontent.com/amcchord/macMaker/main/install.sh | sudo bash"
    echo ""
}

# Run main function
main "$@"
