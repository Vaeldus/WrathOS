# WrathOS

A gaming-focused Linux distribution built on Debian Trixie, powered by the CachyOS kernel.

## What makes WrathOS different

- **Debian Trixie base** — stable, well-supported, massive package ecosystem
- **CachyOS kernel** — BORE scheduler, ThinLTO, MGLRU, FUTEX2, and more gaming optimizations baked in
- **Lean by default** — minimal base install, gaming features added via modular bundles
- **KDE Plasma on Wayland** — modern desktop, gamer-friendly out of the box

## Project structure

| Directory | Purpose |
|---|---|
| `build/` | live-build config and ISO assembly hooks |
| `kernel/` | Kernel build scripts |
| `packages/` | Bundle metapackage definitions |
| `branding/` | Wallpapers, Plymouth theme, GRUB theme |
| `configurator/` | First-boot gaming bundle selector |
| `docs/` | Documentation and install guides |

## Building the kernel
```bash
cd kernel
./build-kernel.sh
```

## Status

Currently in active development. Not yet ready for daily use.

## License

GPL-2.0
