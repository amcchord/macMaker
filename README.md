# macMaker

**Turn any Debian machine into a dedicated Mac OS 9 appliance.**

macMaker transforms a standard Debian system into a seamless Mac OS 9 emulation experience. Boot directly into classic Mac OS with no Linux desktop in sight—just power on and enjoy the nostalgia.

![Mac OS 9](https://img.shields.io/badge/Mac%20OS-9.2.1-blue?style=flat-square)
![QEMU](https://img.shields.io/badge/Powered%20by-QEMU-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## Features

- **One-Line Install** — Get up and running in minutes with a single command
- **Appliance Mode** — Boots directly into Mac OS 9, no Linux desktop visible
- **Web Interface** — Configure RAM, display, boot device, and more from any browser
- **Disk Management** — Create, resize, and manage virtual hard drives
- **Screenshot Capture** — Take screenshots via the web interface
- **USB Passthrough** — Connect physical USB devices to the emulated Mac
- **Silent Boot** — Clean grey boot screen inspired by classic Mac startup
- **Idempotent Updates** — Re-run the installer anytime to update; your data is preserved

---

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/amcchord/macMaker/main/install.sh | sudo bash
```

After installation:
1. **Reboot** the system
2. The machine will boot directly into Mac OS 9
3. Access the web interface at `http://<your-ip>` to configure settings

---

## Requirements

- **Debian** or Debian-based distribution (Ubuntu, etc.)
- **Root access** for installation
- **2GB+ RAM** recommended (512MB allocated to emulator by default)
- **15GB+ disk space** (10GB for virtual disk + OS files)

---

## Web Interface

Access the management interface from any device on your network:

| Page | Description |
|------|-------------|
| **Dashboard** | View emulator status, quick actions |
| **Configuration** | Adjust RAM, resolution, boot device |
| **Disks** | Create and manage virtual hard drives |
| **USB** | Attach/detach USB devices to the emulator |
| **Screenshots** | Capture the current emulator display |

### Configuration Options

| Setting | Description | Default |
|---------|-------------|---------|
| RAM | Memory allocated to Mac OS 9 | 512 MB |
| Boot Device | `c` = Hard Disk, `d` = CD-ROM | CD-ROM |
| Resolution | Display resolution | 1024×768 |
| Sound | Enable audio emulation | Disabled |
| Primary Disk | Main virtual hard drive | macos9.qcow2 |
| CD-ROM | ISO image to mount | macos_921_ppc.iso |

---

## Installation Walkthrough

### Initial Setup

1. Run the installer on a fresh Debian system
2. The installer will:
   - Install QEMU and dependencies
   - Download Mac OS 9.2.1 installation media
   - Create a 10GB virtual hard drive
   - Configure auto-boot into the emulator
   - Set up the web management interface

3. After reboot, you'll see the Mac OS 9 installer
4. Install Mac OS 9 as you would on real hardware
5. Once installed, use the web interface to change boot device from **CD-ROM** to **Hard Disk**
6. Reboot to boot from the installed system

### Updating

Re-run the installer at any time to update:

```bash
curl -fsSL https://raw.githubusercontent.com/amcchord/macMaker/main/install.sh | sudo bash
```

Your configuration, disk images, and screenshots are preserved during updates.

---

## Directory Structure

```
/opt/macemu/
├── config/
│   └── qemu.conf        # Emulator configuration
├── disk/
│   └── macos9.qcow2     # Virtual hard drive
├── iso/
│   └── macos_921_ppc.iso # Installation media
├── rom/                  # ROM files (optional)
├── screenshots/          # Captured screenshots
├── scripts/
│   ├── start-emulator.sh # Main QEMU launcher
│   ├── emu-control.sh    # Emulator control commands
│   └── take-screenshot.sh
└── web/
    └── app.py           # Flask web interface
```

---

## How It Works

macMaker combines several technologies to create a seamless experience:

1. **QEMU** — Emulates a PowerPC Mac (mac99 machine type with OpenBIOS)
2. **Auto-login** — The `macemu` user logs in automatically on tty1
3. **X11 + Openbox** — Minimal window manager runs the emulator fullscreen
4. **Plymouth** — Shows a clean grey boot screen (no Linux boot messages)
5. **Flask** — Powers the web interface for remote management

---

## Tips & Tricks

### Manual Testing

To test the emulator without rebooting:

```bash
su - macemu
startx
```

### Accessing QEMU Monitor

The QEMU monitor socket is available for advanced commands:

```bash
socat - UNIX-CONNECT:/tmp/qemu-monitor.sock
```

### Adding More Disk Space

Use the web interface to create additional virtual drives, or from command line:

```bash
qemu-img create -f qcow2 /opt/macemu/disk/storage.qcow2 20G
```

### Restoring Original Boot

To restore normal Debian boot behavior:

```bash
# Remove auto-login
rm /etc/systemd/system/getty@tty1.service.d/autologin.conf
systemctl daemon-reload

# Restore GRUB
cp /etc/default/grub.macemu.backup /etc/default/grub
update-grub
```

---

## Troubleshooting

### Emulator won't start

- Check logs: `journalctl -u getty@tty1`
- Check X session logs: `cat /tmp/xinitrc.log`
- Verify QEMU is installed: `which qemu-system-ppc`

### Web interface not accessible

- Verify the service is running: `systemctl status macemu-web`
- Check if port 80 is open: `ss -tlnp | grep :80`

### Black screen after boot

- The emulator may be waiting for Mac OS to boot
- Access the web interface and take a screenshot to see current state
- Ensure boot device is set correctly (CD-ROM for install, Hard Disk after)

---

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

---

## License

This project is provided as-is for educational and personal use. Mac OS 9 and related Apple trademarks are property of Apple Inc.

---

## Acknowledgments

- [QEMU](https://www.qemu.org/) — The incredible emulator that makes this possible
- The Mac OS 9 preservation community
- [Archive.org](https://archive.org/) — For preserving ROM files

