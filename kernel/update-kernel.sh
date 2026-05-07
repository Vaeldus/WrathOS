#!/bin/bash
# WrathOS Kernel Update Script
# Checks for a newer stable CachyOS kernel, builds it, publishes to APT repo
# and GitHub Releases, then updates PROJECT-STATE.md.
#
# Usage: ./update-kernel.sh
# Run from anywhere. Fully unattended.

set -e

# ── Configuration ─────────────────────────────────────────────────────────────
WRATHOS_REPO="${HOME}/WrathOS"
BUILD_SCRIPT="${WRATHOS_REPO}/kernel/build-kernel.sh"
KERNEL_DIR="${HOME}/wrathos/kernel"
APT_REPO="${HOME}/wrathos/apt-repo"
GH_PAGES="${HOME}/wrathos/gh-pages"
GPG_KEY="EFFDF5373BF6A7B841F3FF8B4F25D97415661FC2"
GITHUB_REPO="Vaeldus/WrathOS"
PROJECT_STATE="${WRATHOS_REPO}/docs/PROJECT-STATE.md"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[update-kernel]${NC} $1"; }
warning() { echo -e "${YELLOW}[update-kernel]${NC} $1"; }
error()   { echo -e "${RED}[update-kernel]${NC} $1"; exit 1; }
step()    { echo -e "${CYAN}[update-kernel]${NC} ── $1"; }

# ── Step 1: Get latest stable CachyOS release ─────────────────────────────────
step "Checking latest stable CachyOS kernel release..."

LATEST_TAG=$(curl -s https://api.github.com/repos/CachyOS/linux/releases \
  | grep '"tag_name"' \
  | grep -v '\-rc' \
  | head -1 \
  | sed 's/.*"tag_name": "cachyos-\(.*\)".*/\1/')

if [ -z "${LATEST_TAG}" ]; then
    error "Could not determine latest CachyOS release tag."
fi

LATEST_VERSION=$(echo "${LATEST_TAG}" | sed 's/-[0-9]*$//')
LATEST_REV=$(echo "${LATEST_TAG}" | sed 's/.*-//')
LATEST_MAJOR_MINOR=$(echo "${LATEST_VERSION}" | cut -d. -f1,2)

info "Latest stable: cachyos-${LATEST_TAG} (kernel ${LATEST_VERSION}, rev ${LATEST_REV})"

# ── Step 2: Get currently published version ───────────────────────────────────
step "Checking currently published kernel version..."

CURRENT_DEB=$(ls "${APT_REPO}/pool/main/l/linux-upstream/linux-image-"*"-cachy_"*"_amd64.deb" 2>/dev/null | head -1)

if [ -z "${CURRENT_DEB}" ]; then
    warning "No existing kernel deb found in APT repo. Will build fresh."
    CURRENT_VERSION="none"
else
    CURRENT_VERSION=$(basename "${CURRENT_DEB}" | sed 's/linux-image-\(.*\)-cachy_.*/\1/')
fi

info "Currently published: ${CURRENT_VERSION}"

# ── Step 3: Compare versions ──────────────────────────────────────────────────
if [ "${CURRENT_VERSION}" = "${LATEST_VERSION}" ]; then
    info "Already up to date (${CURRENT_VERSION}). Nothing to do."
    exit 0
fi

info "Update available: ${CURRENT_VERSION} → ${LATEST_VERSION}"

# ── Step 4: Verify patches exist for new version ──────────────────────────────
step "Verifying patches exist for ${LATEST_MAJOR_MINOR}..."

PATCH_BASE="https://raw.githubusercontent.com/cachyos/kernel-patches/master/${LATEST_MAJOR_MINOR}"
BORE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${PATCH_BASE}/sched/0001-bore-cachy.patch")
CLANG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${PATCH_BASE}/misc/dkms-clang.patch")

if [ "${BORE_STATUS}" != "200" ] || [ "${CLANG_STATUS}" != "200" ]; then
    error "Patches not found at ${PATCH_BASE} (bore: ${BORE_STATUS}, clang: ${CLANG_STATUS}). Manual intervention required."
fi

info "Patches confirmed at kernel-patches/master/${LATEST_MAJOR_MINOR}"

# ── Step 5: Update build-kernel.sh ───────────────────────────────────────────
step "Updating build-kernel.sh..."

sed -i "s/^KERNEL_VERSION=.*/KERNEL_VERSION=\"${LATEST_VERSION}\"/" "${BUILD_SCRIPT}"
sed -i "s/^CACHY_TAG=.*/CACHY_TAG=\"cachyos-\${KERNEL_VERSION}-${LATEST_REV}\"/" "${BUILD_SCRIPT}"
sed -i "s|kernel-patches/master/[0-9.]*\"|kernel-patches/master/${LATEST_MAJOR_MINOR}\"|" "${BUILD_SCRIPT}"

info "build-kernel.sh updated."

# ── Step 6: Clean old kernel source ──────────────────────────────────────────
step "Cleaning old kernel source from ${KERNEL_DIR}..."
rm -f "${KERNEL_DIR}/cachyos-"*".tar.gz" || true
rm -rf "${KERNEL_DIR}/cachyos-"*/ || true
rm -f "${KERNEL_DIR}/0001-bore-cachy.patch" "${KERNEL_DIR}/dkms-clang.patch" || true
    rm -f "${KERNEL_DIR}"/surface-*.patch || true

# ── Step 7: Build new kernel ──────────────────────────────────────────────────
step "Building kernel ${LATEST_VERSION}. This will take a while..."
cd "${WRATHOS_REPO}/kernel"
bash build-kernel.sh 2>&1 | tee "${KERNEL_DIR}/build.log"
info "Kernel build complete."

# ── Step 8: Collect new debs ──────────────────────────────────────────────────
step "Collecting built .deb packages..."
NEW_DEBS=$(ls "${KERNEL_DIR}/linux-"*"-cachy_"*"_amd64.deb" "${KERNEL_DIR}/linux-libc-dev_"*"_amd64.deb" 2>/dev/null | grep -v "-dbg_")

if [ -z "${NEW_DEBS}" ]; then
    error "No .deb files found after build. Check ${KERNEL_DIR}/build.log"
fi

info "Found debs:"
echo "${NEW_DEBS}"

# ── Step 9: Update APT repo ───────────────────────────────────────────────────
step "Updating APT repo..."

for OLD_PKG in linux-image linux-headers linux-libc-dev linux-image-dbg; do
    reprepro -b "${APT_REPO}" remove trixie "${OLD_PKG}-${CURRENT_VERSION}-cachy" 2>/dev/null || true
done
reprepro -b "${APT_REPO}" remove trixie linux-libc-dev 2>/dev/null || true

for DEB in ${NEW_DEBS}; do
    info "Adding $(basename ${DEB}) to reprepro..."
    reprepro -b "${APT_REPO}" includedeb trixie "${DEB}"
done

info "APT repo updated."

# ── Step 9b: Remove old kernel versions from R2
step "Removing old kernel versions from R2..."
aws s3 ls s3://wrathos-apt/pool/main/l/linux-upstream/ --endpoint-url "${R2_ENDPOINT}" | awk "{print \$4}" | grep -v "${LATEST_VERSION}" | grep -v "libc" | while read f; do
    aws s3 rm "s3://wrathos-apt/pool/main/l/linux-upstream/${f}" --endpoint-url "${R2_ENDPOINT}" || true
done
info "Old R2 versions removed."

# ── Step 10: Sync to R2
step "Syncing pool to R2..."
aws s3 sync "${APT_REPO}/pool" s3://wrathos-apt/pool \
    --endpoint-url "${R2_ENDPOINT}"
aws s3 sync "${APT_REPO}/dists" s3://wrathos-apt/dists \
    --endpoint-url "${R2_ENDPOINT}"
info "R2 sync complete."

# ── Step 10b: Sync to gh-pages ─────────────────────────────────────────────────
step "Syncing APT repo to gh-pages..."
rsync -av --delete "${APT_REPO}/dists" "${GH_PAGES}/apt/"

cd "${GH_PAGES}"
git add -A
git commit -m "kernel: update to ${LATEST_VERSION}-cachy (cachyos-${LATEST_TAG})"
git push origin gh-pages
info "gh-pages updated and pushed."

# ── Step 11: Upload kernel image as GitHub Release asset ──────────────────────
step "Creating GitHub Release for kernel ${LATEST_VERSION}-cachy..."

KERNEL_IMAGE="${KERNEL_DIR}/linux-image-${LATEST_VERSION}-cachy_1_amd64.deb"
KERNEL_HEADERS="${KERNEL_DIR}/linux-headers-${LATEST_VERSION}-cachy_1_amd64.deb"

if [ ! -f "${KERNEL_IMAGE}" ]; then
    error "Kernel image deb not found: ${KERNEL_IMAGE}"
fi

gh release create "v${LATEST_VERSION}-cachy" \
    --repo "${GITHUB_REPO}" \
    --title "Kernel ${LATEST_VERSION}-cachy" \
    --notes "CachyOS kernel ${LATEST_VERSION} (cachyos-${LATEST_TAG}) built for WrathOS/Debian Trixie. BORE scheduler, ThinLTO, FUTEX2." \
    "${KERNEL_IMAGE}" \
    "${KERNEL_HEADERS}" \
    || warning "GitHub release creation failed — upload manually."

info "GitHub release created."

# ── Step 12: Update PROJECT-STATE.md ─────────────────────────────────────────
step "Updating PROJECT-STATE.md..."

sed -i "s/Kernel: CachyOS [0-9.].*-cachy.*/Kernel: CachyOS ${LATEST_VERSION}-cachy (BORE scheduler, ThinLTO, FUTEX2)/" "${PROJECT_STATE}"
sed -i "s/linux-image-[0-9.].*-cachy/linux-image-${LATEST_VERSION}-cachy/g" "${PROJECT_STATE}"
sed -i "s/linux-headers-[0-9.].*-cachy/linux-headers-${LATEST_VERSION}-cachy/g" "${PROJECT_STATE}"

cd "${WRATHOS_REPO}"
git add docs/PROJECT-STATE.md kernel/build-kernel.sh
git commit -m "kernel: bump to ${LATEST_VERSION}-cachy"
git push origin main
info "PROJECT-STATE.md updated and pushed."

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info " Kernel update complete!"
info " ${CURRENT_VERSION} → ${LATEST_VERSION}-cachy"
info " APT repo: https://vaeldus.github.io/WrathOS/apt"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
