# Editorial style

Editorial gives iNiR a quiet, high-contrast composition: charcoal or warm paper surfaces, a prominent inverse card, strong sans-serif headlines, small metadata, compact rounded corners and short accent marks. Paper can follow the selected theme or use its own light/charcoal mode. The Reading typography option uses a serif display face; controls retain the interface font.

Select **Settings → Themes → Style → Editorial**. The Editorial editor exposes paper mode, wallpaper-derived or custom pigment, tint depth, an optional second paper layer, typography, headline scale/weight/tracking, warmth, accent intensity, spacing, corners, ornaments and motion. These values are stored under `appearance.editorial`. A global style is distinct from the panel family: Waffle keeps its layouts and uses its `Looks` palette to present Editorial.

## Color and hierarchy

Use the roles in `modules/common/Appearance.qml`, rather than copying colors from a screenshot:

| Role | Token | Use |
| --- | --- | --- |
| Panel | `editorial.paper` | Main shell surface |
| Content | `editorial.layer(1)` | Cards on the panel |
| Raised control | `editorial.layer(2)` | Inputs and secondary controls |
| Text | `editorial.ink` | Text on paper/layers |
| Supporting text | `editorial.muted` | Descriptions and metadata |
| Accent | `editorial.accent` / `accentInk` | Active controls and their content |
| Soft selection | `editorial.field` / `fieldInk` | Quiet selection backgrounds |
| Inverse card | `editorial.ink` / `paperOnInk` | The focal card and its content |
| Boundary | `editorial.rule` / `edge` | Necessary outlines |
| Interaction | `editorial.controlHover` / `controlPressed` | Quiet tinted hover and press fields |
| Selected interaction | `editorial.selectionHover` / `selectionPressed` | Feedback on selected paper fields |
| Keyboard focus | `editorial.focusRing` | Readable accent boundary |

An inverse card reverses the background/text pair. In dark mode it becomes the pale card seen in the dashboard greeting; in light mode it becomes an ink card. Give the main composition one focal card. Keep supporting cards quiet so headings, content and controls remain easy to scan.

Shared Material controls already consume `Appearance.colors`, whose layer, primary and secondary roles resolve to Editorial. Use their normal color API. Error, warning and application artwork retain their meaning. Waffle components consume `Looks.colors` and `Looks.radius`; do not replace their layout tree with Material controls.

Accent intensity controls both the colored ink used for highlights and the primary/secondary/tertiary tonal fields. Zero gives neutral paper and ink while retaining tonal separation for selection; higher values bring more of the selected theme palette into controls and cards. Each field keeps its matching readable foreground. Poster uses a balanced accent, Studio a quieter one, and Reading a restrained middle ground. The editor previews all three tonal roles.

## Paper layers and tint

**Paper & color** offers neutral, primary, secondary, tertiary and custom pigments. Paper tint colors both the panel and inverse focal cards while retaining readable text. Primary/secondary/tertiary follow the active theme palette; a custom pigment stays fixed. This does not change the light/dark mode of other global styles or applications.

**Second paper layer** adds a restrained tinted backing inside the surface bounds. Its 2–6 px depth does not expand the layout or input area. It appears on dock shelves, bar groups/islands, sidebars and opted-in focal cards, not every button. Studio enables the backing and primary paper tint; Reset Editorial returns to single-sheet, theme-following neutral paper.

Editorial retains the dock and bar layouts. Optional glass keeps wallpaper blur beneath the paper; the second sheet uses a stronger pigment and opacity so its stepped edge remains visible. App artwork, meaningful circular indicators and macOS magnification retain their behavior.

**Accent ink** is independent of paper pigment: choose wallpaper primary, secondary, tertiary or a custom accent. It drives active controls, clock highlights, selection fields and the paper backing. Light paper and charcoal keep their intended brightness even when the application theme uses the opposite mode.

## Typography and geometry

Use `Appearance.editorial.displayFamily`, `titleWeight` and `titleTracking` for display headings, with `Appearance.font.pixelSize` and `fontSizeScale`. Apply `titleScale` to headings, not body text. The dashboard greeting is the large display reference; section headings should remain smaller. Reserve uppercase and positive tracking for short metadata, never full descriptions.

Editorial leaves the shared body font's variable axes unset so an explicit `font.weight` remains effective. Use `editorial.labelWeight` and `metadataTracking` for short labels and metadata. Both are adjustable in Voice & ink, with presets and reset restoring their defaults. Input roles (`input`, `inputHover`, `inputFocus`) give text fields and dropdowns the same quiet fill and one keyboard-focus boundary. Use the normal interface font for buttons and reading text, and the number font for stable numeric readouts. Avoid changing a text item's weight by inspecting other properties of its own `font` group.

Use `Appearance.editorial.radius` for cards and `Appearance.rounding.small` for compact controls. Avatars, circular progress indicators and other intrinsically circular content stay circular. Preserve existing minimum sizes, wrapping, focus behavior and hit areas.

## A focal surface

`PanelSurface.editorialFocus` opts an Editorial surface into the inverse background. Its children must use the matching foreground. The property does not change other styles.

```qml
PanelSurface {
    id: card
    property bool editorial: Appearance.editorialEverywhere
    editorialFocus: true
    outlined: false
    implicitHeight: content.implicitHeight + 32

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Your next chapter")
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.huge
            font.weight: card.editorial ? Appearance.editorial.titleWeight : Font.DemiBold
            font.letterSpacing: card.editorial ? Appearance.editorial.titleTracking : 0
            color: card.editorial ? Appearance.editorial.paperOnInk : Appearance.colors.colOnLayer1
            wrapMode: Text.WordWrap
        }
    }
}
```

Import `QtQuick`, `QtQuick.Layouts`, `qs.modules.common` and `qs.modules.common.widgets` in the containing component. A dashboard `DashCard` has the equivalent `inkField` option and exposes matching `colText` and `colSubtext` roles.

## Rules and separation

`EditorialRule` is a single rounded accent mark, 24 pixels at rest and 48 when emphasized, bounded by its available extent. It supports horizontal/vertical placement, `inset` and an explicit `color` for inverse surfaces. It does not draw a second full-width divider.

```qml
EditorialRule {
    Layout.fillWidth: true
    Layout.preferredHeight: 2
    inset: 0
    emphasized: section.expanded
}
```

Place a mark under a section title when it clarifies hierarchy. Do not add it to the outside edge of every panel, every nested card or every button. Do not combine it with another underline for the same state: `SecondaryTabBar` already owns its active indicator. An inverse surface uses `color: Appearance.editorial.paperOnInk` if it needs a mark.

`SettingsCardSection` supplies section typography and the mark. `SettingsGroup` supplies a quiet inner surface without another Editorial border. Reuse those components instead of adding a second frame or left rail. The Material Flower shape is a small optional signature controlled by `editorial.ornaments`, not a replacement for actionable icons.

## State and media

Keep normal, hover, pressed, selected, disabled and keyboard-focus states in the existing button/input primitives. Selection uses a clear fill or one indicator; keyboard focus retains a visible boundary. Derive durations from `Appearance.animation` so Editorial motion scaling and reduced motion remain effective.

Media presets expose `blendedColors` for their host and use `effectiveColors` to resolve Editorial's solid palette without changing that public input. Keep album artwork in its dedicated image; background artwork washes should not obscure text in compact Editorial cards. Full artwork layouts may retain artwork as their content.

When adding a component, compare it with the dashboard greeting, Settings sections and Overview header. Check it with real content in both light and dark mode, constrained widths, selected/disabled/focused states and any supported layout variants. A global token does not automatically replace component-local colors, image washes or explicit geometry: those need deliberate adaptation in the owning component.

## Settings presentation

Choose **Modules → Settings UI → Overlay layout → Editorial** for the paper studio presentation opened by the bar Settings action. It shares navigation, search and pages with the rail layout. Pair it with the Editorial global style for the complete page and control treatment. Selected navigation uses its tonal field without an additional vertical ornament. Controls use tonal press feedback and stable geometry; Editorial selectors do not expand or bounce when pressed. Editor sliders preview their value while dragging and persist on release.
