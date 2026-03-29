#!/usr/bin/env python3
"""
Generate VSCode color customizations from iNiR theme data.
Injects into settings.json for instant auto-reload (no extension needed).
"""

import json
import os
import re
import sys
from pathlib import Path


# ── Color manipulation helpers ──────────────────────────────────────────


def _hex_to_hsl(hex_color: str):
    """Convert hex color to (h, s, l) where h in [0,360), s,l in [0,1]."""
    hex_color = hex_color.lstrip("#")
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    max_c = max(r, g, b)
    min_c = min(r, g, b)
    l = (max_c + min_c) / 2.0
    if max_c == min_c:
        return (0.0, 0.0, l)
    d = max_c - min_c
    s = d / (2.0 - max_c - min_c) if l > 0.5 else d / (max_c + min_c)
    if max_c == r:
        h = (g - b) / d + (6 if g < b else 0)
    elif max_c == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    return (h * 60.0, s, l)


def _hsl_to_hex(h: float, s: float, l: float) -> str:
    """Convert (h, s, l) back to hex color."""
    s = max(0.0, min(1.0, s))
    l = max(0.0, min(1.0, l))
    h = h % 360.0
    c = (1.0 - abs(2.0 * l - 1.0)) * s
    x = c * (1.0 - abs((h / 60.0) % 2.0 - 1.0))
    m = l - c / 2.0
    if h < 60:
        r, g, b = c, x, 0
    elif h < 120:
        r, g, b = x, c, 0
    elif h < 180:
        r, g, b = 0, c, x
    elif h < 240:
        r, g, b = 0, x, c
    elif h < 300:
        r, g, b = x, 0, c
    else:
        r, g, b = c, 0, x
    return f"#{int((r + m) * 255):02x}{int((g + m) * 255):02x}{int((b + m) * 255):02x}"


def _saturate(hex_color: str, factor: float, min_saturation: float = 0.35) -> str:
    """Boost saturation with an additive minimum floor for very muted inputs."""
    h, s, l = _hex_to_hsl(hex_color)
    if s < 0.01:  # achromatic — can't saturate
        return hex_color
    s = max(min_saturation, min(1.0, s * factor))
    return _hsl_to_hex(h, s, l)


def _blend_colors(base: str, accent: str, ratio: float) -> str:
    """Blend base color with accent. ratio=0.4 means 60% base + 40% accent."""
    base = base.lstrip("#")
    accent = accent.lstrip("#")
    r = int(int(base[0:2], 16) * (1 - ratio) + int(accent[0:2], 16) * ratio)
    g = int(int(base[2:4], 16) * (1 - ratio) + int(accent[2:4], 16) * ratio)
    b = int(int(base[4:6], 16) * (1 - ratio) + int(accent[4:6], 16) * ratio)
    return f"#{min(255, r):02x}{min(255, g):02x}{min(255, b):02x}"


def _adjust_lightness(
    hex_color: str, target_min: float = 0.55, target_max: float = 0.80
) -> str:
    """Clamp lightness into a readable range for dark editor backgrounds."""
    h, s, l = _hex_to_hsl(hex_color)
    l = max(target_min, min(target_max, l))
    return _hsl_to_hex(h, s, l)


def generate_vscode_colors(colors, scss_path):
    """Generate VSCode workbench.colorCustomizations from iNiR theme data."""

    # Parse terminal colors from SCSS
    term_colors = {}
    try:
        with open(scss_path, "r") as f:
            for line in f:
                match = re.match(r"\$(\w+):\s*(#[A-Fa-f0-9]{6});", line.strip())
                if match:
                    name, value = match.groups()
                    term_colors[name] = value
    except FileNotFoundError:
        pass

    # Extract Material You tokens (matugen uses snake_case)
    bg = colors.get("background", colors.get("surface", "#080809"))
    fg = colors.get("on_background", colors.get("on_surface", "#e3dfd9"))
    surface = colors.get("surface", "#080809")
    surface_lowest = colors.get("surface_container_lowest", surface)
    surface_low = colors.get("surface_container_low", "#0c0c0e")
    surface_std = colors.get("surface_container", "#121115")
    surface_high = colors.get("surface_container_high", "#1a191d")
    surface_highest = colors.get("surface_container_highest", "#232126")
    surface_variant = colors.get("surface_variant", "#2a282e")
    on_surface = colors.get("on_surface", "#e3dfd9")
    on_surface_variant = colors.get("on_surface_variant", "#c4bfb8")
    outline = colors.get("outline", "#5c5862")
    outline_variant = colors.get("outline_variant", "#3a363e")

    primary = colors.get("primary", "#d4b796")
    on_primary = colors.get("on_primary", "#241c14")
    primary_container = colors.get("primary_container", "#33281d")
    on_primary_container = colors.get("on_primary_container", "#eddccb")

    secondary = colors.get("secondary", "#ccc2b2")
    tertiary = colors.get("tertiary", "#b8cbb8")
    error = colors.get("error", "#ffb4ab")

    # Terminal colors (Material-derived fallbacks; avoid legacy fixed palettes)
    terminal_defaults = {
        "term0": surface_lowest,
        "term1": error,
        "term2": tertiary,
        "term3": secondary,
        "term4": primary,
        "term5": secondary,
        "term6": tertiary,
        "term7": on_surface,
        "term8": outline_variant,
        "term9": error,
        "term10": tertiary,
        "term11": secondary,
        "term12": primary,
        "term13": secondary,
        "term14": tertiary,
        "term15": fg,
    }

    def term(name):
        return term_colors.get(name, terminal_defaults[name])

    term_bg = term("term0")
    term_fg = term("term15")

    transparent = "#00000000"

    # Build VSCode color customizations
    vscode_colors = {
        # === Base Colors ===
        "focusBorder": primary,
        "foreground": fg,
        "disabledForeground": on_surface_variant + "80",
        "widget.shadow": "#00000060",
        "selection.background": primary + "60",
        "descriptionForeground": on_surface_variant,
        "errorForeground": error,
        "icon.foreground": on_surface,
        # === Window Border ===
        "window.activeBorder": transparent,
        "window.inactiveBorder": transparent,
        # === Text Colors ===
        "textBlockQuote.background": surface_low,
        "textBlockQuote.border": transparent,
        "textCodeBlock.background": surface_low,
        "textLink.activeForeground": primary,
        "textLink.foreground": primary,
        "textPreformat.foreground": tertiary,
        "textSeparator.foreground": transparent,
        # === Button (filled) ===
        "button.background": primary_container,
        "button.foreground": on_primary_container,
        "button.hoverBackground": primary_container + "dd",
        "button.secondaryBackground": surface_high,
        "button.secondaryForeground": on_surface,
        "button.secondaryHoverBackground": surface_highest,
        # === Checkbox ===
        "checkbox.background": surface_std,
        "checkbox.border": transparent,
        "checkbox.foreground": on_surface,
        # === Dropdown ===
        "dropdown.background": surface_low,
        "dropdown.border": transparent,
        "dropdown.foreground": on_surface,
        "dropdown.listBackground": surface_std,
        # === Input ===
        "input.background": surface_low,
        "input.border": transparent,
        "input.foreground": on_surface,
        "input.placeholderForeground": on_surface_variant + "80",
        "inputOption.activeBackground": primary + "40",
        "inputOption.activeBorder": primary,
        "inputOption.activeForeground": on_surface,
        "inputValidation.errorBackground": error + "20",
        "inputValidation.errorBorder": error,
        # === Scrollbar ===
        "scrollbar.shadow": "#00000040",
        "scrollbarSlider.activeBackground": on_surface_variant + "80",
        "scrollbarSlider.background": on_surface_variant + "40",
        "scrollbarSlider.hoverBackground": on_surface_variant + "60",
        # === Badge ===
        "badge.background": primary_container,
        "badge.foreground": on_primary_container,
        # === Progress Bar ===
        "progressBar.background": primary,
        # === Lists and Trees ===
        "list.activeSelectionBackground": surface_high,
        "list.activeSelectionForeground": on_surface,
        "list.dropBackground": primary + "40",
        "list.focusBackground": surface_high,
        "list.focusForeground": on_surface,
        "list.highlightForeground": primary,
        "list.hoverBackground": surface_std,
        "list.hoverForeground": on_surface,
        "list.inactiveSelectionBackground": surface_std,
        "list.inactiveSelectionForeground": on_surface,
        "list.invalidItemForeground": error,
        "list.errorForeground": error,
        "list.warningForeground": tertiary,
        "listFilterWidget.background": surface_high,
        "listFilterWidget.outline": primary,
        "listFilterWidget.noMatchesOutline": error,
        "list.filterMatchBackground": primary + "40",
        "tree.indentGuidesStroke": outline_variant + "40",
        # === Activity Bar ===
        "activityBar.background": surface_lowest,
        "activityBar.foreground": on_surface,
        "activityBar.inactiveForeground": on_surface_variant,
        "activityBar.border": transparent,
        "activityBarBadge.background": primary,
        "activityBarBadge.foreground": on_primary,
        "activityBar.activeBorder": primary,
        "activityBar.activeBackground": surface_std,
        # === Side Bar ===
        "sideBar.background": surface_lowest,
        "sideBar.foreground": on_surface,
        "sideBar.border": transparent,
        "sideBarTitle.foreground": on_surface,
        "sideBarSectionHeader.background": surface_low,
        "sideBarSectionHeader.foreground": on_surface,
        "sideBarSectionHeader.border": transparent,
        # === Editor Groups & Tabs ===
        "editorGroup.border": transparent,
        "editorGroup.dropBackground": primary + "20",
        "editorGroupHeader.noTabsBackground": surface_lowest,
        "editorGroupHeader.tabsBackground": surface_lowest,
        "editorGroupHeader.tabsBorder": transparent,
        "editorGroupHeader.border": transparent,
        "tab.activeBackground": surface_low,
        "tab.activeForeground": on_surface,
        "tab.border": transparent,
        "tab.activeBorder": primary,
        "tab.unfocusedActiveBorder": outline,
        "tab.inactiveBackground": surface_lowest,
        "tab.inactiveForeground": on_surface_variant,
        "tab.unfocusedActiveForeground": on_surface_variant,
        "tab.unfocusedInactiveForeground": on_surface_variant + "80",
        "tab.hoverBackground": surface_low,
        "tab.unfocusedHoverBackground": surface_low,
        "tab.hoverForeground": on_surface,
        "tab.hoverBorder": outline,
        "tab.lastPinnedBorder": outline,
        # === Editor ===
        "editor.background": bg,
        "editor.foreground": fg,
        "editorPane.background": bg,
        "editorGutter.background": bg,
        "editorOverviewRuler.background": bg,
        "editorStickyScroll.background": bg,
        "editorStickyScrollHover.background": surface_low,
        "editorLineNumber.foreground": on_surface_variant,
        "editorLineNumber.activeForeground": on_surface,
        "editorCursor.foreground": primary,
        "editor.selectionBackground": primary_container + "66",
        "editor.inactiveSelectionBackground": primary_container + "33",
        "editor.selectionHighlightBackground": primary_container + "4d",
        "editor.wordHighlightBackground": secondary + "30",
        "editor.wordHighlightStrongBackground": secondary + "50",
        "editor.findMatchBackground": tertiary + "40",
        "editor.findMatchHighlightBackground": tertiary + "30",
        "editor.findRangeHighlightBackground": primary + "20",
        "editor.hoverHighlightBackground": primary + "20",
        "editor.lineHighlightBackground": surface_low + "80",
        "editor.lineHighlightBorder": outline_variant + "00",
        "editorLink.activeForeground": primary,
        "editor.rangeHighlightBackground": surface_std + "40",
        "editorWhitespace.foreground": on_surface_variant + "40",
        "editorIndentGuide.background": outline_variant,
        "editorIndentGuide.activeBackground": outline,
        "editorRuler.foreground": outline_variant,
        "editorCodeLens.foreground": on_surface_variant,
        "editorBracketMatch.background": primary + "20",
        "editorBracketMatch.border": primary,
        # === Diff Editor ===
        "diffEditor.insertedTextBackground": tertiary + "20",
        "diffEditor.removedTextBackground": error + "20",
        "diffEditor.insertedLineBackground": tertiary + "15",
        "diffEditor.removedLineBackground": error + "15",
        "diffEditor.diagonalFill": outline_variant + "80",
        "diffEditor.border": transparent,
        # === Editor Widget ===
        "editorWidget.background": surface_high,
        "editorWidget.border": outline,
        "editorWidget.foreground": on_surface,
        "editorSuggestWidget.background": surface_high,
        "editorSuggestWidget.border": outline,
        "editorSuggestWidget.foreground": on_surface,
        "editorSuggestWidget.highlightForeground": primary,
        "editorSuggestWidget.selectedBackground": surface_highest,
        "editorHoverWidget.background": surface_high,
        "editorHoverWidget.border": outline,
        # === Peek View ===
        "peekView.border": primary,
        "peekViewEditor.background": surface_low,
        "peekViewEditorGutter.background": surface_low,
        "peekViewEditor.matchHighlightBackground": primary + "40",
        "peekViewResult.background": surface_std,
        "peekViewResult.fileForeground": on_surface,
        "peekViewResult.lineForeground": on_surface_variant,
        "peekViewResult.matchHighlightBackground": primary + "40",
        "peekViewResult.selectionBackground": surface_high,
        "peekViewResult.selectionForeground": on_surface,
        "peekViewTitle.background": surface_std,
        "peekViewTitleDescription.foreground": on_surface_variant,
        "peekViewTitleLabel.foreground": on_surface,
        # === Merge Conflicts ===
        "merge.currentHeaderBackground": primary + "80",
        "merge.currentContentBackground": primary + "20",
        "merge.incomingHeaderBackground": secondary + "80",
        "merge.incomingContentBackground": secondary + "20",
        "merge.border": outline,
        "mergeEditor.background": bg,
        "editorOverviewRuler.currentContentForeground": primary,
        "editorOverviewRuler.incomingContentForeground": secondary,
        # === Panel ===
        "panel.background": surface_lowest,
        "panel.border": transparent,
        "panelTitle.activeBorder": primary,
        "panelTitle.activeForeground": on_surface,
        "panelTitle.inactiveForeground": on_surface_variant,
        "panelInput.border": outline,
        # === Status Bar ===
        "statusBar.background": surface_lowest,
        "statusBar.foreground": on_surface,
        "statusBar.border": transparent,
        "statusBar.debuggingBackground": error,
        "statusBar.debuggingForeground": on_primary,
        "statusBar.noFolderBackground": surface_lowest,
        "statusBar.noFolderForeground": on_surface,
        "statusBarItem.activeBackground": surface_high,
        "statusBarItem.hoverBackground": surface_std,
        "statusBarItem.prominentBackground": primary_container,
        "statusBarItem.prominentForeground": on_primary_container,
        "statusBarItem.prominentHoverBackground": primary_container + "dd",
        # === Title Bar ===
        "titleBar.activeBackground": surface_lowest,
        "titleBar.activeForeground": on_surface,
        "titleBar.inactiveBackground": surface_lowest,
        "titleBar.inactiveForeground": on_surface_variant,
        "titleBar.border": transparent,
        # === Menu Bar ===
        "menubar.selectionForeground": on_surface,
        "menubar.selectionBackground": surface_std,
        "menu.foreground": on_surface,
        "menu.background": surface_high,
        "menu.selectionForeground": on_surface,
        "menu.selectionBackground": surface_highest,
        "menu.separatorBackground": transparent,
        "menu.border": transparent,
        # === Notifications ===
        "notificationCenter.border": transparent,
        "notificationCenterHeader.foreground": on_surface,
        "notificationCenterHeader.background": surface_std,
        "notificationToast.border": transparent,
        "notifications.foreground": on_surface,
        "notifications.background": surface_high,
        "notifications.border": transparent,
        "notificationLink.foreground": primary,
        # === Extensions ===
        "extensionButton.prominentForeground": on_primary,
        "extensionButton.prominentBackground": primary,
        "extensionButton.prominentHoverBackground": primary + "dd",
        # === Quick Picker ===
        "pickerGroup.border": outline,
        "pickerGroup.foreground": primary,
        "quickInput.background": surface_high,
        "quickInput.foreground": on_surface,
        # === Integrated Terminal ===
        "terminal.background": term_bg,
        "terminal.foreground": term_fg,
        "terminal.ansiBlack": term("term0"),
        "terminal.ansiRed": term("term1"),
        "terminal.ansiGreen": term("term2"),
        "terminal.ansiYellow": term("term3"),
        "terminal.ansiBlue": term("term4"),
        "terminal.ansiMagenta": term("term5"),
        "terminal.ansiCyan": term("term6"),
        "terminal.ansiWhite": term("term7"),
        "terminal.ansiBrightBlack": term("term8"),
        "terminal.ansiBrightRed": term("term9"),
        "terminal.ansiBrightGreen": term("term10"),
        "terminal.ansiBrightYellow": term("term11"),
        "terminal.ansiBrightBlue": term("term12"),
        "terminal.ansiBrightMagenta": term("term13"),
        "terminal.ansiBrightCyan": term("term14"),
        "terminal.ansiBrightWhite": term("term15"),
        "terminal.selectionBackground": primary + "40",
        "terminalCursor.background": bg,
        "terminalCursor.foreground": primary,
        # === Debug ===
        "debugToolBar.background": surface_high,
        "debugToolBar.border": outline,
        "editor.stackFrameHighlightBackground": tertiary + "30",
        "editor.focusedStackFrameHighlightBackground": tertiary + "50",
        # === Git Decorations ===
        "gitDecoration.addedResourceForeground": tertiary,
        "gitDecoration.modifiedResourceForeground": secondary,
        "gitDecoration.deletedResourceForeground": error,
        "gitDecoration.untrackedResourceForeground": tertiary + "cc",
        "gitDecoration.ignoredResourceForeground": on_surface_variant + "80",
        "gitDecoration.conflictingResourceForeground": error,
        "gitDecoration.submoduleResourceForeground": secondary,
        # === Settings Editor ===
        "settings.headerForeground": on_surface,
        "settings.modifiedItemIndicator": primary,
        "settings.dropdownBackground": surface_low,
        "settings.dropdownForeground": on_surface,
        "settings.dropdownBorder": outline,
        "settings.checkboxBackground": surface_std,
        "settings.checkboxForeground": on_surface,
        "settings.checkboxBorder": outline,
        "settings.textInputBackground": surface_low,
        "settings.textInputForeground": on_surface,
        "settings.textInputBorder": outline,
        "settings.numberInputBackground": surface_low,
        "settings.numberInputForeground": on_surface,
        "settings.numberInputBorder": outline,
        # === Breadcrumbs ===
        "breadcrumb.foreground": on_surface_variant,
        "breadcrumb.background": bg,
        "breadcrumb.focusForeground": on_surface,
        "breadcrumb.activeSelectionForeground": primary,
        "breadcrumbPicker.background": surface_high,
        # === Snippets ===
        "editor.snippetTabstopHighlightBackground": primary + "30",
        "editor.snippetTabstopHighlightBorder": primary,
        "editor.snippetFinalTabstopHighlightBackground": tertiary + "30",
        "editor.snippetFinalTabstopHighlightBorder": tertiary,
        # === Symbol Icons ===
        "symbolIcon.arrayForeground": secondary,
        "symbolIcon.booleanForeground": tertiary,
        "symbolIcon.classForeground": primary,
        "symbolIcon.colorForeground": secondary,
        "symbolIcon.constantForeground": tertiary,
        "symbolIcon.constructorForeground": primary,
        "symbolIcon.enumeratorForeground": secondary,
        "symbolIcon.enumeratorMemberForeground": tertiary,
        "symbolIcon.eventForeground": error,
        "symbolIcon.fieldForeground": secondary,
        "symbolIcon.fileForeground": on_surface,
        "symbolIcon.folderForeground": on_surface,
        "symbolIcon.functionForeground": primary,
        "symbolIcon.interfaceForeground": secondary,
        "symbolIcon.keyForeground": tertiary,
        "symbolIcon.keywordForeground": secondary,
        "symbolIcon.methodForeground": primary,
        "symbolIcon.moduleForeground": on_surface,
        "symbolIcon.namespaceForeground": on_surface,
        "symbolIcon.nullForeground": on_surface_variant,
        "symbolIcon.numberForeground": tertiary,
        "symbolIcon.objectForeground": secondary,
        "symbolIcon.operatorForeground": secondary,
        "symbolIcon.packageForeground": on_surface,
        "symbolIcon.propertyForeground": secondary,
        "symbolIcon.referenceForeground": secondary,
        "symbolIcon.snippetForeground": tertiary,
        "symbolIcon.stringForeground": tertiary,
        "symbolIcon.structForeground": primary,
        "symbolIcon.textForeground": on_surface,
        "symbolIcon.typeParameterForeground": secondary,
        "symbolIcon.unitForeground": tertiary,
        "symbolIcon.variableForeground": on_surface,
        # === Notebooks (Jupyter) ===
        "notebook.editorBackground": bg,
        "notebook.cellEditorBackground": bg,
        "notebook.cellBorderColor": transparent,
        "notebook.cellToolbarSeparator": transparent,
        "notebook.focusedCellBackground": bg,
        "notebookStatusRunningIcon.foreground": primary,
    }

    return vscode_colors


def generate_vscode_syntax(colors, term_colors):
    """Generate VSCode editor.tokenColorCustomizations for syntax highlighting.

    Uses ANSI terminal palette (term1-6) which always has distinct hues even
    with very desaturated/greyscale wallpapers.  Each syntax color gets a
    saturation boost and a configurable blend with the theme's primary color
    so the result feels cohesive rather than random.
    """

    primary = colors.get("primary", "#d4b796")
    on_surface = colors.get("on_surface", "#e3dfd9")
    on_surface_variant = colors.get("on_surface_variant", "#c4bfb8")
    error = colors.get("error", "#ffb4ab")

    # ANSI palette: always has distinct hues regardless of wallpaper saturation
    # term1=red  term2=green  term3=yellow  term4=blue  term5=magenta  term6=cyan
    t = lambda n: term_colors.get(f"term{n}", "#888888")

    # Mix a percentage of the primary color into each syntax color for cohesion
    mix_ratio = 0.40

    def syntax_color(term_idx: int) -> str:
        """Saturate a terminal color and blend with primary."""
        raw = t(term_idx)
        boosted = _saturate(raw, 1.6, min_saturation=0.40)
        blended = _blend_colors(boosted, primary, mix_ratio)
        return _adjust_lightness(blended, target_min=0.55, target_max=0.82)

    col_keyword = syntax_color(5)  # magenta → keywords, operators
    col_string = syntax_color(2)  # green   → strings, literals
    col_function = syntax_color(4)  # blue    → functions, methods
    col_type = syntax_color(6)  # cyan    → types, classes
    col_constant = syntax_color(3)  # yellow  → numbers, constants
    col_tag = syntax_color(1)  # red     → tags, special
    col_property = _blend_colors(
        syntax_color(4), syntax_color(6), 0.5
    )  # blue-cyan → properties
    col_error = _saturate(error, 1.4, min_saturation=0.50)

    syntax_rules = [
        # Comments — muted, italic
        {
            "scope": ["comment", "punctuation.definition.comment"],
            "settings": {
                "foreground": on_surface_variant + "aa",
                "fontStyle": "italic",
            },
        },
        {
            "scope": ["comment.block.documentation", "comment.block.javadoc"],
            "settings": {
                "foreground": on_surface_variant + "cc",
                "fontStyle": "italic",
            },
        },
        # Keywords & storage
        {
            "scope": ["keyword", "storage.type", "storage.modifier"],
            "settings": {"foreground": col_keyword},
        },
        {
            "scope": ["keyword.control", "keyword.control.flow"],
            "settings": {"foreground": col_keyword},
        },
        {
            "scope": ["keyword.operator", "keyword.operator.assignment"],
            "settings": {"foreground": col_keyword},
        },
        {"scope": ["keyword.other.unit"], "settings": {"foreground": col_constant}},
        # Constants & numbers
        {
            "scope": ["constant", "constant.language", "constant.character"],
            "settings": {"foreground": col_constant},
        },
        {
            "scope": [
                "constant.numeric",
                "constant.numeric.integer",
                "constant.numeric.float",
            ],
            "settings": {"foreground": col_constant},
        },
        {
            "scope": ["constant.other.color", "constant.other.symbol"],
            "settings": {"foreground": col_constant},
        },
        # Strings & literals
        {"scope": ["string", "string.quoted"], "settings": {"foreground": col_string}},
        {"scope": ["string.regexp"], "settings": {"foreground": col_tag}},
        {
            "scope": ["string.template", "string.interpolated"],
            "settings": {"foreground": col_string},
        },
        {"scope": ["string.other.link"], "settings": {"foreground": col_function}},
        {
            "scope": ["punctuation.definition.string"],
            "settings": {"foreground": col_string},
        },
        {
            "scope": ["constant.character.escape", "string.escape"],
            "settings": {"foreground": col_tag},
        },
        # Functions & methods
        {
            "scope": ["entity.name.function", "support.function"],
            "settings": {"foreground": col_function},
        },
        {
            "scope": ["meta.function-call", "entity.name.function.call"],
            "settings": {"foreground": col_function},
        },
        {
            "scope": ["support.function.builtin"],
            "settings": {"foreground": col_function},
        },
        {
            "scope": ["entity.name.function.decorator", "meta.decorator"],
            "settings": {"foreground": col_tag, "fontStyle": "italic"},
        },
        # Classes, types & interfaces
        {
            "scope": [
                "entity.name.type",
                "entity.name.class",
                "support.type",
                "support.class",
            ],
            "settings": {"foreground": col_type},
        },
        {
            "scope": ["entity.other.inherited-class"],
            "settings": {"foreground": col_type, "fontStyle": "italic"},
        },
        {"scope": ["entity.name.type.interface"], "settings": {"foreground": col_type}},
        {"scope": ["entity.name.type.enum"], "settings": {"foreground": col_type}},
        {
            "scope": ["support.type.builtin", "support.type.primitive"],
            "settings": {"foreground": col_type},
        },
        # Variables
        {
            "scope": ["variable", "variable.other"],
            "settings": {"foreground": on_surface},
        },
        {
            "scope": ["variable.language"],
            "settings": {"foreground": col_tag, "fontStyle": "italic"},
        },
        {
            "scope": ["variable.parameter", "variable.parameter.function"],
            "settings": {"foreground": on_surface},
        },
        # Properties & attributes
        {
            "scope": [
                "variable.other.property",
                "support.variable.property",
                "variable.other.object.property",
            ],
            "settings": {"foreground": col_property},
        },
        {
            "scope": ["entity.other.attribute-name"],
            "settings": {"foreground": col_property},
        },
        {
            "scope": ["meta.object-literal.key"],
            "settings": {"foreground": col_property},
        },
        # Tags (HTML/XML/JSX)
        {"scope": ["entity.name.tag"], "settings": {"foreground": col_tag}},
        {"scope": ["punctuation.definition.tag"], "settings": {"foreground": col_tag}},
        {"scope": ["entity.name.tag.css"], "settings": {"foreground": col_type}},
        {
            "scope": ["support.type.property-name.css"],
            "settings": {"foreground": col_property},
        },
        {
            "scope": ["support.constant.property-value.css"],
            "settings": {"foreground": col_constant},
        },
        # Punctuation
        {"scope": ["punctuation"], "settings": {"foreground": on_surface}},
        {
            "scope": ["punctuation.separator", "punctuation.terminator"],
            "settings": {"foreground": on_surface_variant},
        },
        {
            "scope": ["punctuation.section.embedded"],
            "settings": {"foreground": col_tag},
        },
        # Markup (Markdown)
        {
            "scope": ["markup.heading"],
            "settings": {"foreground": col_function, "fontStyle": "bold"},
        },
        {
            "scope": ["markup.bold"],
            "settings": {"foreground": on_surface, "fontStyle": "bold"},
        },
        {
            "scope": ["markup.italic"],
            "settings": {"foreground": on_surface, "fontStyle": "italic"},
        },
        {
            "scope": ["markup.underline.link"],
            "settings": {"foreground": col_function, "fontStyle": "underline"},
        },
        {
            "scope": ["markup.inline.raw", "markup.fenced_code"],
            "settings": {"foreground": col_string},
        },
        {"scope": ["markup.list"], "settings": {"foreground": col_keyword}},
        {"scope": ["markup.deleted"], "settings": {"foreground": col_error}},
        {"scope": ["markup.inserted"], "settings": {"foreground": col_string}},
        {"scope": ["markup.changed"], "settings": {"foreground": col_constant}},
        # Invalid
        {"scope": ["invalid"], "settings": {"foreground": col_error}},
        {
            "scope": ["invalid.deprecated"],
            "settings": {"foreground": col_error, "fontStyle": "italic strikethrough"},
        },
    ]

    return syntax_rules


def generate_vscode_semantic_tokens(colors, term_colors):
    """Generate VSCode semantic token rules using ANSI terminal palette.

    Mirrors the syntax highlighting approach: terminal palette colors with
    saturation boost and primary blending for consistent readability.
    """

    primary = colors.get("primary", "#d4b796")
    on_surface = colors.get("on_surface", "#e3dfd9")
    on_surface_variant = colors.get("on_surface_variant", "#c4bfb8")
    error = colors.get("error", "#ffb4ab")

    t = lambda n: term_colors.get(f"term{n}", "#888888")
    mix_ratio = 0.40

    def sc(term_idx: int) -> str:
        raw = t(term_idx)
        boosted = _saturate(raw, 1.6, min_saturation=0.40)
        blended = _blend_colors(boosted, primary, mix_ratio)
        return _adjust_lightness(blended, target_min=0.55, target_max=0.82)

    col_keyword = sc(5)  # magenta
    col_string = sc(2)  # green
    col_function = sc(4)  # blue
    col_type = sc(6)  # cyan
    col_constant = sc(3)  # yellow
    col_tag = sc(1)  # red
    col_property = _blend_colors(sc(4), sc(6), 0.5)
    col_error = _saturate(error, 1.4, min_saturation=0.50)

    return {
        "class": col_type,
        "enum": col_type,
        "enumMember": col_constant,
        "function": col_function,
        "method": col_function,
        "interface": col_type,
        "namespace": col_type,
        "parameter": on_surface,
        "property": col_property,
        "struct": col_type,
        "type": col_type,
        "typeParameter": col_constant,
        "variable": on_surface,
        "variable.constant": col_constant,
        "variable.defaultLibrary": col_tag,
        "comment": on_surface_variant + "aa",
        "keyword": col_keyword,
        "keyword.control": col_keyword,
        "number": col_constant,
        "string": col_string,
        "regexp": col_tag,
        "operator": col_keyword,
        "decorator": col_tag,
    }


def merge_settings_json(
    settings_path, color_customizations, token_customizations, semantic_tokens
):
    """Intelligently merge color customizations into existing settings.json."""

    settings_path = Path(settings_path)
    settings_path.parent.mkdir(parents=True, exist_ok=True)

    # Read existing settings
    if settings_path.exists():
        try:
            with open(settings_path, "r") as f:
                settings = json.load(f)
        except json.JSONDecodeError:
            print(
                f"Warning: Could not parse {settings_path}, creating backup",
                file=sys.stderr,
            )
            backup_path = settings_path.with_suffix(".json.backup")
            settings_path.rename(backup_path)
            settings = {}
    else:
        settings = {}

    # Merge color customizations (replace entirely to ensure consistency)
    settings["workbench.colorCustomizations"] = color_customizations
    settings["editor.tokenColorCustomizations"] = {
        "textMateRules": token_customizations
    }
    settings["editor.semanticTokenColorCustomizations"] = {
        "enabled": True,
        "rules": semantic_tokens,
    }

    # Write back with pretty formatting
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)

    return True


def generate_vscode_theme(colors_json_path, scss_path, settings_path):
    """Main function to generate and apply VSCode theme."""

    # Read Material You colors
    try:
        with open(colors_json_path, "r") as f:
            colors = json.load(f)
    except FileNotFoundError:
        print(f"Error: Could not find {colors_json_path}", file=sys.stderr)
        return False

    # Parse terminal colors
    term_colors = {}
    try:
        with open(scss_path, "r") as f:
            for line in f:
                match = re.match(r"\$(\w+):\s*(#[A-Fa-f0-9]{6});", line.strip())
                if match:
                    name, value = match.groups()
                    term_colors[name] = value
    except FileNotFoundError:
        print(f"Warning: Could not find {scss_path}, using defaults", file=sys.stderr)

    # Generate color customizations
    color_customizations = generate_vscode_colors(colors, scss_path)
    syntax_customizations = generate_vscode_syntax(colors, term_colors)
    semantic_customizations = generate_vscode_semantic_tokens(colors, term_colors)

    # Merge into settings.json
    success = merge_settings_json(
        settings_path,
        color_customizations,
        syntax_customizations,
        semantic_customizations,
    )

    if success:
        print("✓ Generated VSCode theme (auto-reloads instantly)")
        return True
    else:
        print("✗ Failed to generate VSCode theme", file=sys.stderr)
        return False


# All known VSCode forks and their config paths
VSCODE_FORKS = {
    "code": "Code",  # Official VSCode
    "codium": "VSCodium",  # VSCodium (FOSS build)
    "code-oss": "Code - OSS",  # Arch/community OSS build
    "code-insiders": "Code - Insiders",  # Insiders preview
    "cursor": "Cursor",  # Cursor AI editor
    "windsurf": "Windsurf",  # Windsurf AI editor
    "windsurf-next": "Windsurf - Next",  # Windsurf preview
    "qoder": "Qoder",  # Qoder editor
    "antigravity": "Antigravity",  # Antigravity editor
    "positron": "Positron",  # Posit's data science IDE
    "void": "Void",  # Void editor
    "melty": "Melty",  # Melty editor
    "pearai": "PearAI",  # PearAI editor
    "aide": "Aide",  # Aide editor
}


def get_settings_path(fork_name: str) -> Path:
    """Get the settings.json path for a VSCode fork."""
    config_dir = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    return Path(config_dir) / fork_name / "User" / "settings.json"


def strip_vscode_theme(settings_path: str) -> bool:
    """Remove iNiR color customizations from a VSCode settings.json.

    Called when the user disables VSCode theming from Settings UI.
    Removes workbench.colorCustomizations, editor.tokenColorCustomizations,
    and editor.semanticTokenColorCustomizations entirely.
    """
    settings_path = Path(settings_path)
    if not settings_path.exists():
        return True  # nothing to strip

    try:
        with open(settings_path, "r") as f:
            settings = json.load(f)
    except (json.JSONDecodeError, OSError):
        return False

    changed = False
    for key in [
        "workbench.colorCustomizations",
        "editor.tokenColorCustomizations",
        "editor.semanticTokenColorCustomizations",
    ]:
        if key in settings:
            del settings[key]
            changed = True

    if changed:
        try:
            with open(settings_path, "w") as f:
                json.dump(settings, f, indent=2, ensure_ascii=False)
            print(f"✓ Stripped iNiR theme from {settings_path}")
        except OSError as e:
            print(f"✗ Failed to write {settings_path}: {e}", file=sys.stderr)
            return False

    return True


def strip_all_vscode_themes(forks: list = None):
    """Strip iNiR theme from multiple VSCode forks."""
    if forks is None:
        forks = [
            key
            for key, name in VSCODE_FORKS.items()
            if get_settings_path(name).parent.exists()
        ]

    results = {}
    for fork_key in forks:
        fork_name = VSCODE_FORKS.get(fork_key)
        if not fork_name:
            continue
        settings_path = get_settings_path(fork_name)
        if not settings_path.exists():
            continue
        success = strip_vscode_theme(str(settings_path))
        results[fork_key] = success
        if success:
            print(f"  ✓ {fork_name}")
        else:
            print(f"  ✗ {fork_name}", file=sys.stderr)
    return results


def generate_all_vscode_themes(
    colors_json_path: str, scss_path: str, forks: list = None
):
    """Generate themes for multiple VSCode forks.

    Args:
        colors_json_path: Path to iNiR palette.json (colors.json fallback is still accepted)
        scss_path: Path to material_colors.scss
        forks: List of fork keys to generate for (None = all installed)
    """
    if forks is None:
        # Auto-detect installed forks
        forks = [
            key
            for key, name in VSCODE_FORKS.items()
            if get_settings_path(name).parent.exists()
        ]

    results = {}
    for fork_key in forks:
        fork_name = VSCODE_FORKS.get(fork_key)
        if not fork_name:
            print(f"Unknown fork: {fork_key}", file=sys.stderr)
            continue

        settings_path = get_settings_path(fork_name)
        if not settings_path.parent.exists():
            continue

        success = generate_vscode_theme(colors_json_path, scss_path, str(settings_path))
        results[fork_key] = success
        if success:
            print(f"  ✓ {fork_name}")
        else:
            print(f"  ✗ {fork_name}", file=sys.stderr)

    return results


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate VSCode theme from Material You colors"
    )
    parser.add_argument(
        "--colors",
        type=str,
        default=os.path.expanduser(
            "~/.local/state/quickshell/user/generated/palette.json"
        ),
    )
    parser.add_argument(
        "--scss",
        type=str,
        default=os.path.expanduser(
            "~/.local/state/quickshell/user/generated/material_colors.scss"
        ),
    )
    parser.add_argument(
        "--output", type=str, default=None, help="Single output path (legacy mode)"
    )
    parser.add_argument(
        "--forks",
        type=str,
        nargs="*",
        default=None,
        help=f"Forks to generate for. Options: {', '.join(VSCODE_FORKS.keys())}. Default: all installed",
    )
    parser.add_argument(
        "--list-forks", action="store_true", help="List all known forks and exit"
    )
    parser.add_argument(
        "--strip",
        action="store_true",
        help="Remove iNiR color customizations from settings.json (used when disabling theming)",
    )

    args = parser.parse_args()

    if args.strip:
        results = strip_all_vscode_themes(args.forks)
        stripped = sum(1 for v in results.values() if v)
        print(f"Stripped themes from {stripped}/{len(results)} forks")
        sys.exit(0)

    if args.list_forks:
        print("Known VSCode forks:")
        for key, name in VSCODE_FORKS.items():
            path = get_settings_path(name)
            installed = "✓" if path.parent.exists() else "✗"
            print(f"  [{installed}] {key}: {name} ({path})")
        sys.exit(0)

    if args.output:
        # Legacy single-output mode
        success = generate_vscode_theme(args.colors, args.scss, args.output)
        sys.exit(0 if success else 1)
    else:
        # Multi-fork mode
        results = generate_all_vscode_themes(args.colors, args.scss, args.forks)
        success_count = sum(1 for v in results.values() if v)
        total = len(results)
        print(f"Generated themes for {success_count}/{total} forks")
        sys.exit(0 if success_count > 0 else 1)
