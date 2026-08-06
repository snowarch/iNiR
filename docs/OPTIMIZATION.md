# QML/Quickshell Performance Optimization Guide

Best practices for optimizing iNiR based on Qt6 QML documentation and KDAB recommendations.

## Quick Reference

| Do                             | Don't                                        |
| ------------------------------ | -------------------------------------------- |
| `property int size: 10`        | `property var size: 10`                      |
| `visible: false`               | `opacity: 0`                                 |
| `anchors.fill: parent`         | `width: parent.width; height: parent.height` |
| `root.myProperty` (qualified)  | `myProperty` (unqualified)                   |
| `asynchronous: true` on images | Sync image loading                           |
| Cache lookups in loops         | Repeated property access                     |

## 1. Type Annotations

Always use concrete types instead of `var`:

```qml
// Bad
property var size: 10
property var items: []

// Good
property int size: 10
property list<string> items: []
```

Annotate function parameters and return types:

```qml
// Bad
function calculate(width, height) {
    return width * height
}

// Good
function calculate(width: real, height: real): real {
    return width * height
}
```

## 2. Qualified Property Lookups

Always qualify property access with object id:

```qml
Item {
    id: root
    property int size: 10

    Rectangle {
        // Bad - unqualified lookup
        width: size

        // Good - qualified lookup
        width: root.size
    }
}
```

## 3. Property Resolution Caching

Cache property lookups outside tight loops:

```qml
// Bad - resolves rect.color 4 times per iteration
for (var i = 0; i < 1000; ++i) {
    printValue("red", rect.color.r)
    printValue("green", rect.color.g)
    printValue("blue", rect.color.b)
    printValue("alpha", rect.color.a)
}

// Good - resolve once, use cached value
var rectColor = rect.color
for (var i = 0; i < 1000; ++i) {
    printValue("red", rectColor.r)
    printValue("green", rectColor.g)
    printValue("blue", rectColor.b)
    printValue("alpha", rectColor.a)
}
```

## 4. Binding Optimization

Use temporary accumulators to avoid intermediate re-evaluations:

```qml
// Bad - triggers 6 binding re-evaluations
for (var i = 0; i < someData.length; ++i) {
    accumulatedValue = accumulatedValue + someData[i]
}

// Good - single re-evaluation at the end
var temp = accumulatedValue
for (var i = 0; i < someData.length; ++i) {
    temp = temp + someData[i]
}
accumulatedValue = temp
```

## 5. Visibility vs Opacity

Use `visible: false` instead of `opacity: 0`:

```qml
// Bad - still renders, just transparent
opacity: 0

// Good - skips rendering entirely
visible: false
```

## 6. Anchors vs Bindings

Prefer anchors for relative positioning:

```qml
// Bad - binding-based positioning
Rectangle {
    x: rect1.x
    y: rect1.y + rect1.height
    width: rect1.width - 20
}

// Good - anchor-based positioning
Rectangle {
    anchors.left: rect1.left
    anchors.top: rect1.bottom
    anchors.right: rect1.right
    anchors.rightMargin: 20
}
```

## 7. Image Loading

Always use async loading and explicit source size:

```qml
Image {
    source: "large-image.png"
    asynchronous: true  // Load in background thread
    sourceSize: Qt.size(200, 200)  // Scale before loading
    cache: true  // Cache decoded image
    smooth: false  // Disable if not needed
}
```

## 8. Text Performance

Use simplest text format possible:

```qml
Text {
    // Best performance
    textFormat: Text.PlainText

    // Only if you need basic formatting
    // textFormat: Text.StyledText

    // Avoid - expensive parsing
    // textFormat: Text.AutoText
    // textFormat: Text.RichText
}
```

## 9. ListView/Delegates

Keep delegates simple and avoid clipping:

```qml
ListView {
    // Buffer delegates outside viewport
    cacheBuffer: 200

    delegate: Item {
        // NEVER clip in delegates
        // clip: true  // BAD!

        // Keep delegate simple
        // Avoid ShaderEffects in delegates
    }
}
```

## 10. Lazy Loading (Quickshell)

Use LazyLoader for panels not immediately needed:

```qml
// LazyLoader properties:
// - active: sync load, destroys on false
// - loading: starts async background load
// - activeAsync: async load, can read/write like active
// - item: accessing forces sync load if not ready

LazyLoader {
    // Load when condition is true
    active: Config.ready && someCondition

    HeavyComponent {}
}
```

**Important**: `loading` only STARTS async load, doesn't KEEP component active. Use `active` to maintain loaded state.

## 11. Clipping

Avoid `clip: true` whenever possible:

```qml
// Bad - increases renderer complexity
Rectangle {
    clip: true
    // ...
}

// Good - use ClippingRectangle only when necessary
// Or restructure to avoid clipping
```

## 12. Null Safety & Config Access

iNiR's config uses Quickshell's `JsonAdapter` + `FileView`. Every property is declared in `Config.qml` with a typed default. When the user's `config.json` has a value, JsonAdapter reads it; when it doesn't, the schema default applies. The property always exists for declared schema keys.

```qml
// Config access: schema properties are guaranteed by JsonAdapter
property int value: Config.options.bar.cornerStyle  //  always valid

// ❌ Direct assignment: persists to disk via JsonAdapter, but does NOT emit
//    configChanged(). Listeners (settings pages, bar layout, theme reactivity)
//    will not update. This is the #1 silent bug source in iNiR.
// Config.options.bar.bottom = true

// ✅ Always use setNestedValue(): persists to disk AND emits configChanged()
//    so every listener reacts correctly.
Config.setNestedValue("bar.bottom", true)

// Runtime data: may genuinely be null, USE optional chaining here
property string title: NiriService.activeWindow?.title ?? ""
```

> **Project rule:** always use `Config.setNestedValue("dot.path", value)` for any config write. Direct property assignment (`Config.options.x = y`) skips the `configChanged()` signal. The value reaches disk but the UI and any reactive listeners never see the change.

> **Also:** use `?.` + `??` on config reads in module code. It protects against edge cases like key renames during migrations or malformed user configs. JsonAdapter guarantees schema defaults, but defensive access is the safer habit.

## Quickshell-Specific

### PanelLoader Pattern

```qml
component PanelLoader: LazyLoader {
    required property string identifier
    property bool extraCondition: true
    active: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
}
```

### StyledImage

Already optimized with `asynchronous: true` by default.

### Appearance System

Use `Appearance.animationsEnabled` and `Appearance.effectsEnabled` to respect user preferences and GameMode.

### Runtime performance controls

On Niri 26.04 or newer, Settings › Effects can delegate supported translucent surfaces to Niri's `ext-background-effect-v1` implementation and avoid a duplicate QML blur pass. The page is shared by ii and Waffle and provides a default backend plus overrides for bars, docks, panels, islands and desktop widgets. `Auto` preserves each global style's intended material; `Wallpaper`, `Compositor` and `Off` are explicit requests.

Native blur is deliberately shape-aware. Rounded rectangles publish their exact item bounds and radius, while the islands bar publishes a union of its five live cards. Complex connected decorations, pill compositions and non-rounded silhouettes use wallpaper blur when an equivalent compositor region cannot be expressed. Disabling compositor blur keeps the selected global style and resolves through its wallpaper or solid fallback.

Launchers, overview, wallpaper pickers and most other heavy panels are created on demand. Their IPC commands remain registered through lightweight routers. Sidebars are the deliberate exception: their fullscreen roots load in the deferred phase, their content waits for the first valid mapped geometry, and both remain resident afterward so rapid close/reopen can reverse one surface without rebuilding its workspace.

Thumbnail jobs launched by the wallpaper and generated-image pickers run in a transient user scope rather than the `inir.service` cgroup. `inir restart` cancels any unfinished iNiR thumbnail pool, and completed scopes are collected automatically, so their workers and page cache are not reported as shell memory.

### Stateful visual lifetimes

Most heavy visual trees are disposable, but sidebar workspaces are resident by design. They mount at final geometry, animate by transforming or clipping the same tree, release the fullscreen backdrop input as soon as closing begins, and preserve navigation, searches and bottom-widget state. Settings keeps only the current page and its immediate neighbours rendered; ii/Waffle navigation, theme filters and Gowall editor context live in persistent settings state instead of page delegates.

Blur eligibility is topology-based. A surface must declare an exact `rectangle`, `rounded-rectangle` or `islands-union` region before an explicit compositor backend can be used. Unsupported or morphing silhouettes retain their wallpaper material, and `auto` remains fidelity-first. Explicit Island/Ricelin surfaces own their complete material so global ZZZ, Aurora, Angel or iNiR chrome cannot leak into the same surface.

Desktop widgets keep decoded wallpaper images warm, but release their per-widget mask and blur framebuffer objects whenever the widget is hidden or the widget power manager pauses visual work. Clocks, Cava and resource sampling continue to use their own visibility and consumer gates, so returning to the desktop restores the same visuals without keeping invisible render targets active.

The bar spectrum uses one shared Cava process regardless of monitor count. Its
`Primary only` mode is the performance default: only the configured primary
output uploads and paints spectrum canvases, while the other bars keep their
normal layout. `All monitors` is available in Settings › Bar › Audio spectrum
for users who prefer matching visualizers on every output. M3 visualizer slots
collapse while the shared service reports no audio signal, so an empty Cava
frame does not reserve bar space.


## Tools

- **QML Profiler** (Qt Creator): Find slow bindings and functions
- **GammaRay**: Analyze QML scenes
- **Hotspot**: CPU profiling
- **Heaptrack**: Memory profiling

## References

- [Qt Quick Performance](https://doc.qt.io/qt-6/qtquick-performance.html)
- [KDAB: 10 Tips for QML Performance](https://www.kdab.com/10-tips-to-make-your-qml-code-faster-and-more-maintainable/)
- [Quickshell LazyLoader](https://quickshell.outfoxxed.me/docs/v0.1.0/types/Quickshell/LazyLoader/)
