# WrathOS Project State

> This document is the source of truth for the current state of WrathOS.
> Update it with every release. Claude should read this at the start of any session.

## Identity
- **Name:** WrathOS
- **Tagline:** Forging ahead reliably, Gaming at the edge.
- **Version:** v0.1-alpha
- **Base:** Debian Trixie
- **Kernel:** CachyOS 6.19.9-cachy (BORE scheduler, ThinLTO, FUTEX2)
- **Desktop:** KDE Plasma 6.3 on Wayland, SDDM
- **Installer:** Calamares 3.3.14
- **GitHub:** https://github.com/Vaeldus/WrathOS
- **Maintainer:** Vaeldus / zxd (zxdsystems@gmail.com)

---

## Build Environment
- **Build machine:** WrathOS-Build VM
- **User:** zxd
- **SSH:** `ssh -p 2222 zxd@127.0.0.1`
- **Build dir:** `~/WrathOS/build`
- **APT repo:** `~/wrathos/apt-repo`
- **gh-pages:** `~/wrathos/gh-pages`
- **GitHub Pages APT:** `https://vaeldus.github.io/WrathOS/apt`
- **GPG Key ID:** `EFFDF5373BF6A7B841F3FF8B4F25D97415661FC2`

> **Note:** Build VM clock slips after sleep. Always run `sudo timedatectl set-ntp true` before building.

---

## Rebuild Command
```bash
sudo timedatectl set-ntp true
cd ~/WrathOS/build
sudo lb clean --all
lb config \
  --distribution trixie \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-images iso-hybrid \
  --bootloader grub-efi \
  --debian-installer none \
  --apt-indices false \
  --memtest none \
  --bootappend-live "boot=live components quiet splash"
sudo lb build 2>&1 | tee ~/wrathos/build.log
```

---

## Key File Locations

| File | Purpose |
|------|---------|
| `~/WrathOS/configurator/wrathos-configurator.py` | Configurator source |
| `~/WrathOS/build/config/includes.chroot/usr/bin/wrathos-configurator` | Configurator in ISO |
| `~/WrathOS/build/config/includes.chroot/usr/bin/wrathos-firstboot-system.sh` | First boot systemd script |
| `~/WrathOS/build/config/includes.chroot/usr/bin/wrathos-set-wallpaper.sh` | Wallpaper script |
| `~/WrathOS/build/config/hooks/live/` | Build hooks |
| `~/WrathOS/build/config/package-lists/wrathos.list.chroot` | Base package list |
| `~/WrathOS/build/config/includes.chroot/etc/calamares/` | Calamares config |
| `~/WrathOS/build/config/includes.chroot/etc/calamares/modules/shellprocess.conf` | Post-install commands |
| `~/WrathOS/build/config/includes.chroot/etc/calamares/modules/finished.conf` | Post-install reboot options |
| `~/WrathOS/packages/wrathos-bundle-*/` | Bundle metapackages |
| `~/WrathOS/build/config/includes.chroot/opt/wrathos-bundles/` | Bundle debs in ISO |
| `~/wrathos/apt-repo/` | Local APT repo |
| `~/wrathos/gh-pages/` | GitHub Pages repo |

---

## Hook Reference

| Hook | Purpose |
|------|---------|
| `0001` | Install CachyOS kernel debs |
| `0003` | Fix live boot kernel filename (binary) |
| `0004` | GRUB theme |
| `0005` | Plymouth theme |
| `0006` | OS identity (WrathOS, not Debian) |
| `0007` | Wallpaper — replaces Next wallpaper files, appends to plasma defaults |
| `0008` | Calamares desktop + wrathos-setup.desktop in skel/Desktop |
| `0009` | Remove Debian installer shortcuts |
| `0010` | Fastfetch config |
| `0012` | Enable wrathos-firstboot.service |
| `0013` | Disable KDE welcome center (replace binary with no-op) |
| `0014` | GRUB live branding (chroot) |
| `0015` | GRUB binary branding — W logo splash (binary) |
| `0016` | Bundle repo setup (dpkg-scanpackages) |
| `0017` | Flatpak setup — install flatpak, add Flathub system remote |

---

## Bundle System

Bundles are defined in `wrathos-configurator.py` as a BUNDLES list with:
- `id` — unique identifier
- `packages` — list of apt packages to install
- `flatpak` — list of (app_id, app_name) tuples for Flatpak installs
- `name`, `desc`, `recommended`, `default`

Installation uses a single `pkexec bash /tmp/wrathos-install.sh` call.
The script contains all apt installs followed by all Flatpak installs.
`set -e` is NOT used — failures are non-fatal per line.
Installed bundles tracked at `~/.wrathos-bundles-installed`.

### Current Bundles

| Bundle | APT Packages | Flatpak Apps |
|--------|-------------|--------------|
| gpu | mesa-vulkan-drivers, libvulkan1, vulkan-tools | — |
| steam | flatpak, libvulkan1 | com.valvesoftware.Steam |
| perf | gamemode, mangohud | — |
| codecs | ffmpeg, gstreamer plugins, flatpak | org.videolan.VLC |
| launchers | lutris, flatpak | Heroic, Bottles |
| emulation | dolphin-emu, flatpak | org.libretro.RetroArch |

---

## First Boot Flow

1. Calamares installs system
2. shellprocess.conf runs: GRUB install, EFI fallback copy, Flatpak/Flathub setup, WrathOS APT repo setup
3. User manually reboots (restart option shown, unchecked by default)
4. First boot: `wrathos-firstboot.service` runs `wrathos-firstboot-system.sh` as root
5. Script creates autostart files, desktop icon, app menu entry
6. Script touches `/var/lib/wrathos-firstboot-done` and exits
7. User logs into KDE — configurator auto-launches, wallpaper sets

> **Critical:** `wrathos-firstboot-system.sh` must check `boot=live` at the top or it will reboot the live environment.

---

## Wallpaper System

- WrathOS wallpaper replaces KDE's default Next wallpaper files at `/usr/share/wallpapers/Next/contents/images/`
- Hook 0007 also appends `[Wallpaper]` section to `/usr/share/plasma/shells/org.kde.plasma.desktop/contents/defaults`
- **Critical:** Hook 0007 must APPEND to the defaults file, never overwrite it — overwriting destroys `Containment=org.kde.plasma.folder` which breaks desktop icons
- `wrathos-set-wallpaper.sh` runs as autostart on first login as a fallback
- Flag file `~/.wrathos-wallpaper-set` prevents re-running after user changes wallpaper

---

## APT Repository

- **Local repo:** `~/wrathos/apt-repo` (reprepro)
- **GitHub Pages:** `https://vaeldus.github.io/WrathOS/apt`
- **Signed with:** `EFFDF5373BF6A7B841F3FF8B4F25D97415661FC2`
- **Kernel image** hosted as GitHub Release asset (too large for Pages)
- **Key format:** Binary (not armored) — export with `gpg --export` not `gpg --armor --export`

### Repo Contents
- `linux-image-6.19.9-cachy`
- `linux-headers-6.19.9-cachy`
- `linux-libc-dev`
- `wrathos-base`
- `wrathos-bundle-*` (v1.1)

---

## Working State (v0.1-alpha)

- ✅ CachyOS kernel 6.19.9-cachy boots
- ✅ KDE Plasma 6.3 on Wayland
- ✅ WrathOS identity and branding throughout
- ✅ GRUB EFI with WrathOS W logo
- ✅ Plymouth theme
- ✅ Fastfetch with WrathOS ASCII art
- ✅ Live desktop — Install WrathOS icon works
- ✅ No KDE welcome center (live or installed)
- ✅ WrathOS wallpaper on live and installed
- ✅ Calamares installer
- ✅ Restart option shown after install
- ✅ Flatpak + Flathub pre-configured
- ✅ WrathOS Setup icon on installed desktop
- ✅ Bundle installation — single pkexec prompt
- ✅ Installed bundle tracking
- ✅ Flatpak apps appear in KDE menu after install
- ✅ Configurator auto-launches on first boot
- ✅ GitHub Pages APT repo for kernel/bundle updates

---

## Known Issues / Next Steps

- GitHub Actions CI pipeline for automated ISO builds not yet set up
- No automated kernel update process — manual reprepro + gh release required
- Configurator crashes on first launch in VMware (VMware graphics issue, not a real hardware bug)
