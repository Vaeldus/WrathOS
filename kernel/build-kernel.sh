#!/bin/bash
# WrathOS Kernel Build Script
# Builds the CachyOS kernel as Debian .deb packages
#
# Usage: ./build-kernel.sh
# Requirements: Run from the kernel/ directory inside the WrathOS repo
#
# Note: linux-surface patches are not yet available for 7.0.
# Surface support will be re-added when linux-surface updates their patch set.

set -e

# ── Configuration ────────────────────────────────────────────────────────────
KERNEL_VERSION="7.0.1"
CACHY_TAG="cachyos-${KERNEL_VERSION}-3"
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

# ── Update config ─────────────────────────────────────────────────────────────
info "Updating kernel config for ${KERNEL_VERSION}..."
# Disable debug package
scripts/config --disable DEBUG_INFO
scripts/config --enable DEBUG_INFO_NONE

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
    GENERATE_DEBUG=0 \
    2>&1 | tee "${BUILD_DIR}/build.log"

# ── Done ──────────────────────────────────────────────────────────────────────
info "Build complete. Packages are in ${BUILD_DIR}/"
ls "${BUILD_DIR}"/*.deb
