# WrathOS Project State

> This document is the source of truth for the current state of WrathOS.
> Update it with every release. Claude should read this at the start of any session.

## Identity
- **Name:** WrathOS
- **Tagline:** Forging ahead reliably, Gaming at the edge.
- **Version:** v0.5 (Forge)
- **Base:** Debian Trixie
- **Kernel:** CachyOS 7.0.3-cachy (BORE scheduler, ThinLTO, FUTEX2)
- **Desktop:** KDE Plasma 6.3 on Wayland, SDDM
- **Installer:** Calamares 3.3.14
- **GitHub:** https://github.com/Vaeldus/WrathOS
- **Maintainer:** Vaeldus / zxd (zxdsystems@gmail.com)

---

## Build Environment
- **Build machine:** WrathOS-Build VM (QEMU/KVM on hope)
- **User:** zxd
- **SSH:** `ssh zxd@192.168.50.250` (port 22, static IP)
- **Build dir:** `~/WrathOS/build`
- **APT repo:** `~/wrathos/apt-repo`
- **gh-pages:** `~/wrathos/gh-pages`
- **Kernel build dir:** `~/wrathos/kernel`
- **Meta-packages:** `~/wrathos/meta-packages`
- **Actions runner:** `~/WrathOS/actions-runner`
- **GPG Key ID:** `EFFDF5373BF6A7B841F3FF8B4F25D97415661FC2`
- **Network:** virtio NIC, systemd-networkd, static 192.168.50.250/24, gateway 192.168.50.2, DNS 192.168.50.5

> **Note:** Build VM clock slips after sleep. Always run `sudo timedatectl set-ntp true` before building.

---

## APT Repository Infrastructure
- **Index (dists/):** https://vaeldus.github.io/WrathOS/apt (gh-pages) AND https://pub-eb0cb388725b4257a37f7d082e4d229b.r2.dev (Cloudflare R2)
- **Pool (packages):** https://pub-eb0cb388725b4257a37f7d082e4d229b.r2.dev (Cloudflare R2)
- **Installed system APT source:** `deb [signed-by=/etc/apt/keyrings/wrathos.gpg] https://pub-eb0cb388725b4257a37f7d082e4d229b.r2.dev trixie main`
- **R2 Bucket:** wrathos-apt
- **R2 Public URL:** https://pub-eb0cb388725b4257a37f7d082e4d229b.r2.dev
- **R2 Endpoint:** https://31bb4fc1020217be8b33a39bcad88900.r2.cloudflarestorage.com
- **Keyring location (installed):** `/etc/apt/keyrings/wrathos.gpg`
- **Keyring download:** https://pub-eb0cb388725b4257a37f7d082e4d229b.r2.dev/wrathos-archive-keyring.gpg
- **Signed with:** `EFFDF5373BF6A7B841F3FF8B4F25D97415661FC2`
- **Key format:** Binary (not armored) — export with `gpg --export` not `gpg --armor --export`

### Repo Contents
- `linux-image-7.0.9-cachy`
- `linux-headers-7.0.9-cachy`
- `linux-libc-dev`
- `wrathos-kernel` (meta-package v7.0.3 — depends on current kernel, enables `apt upgrade` for kernels)
- `wrathos-base`
- `wrathos-bundle-*` (v1.1)

### Publishing Workflow
1. `reprepro` manages local APT repo at `~/wrathos/apt-repo`
2. `dists/` synced to both R2 and gh-pages
3. Large kernel image debs uploaded directly to R2 pool (too large for gh-pages 100MB limit)
4. Small debs (headers, libc-dev, bundles, meta-packages) also in R2 pool
5. `wrathos-kernel` meta-package bumped with each kernel update

---

## CI Pipeline
- **Runner:** Self-hosted GitHub Actions runner on build box
- **Service:** `actions.runner.Vaeldus-WrathOS.wrathos-build-box.service`
- **Schedule:** Weekly kernel update check (Mondays 6am UTC)
- **Workflow:** `.github/workflows/kernel-update.yml`
- **Manual trigger:** Available via GitHub Actions UI
- **Secrets:** `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `GPG_PRIVATE_KEY`, `BUILD_BOX_SSH_KEY`

### CI Flow
1. Check GitHub API for latest stable CachyOS release (filters out `-rc` tags)
2. Compare against currently published version in APT repo
3. If newer: update `build-kernel.sh`, clean old source, build new kernel
4. Add new debs to reprepro, remove old ones
5. Sync dists/ and pool/ to R2
6. Sync dists/ to gh-pages
7. Upload kernel image as GitHub Release asset
8. Update `PROJECT-STATE.md` and `build-kernel.sh`, push to main

---

## Kernel Build System
- **Script:** `~/WrathOS/kernel/build-kernel.sh`
- **Update script:** `~/WrathOS/kernel/update-kernel.sh`
- **Current version:** 7.0.3-cachy (cachyos-7.0.3-2)
- **Patches:** BORE scheduler, dkms-clang
- **linux-surface patches:** Not yet available for 7.0 — will be re-added when linux-surface updates
- **Build flags:** clang, ld.lld, LLVM=1, LLVM_IAS=1, ThinLTO
- **Debug package:** Suppressed via `scripts/config --disable DEBUG_INFO` (verify working)

### Kernel Update Manual Steps (if CI fails)
```bash
cd ~/WrathOS/kernel
bash update-kernel.sh
# If meta-package needs bumping:
cat > ~/wrathos/meta-packages/wrathos-kernel/DEBIAN/control << CTLEOF
Package: wrathos-kernel
Version: X.X.X
Architecture: amd64
Maintainer: WrathOS <zxdsystems@gmail.com>
Section: kernel
Priority: optional
Depends: linux-image-X.X.X-cachy, linux-headers-X.X.X-cachy
Description: WrathOS kernel meta-package
 Upgrading this package pulls in the latest supported kernel.
CTLEOF
dpkg-deb --build --root-owner-group ~/wrathos/meta-packages/wrathos-kernel
reprepro -b ~/wrathos/apt-repo remove trixie wrathos-kernel
reprepro -b ~/wrathos/apt-repo includedeb trixie ~/wrathos/meta-packages/wrathos-kernel.deb
aws s3 cp ~/wrathos/meta-packages/wrathos-kernel.deb \
    s3://wrathos-apt/pool/main/w/wrathos-kernel/wrathos-kernel_X.X.X_amd64.deb \
    --endpoint-url https://31bb4fc1020217be8b33a39bcad88900.r2.cloudflarestorage.com
```

---

## ISO Build

### Rebuild Command
```bash
sudo timedatectl set-ntp true
cd ~/WrathOS/build
sudo lb clean --all
sudo chown -R zxd:zxd ~/WrathOS/build/.build ~/WrathOS/build/cache 2>/dev/null || true
lb config \
  --distribution trixie \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-images iso-hybrid \
  --bootloader grub-efi \
  --debian-installer none \
  --apt-indices false \
  --memtest none \
  --bootappend-live "boot=live components quiet splash"
screen -S iso-build
sudo lb build 2>&1 | tee ~/wrathos/build.log
# Detach: Ctrl+A then D
# Reattach: screen -r iso-build
```

### ISO Release
- ISOs hosted on Cloudflare R2 (too large for GitHub 2GB release limit)
- Latest: https://pub-eb0cb388725b4257a37f7d082e4d229b.r2.dev/releases/WrathOS-0.5-Forge-amd64-20260425.iso
- Upload: `aws s3 cp <iso> s3://wrathos-apt/releases/<iso> --endpoint-url <R2_ENDPOINT>`

### Common ISO Build Issues
- `lb chroot_devpts already locked` — run `sudo chown -R zxd:zxd ~/WrathOS/build/.build` then retry
- `config stage required` — always run `lb config` before `lb build`
- Build killed mid-run — use `screen` to prevent SSH disconnects killing the build
- Debug deb produced — delete with `rm ~/wrathos/kernel/linux-image-*-dbg_*.deb`

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
| `~/WrathOS/build/config/includes.chroot/opt/wrathos-kernel/` | Kernel debs bundled in ISO |
| `~/WrathOS/packages/wrathos-bundle-*/` | Bundle metapackages |
| `~/WrathOS/build/config/includes.chroot/opt/wrathos-bundles/` | Bundle debs in ISO |
| `~/WrathOS/kernel/build-kernel.sh` | Kernel build script |
| `~/WrathOS/kernel/update-kernel.sh` | Automated kernel update script |
| `~/WrathOS/.github/workflows/kernel-update.yml` | CI workflow |
| `~/wrathos/apt-repo/` | Local APT repo |
| `~/wrathos/gh-pages/` | GitHub Pages repo |
| `~/wrathos/kernel/` | Kernel build artifacts and debs |
| `~/wrathos/meta-packages/` | Meta-package sources |

---

## Hook Reference

| Hook | Purpose |
|------|---------|
| `0001` | Install CachyOS kernel debs (version auto-detected) |
| `0003` | Fix live boot kernel filename — dynamic version detection (binary) |
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
2. shellprocess.conf runs: GRUB install, EFI fallback copy, Flatpak/Flathub setup, WrathOS APT repo + keyring setup from R2
3. User manually reboots (restart option shown, unchecked by default)
4. First boot: `wrathos-firstboot.service` runs `wrathos-firstboot-system.sh` as root
5. Script ensures APT keyring is in place (fallback download from R2)
6. Script creates autostart files, desktop icon, app menu entry
7. Script touches `/var/lib/wrathos-firstboot-done` and exits
8. User logs into KDE — configurator auto-launches, wallpaper sets

> **Critical:** `wrathos-firstboot-system.sh` must check `boot=live` at the top or it will reboot the live environment.

---

## Wallpaper System

- WrathOS wallpaper replaces KDE's default Next wallpaper files at `/usr/share/wallpapers/Next/contents/images/`
- Hook 0007 also appends `[Wallpaper]` section to `/usr/share/plasma/shells/org.kde.plasma.desktop/contents/defaults`
- **Critical:** Hook 0007 must APPEND to the defaults file, never overwrite it — overwriting destroys `Containment=org.kde.plasma.folder` which breaks desktop icons
- `wrathos-set-wallpaper.sh` runs as autostart on first login as a fallback
- Flag file `~/.wrathos-wallpaper-set` prevents re-running after user changes wallpaper

---

## Working State (v0.1-alpha)

- ✅ CachyOS kernel 7.0.3-cachy boots
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
- ✅ Cloudflare R2 APT repo — kernel updates via `apt upgrade`
- ✅ `wrathos-kernel` meta-package for seamless kernel upgrades
- ✅ Self-hosted GitHub Actions CI runner on build box
- ✅ Automated weekly kernel update check via CI

---

## Known Issues / Open Items

- CI pipeline: reprepro --ask-passphrase removed, gh-pages pool sync removed ✅
- Debug kernel deb suppressed via KDEB_IMAGE_DEBUG=0 ✅
- `update-kernel.sh` auto-bumps wrathos-kernel meta-package ✅
- linux-surface patches not yet available for kernel 7.0 — Surface device support pending linux-surface upstream update
- Configurator crashes on first launch in VMware (VMware graphics issue, low priority)
- ISO build automated via CI — triggers after successful kernel update ✅

---

## Release History

| Date | Version | Kernel | Notes |
|------|---------|--------|-------|
| 2026-03-20 | v0.1-alpha | 6.19.9-cachy | Initial release |
| 2026-04-25 | v0.1-alpha | 7.0.0-cachy | R2 hosting, CI pipeline |

### Latest ISO
https://pub-eb0cb388725b4257a37f7d082e4d229b.r2.dev/releases/WrathOS-0.5-Forge-amd64-20260425.iso
