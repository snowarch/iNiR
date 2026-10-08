# Quickshell patches

Patches against [Quickshell](https://git.outfoxxed.me/quickshell/quickshell)
that fix issues affecting iNiR.  Apply them when building QS from source or
via the AUR.

## fix-extension-uaf.patch

**Applies to:** QS 0.2.1 (commit `11a71d2` and nearby)

**Bug:** Hot-reload always crashes with SIGSEGV in
`IpcHandlerRegistry::registerHandler()`.

**Root cause:** `EngineGeneration::destroy()` deletes extensions (including
`IpcHandlerRegistry` and its `QHash`) *before* the QML root is destroyed.
The root is scheduled via `deleteLater()`, so it's torn down later in the
event loop.  During teardown, QML timers and property notifications can
trigger lazy singleton instantiation, which calls
`PostReloadHook::componentComplete()` — and that accesses the already-freed
registry through a dangling pointer in the extensions hash.

Simpler shells rarely hit this because they have few singletons and no
uninstantiated components at reload time.  iNiR's panel family system (ii vs
waffle) and 50+ IPC handlers make the race virtually guaranteed.

**Fix:** Move extension deletion into the `root->destroyed` callback so
extensions outlive the root.  The no-root branch keeps immediate deletion
since there's no QML tree to trigger lazy instantiation.

### Applying

#### AUR / makepkg

Add to your PKGBUILD:

```bash
source+=(fix-extension-uaf.patch)
sha256sums+=('SKIP')

prepare() {
  cd "$_pkgname"
  patch -Np1 -i "$srcdir/fix-extension-uaf.patch"
}
```

#### Manual build

```bash
cd quickshell
patch -Np1 < /path/to/fix-extension-uaf.patch
cmake -GNinja -B build ...
cmake --build build
```

## fix-tray-empty-pixmap.patch

**Applies to:** QS 0.3.1 (tag `v0.3.1`)

**Bug:** When a tray item publishes an empty `IconPixmap` entry (0x0, no data) while it changes its
icon, every view of that icon logs `QImage::scaled: Image is a null image` and `Unable to create pixmap
for tray icon`, and shows Quickshell's missing-icon placeholder until the real icon arrives. iNiR has
17 views of each tray icon in iRiS (bar, strip, bubbles, previews), so one icon change prints 34 lines.

**Root cause:** `StatusNotifierItem::createPixmap` picks the closest pixmap without checking that it
holds an image, then scales the null `QImage`; with no usable pixmap the provider falls back to
`missingPixmap`.

**Fix:** skip entries with no size or too little data, and treat "pixmaps published, none usable" as a
blank (transparent) icon instead of a missing one.

**Verified (2026-09-29):** a throwaway StatusNotifierItem publishing a 0x0 entry, then a valid one: stock
0.3.1 logs both warnings; the patched build logs none and the valid icon still shows. Not yet reported
upstream.

