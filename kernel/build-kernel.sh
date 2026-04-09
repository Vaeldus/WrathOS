#!/bin/bash
# WrathOS Kernel Build Script
# Builds the CachyOS kernel with linux-surface patches as Debian .deb packages
#
# Usage: ./build-kernel.sh
# Requirements: Run from the kernel/ directory inside the WrathOS repo

set -e

# ── Configuration ────────────────────────────────────────────────────────────
KERNEL_VERSION="6.19.11"
CACHY_TAG="cachyos-${KERNEL_VERSION}-2"
LOCALVERSION="-cachy"
DEB_VERSION="1"
BUILD_DIR="${HOME}/wrathos/kernel"
JOBS=$(nproc)
MAJOR_MINOR=$(echo "${KERNEL_VERSION}" | cut -d. -f1,2)

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[WrathOS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WrathOS]${NC} $1"; }
error()   { echo -e "${RED}[WrathOS]${NC} $1"; exit 1; }

# ── Preflight checks ──────────────────────────────────────────────────────────
info "Checking build dependencies..."
for cmd in clang llvm-as ld.lld make wget git patch; do
    command -v $cmd >/dev/null 2>&1 || error "Missing dependency: $cmd"
done
info "All dependencies present."

# ── Create build directory ────────────────────────────────────────────────────
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# ── Download kernel source ────────────────────────────────────────────────────
if [ ! -f "${CACHY_TAG}.tar.gz" ]; then
    info "Downloading CachyOS kernel source ${CACHY_TAG}..."
    wget "https://github.com/CachyOS/linux/releases/download/${CACHY_TAG}/${CACHY_TAG}.tar.gz"
else
    info "Kernel source tarball already present, skipping download."
fi

# ── Download CachyOS patches ──────────────────────────────────────────────────
PATCH_BASE="https://raw.githubusercontent.com/cachyos/kernel-patches/master/${MAJOR_MINOR}"

if [ ! -f "0001-bore-cachy.patch" ]; then
    info "Downloading BORE scheduler patch..."
    wget "${PATCH_BASE}/sched/0001-bore-cachy.patch"
fi

if [ ! -f "dkms-clang.patch" ]; then
    info "Downloading dkms-clang patch..."
    wget "${PATCH_BASE}/misc/dkms-clang.patch"
fi

# ── Download linux-surface patches ───────────────────────────────────────────
SURFACE_BASE="https://raw.githubusercontent.com/linux-surface/linux-surface/master/patches/${MAJOR_MINOR}"
SURFACE_PATCHES=(
    "0001-secureboot.patch"
    "0002-surface3.patch"
    "0003-mwifiex.patch"
    "0004-ath10k.patch"
    "0005-ipts.patch"
    "0006-ithc.patch"
    "0007-surface-sam.patch"
    "0008-surface-sam-over-hid.patch"
    "0009-surface-button.patch"
    "0010-surface-typecover.patch"
    "0011-surface-shutdown.patch"
    "0012-surface-gpe.patch"
    "0013-cameras.patch"
    "0014-amd-gpio.patch"
    "0015-rtc.patch"
    "0016-hid-surface.patch"
)

for PATCH in "${SURFACE_PATCHES[@]}"; do
    if [ ! -f "surface-${PATCH}" ]; then
        info "Downloading surface patch: ${PATCH}..."
        wget -O "surface-${PATCH}" "${SURFACE_BASE}/${PATCH}"
    fi
done

# ── Extract source ────────────────────────────────────────────────────────────
if [ ! -d "${CACHY_TAG}" ]; then
    info "Extracting kernel source..."
    tar -xzf "${CACHY_TAG}.tar.gz"
fi

cd "${CACHY_TAG}"

# ── Copy CachyOS config ───────────────────────────────────────────────────────
info "Copying CachyOS kernel config..."
cp "${BUILD_DIR}/linux-cachyos/linux-cachyos/config" .config

# ── Apply CachyOS patches ─────────────────────────────────────────────────────
info "Applying BORE scheduler patch..."
patch -Np1 < "${BUILD_DIR}/0001-bore-cachy.patch"

info "Applying dkms-clang patch..."
patch -Np1 < "${BUILD_DIR}/dkms-clang.patch"

# ── Apply linux-surface patches ───────────────────────────────────────────────
for PATCH in "${SURFACE_PATCHES[@]}"; do
    info "Applying surface patch: ${PATCH}..."
    patch -Np1 < "${BUILD_DIR}/surface-${PATCH}" || warning "Patch ${PATCH} failed or already applied, continuing..."
done

# ── Enable Surface Kconfig options ───────────────────────────────────────────
info "Enabling Surface kernel config options..."
cat >> .config << 'KCONFIG'
CONFIG_SURFACE_AGGREGATOR=m
CONFIG_SURFACE_AGGREGATOR_BUS=y
CONFIG_SURFACE_AGGREGATOR_REGISTRY=m
CONFIG_SURFACE_AGGREGATOR_HUB=m
CONFIG_SURFACE_SAM_SSH_DEBUG_DEVICE=n
CONFIG_SURFACE_BUTTON=m
CONFIG_SURFACE_GPE=m
CONFIG_SURFACE_HOTPLUG=m
CONFIG_SURFACE_3_POWER_OPREGION=m
CONFIG_SURFACE_PRO3_BUTTON=m
CONFIG_SURFACE_ACPI_NOTIFY=m
CONFIG_SURFACE_PLATFORM_PROFILE=m
CONFIG_SURFACE_CHARGER_NOTIFY=m
CONFIG_INTEL_IPTS=m
CONFIG_INTEL_ITHC=m
KCONFIG

# ── Update config ─────────────────────────────────────────────────────────────
info "Updating kernel config for ${KERNEL_VERSION}..."
make olddefconfig CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1

# ── Build ─────────────────────────────────────────────────────────────────────
info "Building kernel with ${JOBS} cores — this will take a while..."
make -j"${JOBS}" bindeb-pkg \
    CC=clang \
    LD=ld.lld \
    LLVM=1 \
    LLVM_IAS=1 \
    LOCALVERSION="${LOCALVERSION}" \
    KDEB_PKGVERSION="${DEB_VERSION}" \
    2>&1 | tee "${BUILD_DIR}/build.log"

# ── Done ──────────────────────────────────────────────────────────────────────
info "Build complete. Packages are in ${BUILD_DIR}/"
ls "${BUILD_DIR}"/*.deb
