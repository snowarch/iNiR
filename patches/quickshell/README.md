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
