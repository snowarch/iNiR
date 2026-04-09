# QML/Quickshell Performance Optimization Guide

Best practices for optimizing iNiR based on Qt6 QML documentation and KDAB recommendations.

## Quick Reference

| Do | Don't |
|---|---|
| `property int size: 10` | `property var size: 10` |
| `visible: false` | `opacity: 0` |
| `anchors.fill: parent` | `width: parent.width; height: parent.height` |
| `root.myProperty` (qualified) | `myProperty` (unqualified) |
| `asynchronous: true` on images | Sync image loading |
| Cache lookups in loops | Repeated property access |

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
// Config access — schema properties are guaranteed by JsonAdapter
property int value: Config.options.bar.cornerStyle  //  always valid

// Direct assignment persists to config.json automatically
Config.options.bar.bottom = true

// Use setNestedValue() when you need the configChanged() signal
// (5 listeners depend on it — settings pages, bar layout, etc.)
Config.setNestedValue("bar.bottom", true)

// Runtime data — may genuinely be null, USE optional chaining here
property string title: NiriService.activeWindow?.title ?? ""
```

> **Project convention:** use `?.` + `??` on config access in module code anyway. It protects against edge cases like key renames during migrations or malformed user configs. JsonAdapter guarantees schema defaults, but defensive access is the safer habit.

## Quickshell-Specific

### PanelLoader Pattern

```qml
component PanelLoader: LazyLoader {
    required property string identifier
    property bool extraCondition: true
    active: Config.ready && Config.options.enabledPanels.includes(identifier) && extraCondition
}
```

### StyledImage

Already optimized with `asynchronous: true` by default.

### Appearance System

Use `Appearance.animationsEnabled` and `Appearance.effectsEnabled` to respect user preferences and GameMode.

## Tools

- **QML Profiler** (Qt Creator): Find slow bindings and functions
- **GammaRay**: Analyze QML scenes
- **Hotspot**: CPU profiling
- **Heaptrack**: Memory profiling

## References

- [Qt Quick Performance](https://doc.qt.io/qt-6/qtquick-performance.html)
- [KDAB: 10 Tips for QML Performance](https://www.kdab.com/10-tips-to-make-your-qml-code-faster-and-more-maintainable/)
- [Quickshell LazyLoader](https://quickshell.outfoxxed.me/docs/v0.1.0/types/Quickshell/LazyLoader/)
