#!/usr/bin/env bash
# build-quickshell-webengine.sh — Build Quickshell with QtWebEngine support
#
# This script clones, patches, and builds Quickshell with WebEngine support
# for iNiR's WebApp plugin system. For Arch Linux users, prefer the PKGBUILD
# in scripts/quickshell-webengine/ instead.
#
# Usage:
#   ./build-quickshell-webengine.sh [--install]
#
# Requirements:
#   - cmake, ninja, git, pkg-config
#   - Qt6: qt6-base, qt6-declarative, qt6-svg, qt6-wayland, qt6-webengine
#   - qt6-shadertools, spirv-tools, wayland-protocols, vulkan-headers (build-time)
#   - cli11

set -euo pipefail

REPO_URL="https://github.com/quickshell-mirror/quickshell.git"
BUILD_DIR="/tmp/quickshell-webengine-build"
INSTALL_PREFIX="/usr"
QML_DIR="/usr/lib/qt6/qml"
DO_INSTALL=false

if [[ "${1:-}" == "--install" ]]; then
    DO_INSTALL=true
fi

echo "═══════════════════════════════════════════════════"
echo "  Quickshell + WebEngine build for iNiR"
echo "═══════════════════════════════════════════════════"

# ── Clone ─────────────────────────────────────────────
if [[ -d "$BUILD_DIR" ]]; then
    echo "[1/5] Updating existing source..."
    cd "$BUILD_DIR"
    git fetch origin
    git reset --hard origin/master
else
    echo "[1/5] Cloning quickshell..."
    git clone "$REPO_URL" "$BUILD_DIR"
    cd "$BUILD_DIR"
fi

echo "    Commit: $(git rev-parse --short HEAD)"

# ── Patch ─────────────────────────────────────────────
echo "[2/5] Applying WebEngine patches..."

# Patch 1: qArgC = 1 (Chromium needs argv[0])
sed -i 's/auto qArgC = 0;/auto qArgC = 1;/' src/launch/launch.cpp
echo "    ✓ qArgC = 1"

# Patch 2: WebEngine init header
mkdir -p src/webengine
cat > src/webengine/webengine.hpp << 'HEADER_EOF'
#include <QDebug>
#include <qlibrary.h>

namespace qs::web_engine {

inline bool init() {
    using InitializeFunc = void (*)();
    QLibrary lib("Qt6WebEngineQuick");
    if (!lib.load()) {
        qWarning() << "Failed to load Qt6WebEngineQuick:" << lib.errorString();
        return false;
    }
    auto initialize = reinterpret_cast<InitializeFunc>(
        lib.resolve("_ZN16QtWebEngineQuick10initializeEv"));
    if (!initialize) {
        qWarning() << "Failed to resolve QtWebEngineQuick::initialize()";
        return false;
    }
    initialize();
    qDebug() << "QtWebEngineQuick initialized successfully";
    return true;
}

} // namespace qs::web_engine
HEADER_EOF
echo "    ✓ WebEngine init header"

# Patch 3: Hook into launch.cpp
sed -i '/#include "launch_p.hpp"/a #include "../webengine/webengine.hpp"' src/launch/launch.cpp
sed -i '/bool useSystemStyle = false;/a\\t\tbool useQtWebEngineQuick = false;' src/launch/launch.cpp
sed -i '/else if (pragma == "RespectSystemStyle")/a\\t\t\t\telse if (pragma == "EnableQtWebEngineQuick") pragmas.useQtWebEngineQuick = true;' src/launch/launch.cpp
sed -i '/auto qArgC = 1;/a\\n\tif (pragmas.useQtWebEngineQuick) {\n\t\tweb_engine::init();\n\t}' src/launch/launch.cpp
echo "    ✓ launch.cpp patched"

# ── Configure ─────────────────────────────────────────
echo "[3/5] Configuring..."
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DINSTALL_QMLDIR="$QML_DIR" \
    -DDISTRIBUTOR="iNiR build script" \
    -DUSE_JEMALLOC=OFF \
    -DCRASH_REPORTER=OFF \
    -DCRASH_HANDLER=OFF

# ── Build ─────────────────────────────────────────────
echo "[4/5] Building (this takes a few minutes)..."
cmake --build build -j"$(nproc)"

echo "    ✓ Build complete: $BUILD_DIR/build/quickshell"

# ── Install ───────────────────────────────────────────
if $DO_INSTALL; then
    echo "[5/5] Installing (requires sudo)..."
    sudo cmake --install build
    echo "    ✓ Installed to $INSTALL_PREFIX"
    echo ""
    echo "Done! Restart your shell with: inir restart"
else
    echo "[5/5] Skipping install (run with --install to install system-wide)"
    echo ""
    echo "To install manually:"
    echo "  sudo cmake --install $BUILD_DIR/build"
    echo ""
    echo "Or copy the binary directly:"
    echo "  sudo cp $BUILD_DIR/build/quickshell /usr/bin/quickshell"
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Done! Enable Web Apps in:"
echo "  Settings → Interface → Sidebars → Web Apps"
echo "═══════════════════════════════════════════════════"
