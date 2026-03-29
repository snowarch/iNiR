#!/usr/bin/env bash
# AUR publication helper for inir-shell-git
# Run this after: (1) pushing to GitHub, (2) registering AUR account, (3) adding SSH key
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="${SCRIPT_DIR}"
AUR_PKG="inir-shell-git"
WORK_DIR="${TMPDIR:-/tmp}/aur-${AUR_PKG}"

echo "=== iNiR AUR Publication Helper ==="
echo ""

# Step 1: Verify SSH access
echo "[1/5] Testing AUR SSH access..."
if ! ssh -T aur@aur.archlinux.org -o ConnectTimeout=5 2>&1 | grep -q "Welcome"; then
    echo "ERROR: AUR SSH authentication failed."
    echo ""
    echo "To fix this:"
    echo "  1. Register at https://aur.archlinux.org/register"
    echo "  2. Go to https://aur.archlinux.org/account/YOUR_USERNAME/edit"
    echo "  3. Paste your SSH public key:"
    echo "     $(cat ~/.ssh/id_ed25519.pub 2>/dev/null || echo '(no key found — run: ssh-keygen -t ed25519)')"
    echo "  4. Re-run this script"
    exit 1
fi
echo "  SSH access OK"

# Step 2: Verify GitHub has LICENSE
echo "[2/5] Verifying LICENSE exists on GitHub..."
if ! curl -sf "https://raw.githubusercontent.com/snowarch/iNiR/dev/LICENSE" >/dev/null 2>&1; then
    echo "ERROR: LICENSE not found on GitHub."
    echo "  Push your local commits first: git push origin dev"
    exit 1
fi
echo "  LICENSE found on GitHub"

# Step 3: Clone AUR repo (creates new package if it doesn't exist)
echo "[3/5] Cloning AUR repo..."
rm -rf "${WORK_DIR}"
git clone "ssh://aur@aur.archlinux.org/${AUR_PKG}.git" "${WORK_DIR}" 2>/dev/null || {
    echo "  Package doesn't exist yet, creating empty repo..."
    mkdir -p "${WORK_DIR}"
    cd "${WORK_DIR}"
    git init
    git remote add origin "ssh://aur@aur.archlinux.org/${AUR_PKG}.git"
}

# Step 4: Copy package files
echo "[4/5] Copying package files..."
cp "${PKG_DIR}/PKGBUILD" "${WORK_DIR}/PKGBUILD"
cp "${PKG_DIR}/inir-shell-git.install" "${WORK_DIR}/inir-shell-git.install"

# Regenerate .SRCINFO from the PKGBUILD
cd "${WORK_DIR}"
makepkg --printsrcinfo > .SRCINFO

echo "  Files in AUR repo:"
ls -la "${WORK_DIR}"/{PKGBUILD,.SRCINFO,inir-shell-git.install}

# Step 5: Commit and push
echo "[5/5] Committing and pushing to AUR..."
cd "${WORK_DIR}"
git add PKGBUILD .SRCINFO inir-shell-git.install
git commit -m "Initial upload: inir-shell-git $(grep pkgver= PKGBUILD | head -1 | cut -d= -f2)"

echo ""
echo "Ready to push. Review the commit:"
git log --oneline -1
git diff --stat HEAD~1
echo ""
read -rp "Push to AUR? [y/N] " confirm
if [[ "${confirm}" =~ ^[Yy]$ ]]; then
    git push origin master
    echo ""
    echo "=== Published! ==="
    echo "  https://aur.archlinux.org/packages/${AUR_PKG}"
else
    echo ""
    echo "Aborted. AUR repo prepared at: ${WORK_DIR}"
    echo "To push manually: cd ${WORK_DIR} && git push origin master"
fi
