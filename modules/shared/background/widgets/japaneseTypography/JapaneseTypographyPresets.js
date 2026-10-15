.pragma library

function setValue(path, key, value, group) {
    const updates = {};
    updates[path + "." + key] = value;
    if (group === "composition") updates[path + ".preset"] = "custom";
    if (group === "palette") updates[path + ".palettePreset"] = "custom";
    if (group === "font") updates[path + ".fontPreset"] = "custom";
    return updates;
}

function composition(path, preset) {
    const updates = {};
    updates[path + ".preset"] = preset;
    if (preset === "magazine") {
        updates[path + ".primarySize"] = 56;
        updates[path + ".secondarySize"] = 16;
        updates[path + ".primaryColumns"] = 2;
        updates[path + ".secondaryColumns"] = 3;
        updates[path + ".columnGap"] = 12;
        updates[path + ".mirrorLayout"] = true;
        updates[path + ".showSecondary"] = true;
        updates[path + ".showSeal"] = true;
        updates[path + ".showFooter"] = true;
        updates[path + ".showRule"] = true;
        updates[path + ".contentWidth"] = 400;
        updates[path + ".contentHeight"] = 540;
    } else if (preset === "minimal") {
        updates[path + ".primarySize"] = 96;
        updates[path + ".primaryColumns"] = 1;
        updates[path + ".mirrorLayout"] = false;
        updates[path + ".showSecondary"] = false;
        updates[path + ".showSeal"] = false;
        updates[path + ".showFooter"] = false;
        updates[path + ".showRule"] = false;
        updates[path + ".contentWidth"] = 260;
        updates[path + ".contentHeight"] = 560;
    } else if (preset === "traditional") {
        updates[path + ".primarySize"] = 64;
        updates[path + ".secondarySize"] = 17;
        updates[path + ".primaryColumns"] = 2;
        updates[path + ".secondaryColumns"] = 2;
        updates[path + ".columnGap"] = 18;
        updates[path + ".mirrorLayout"] = true;
        updates[path + ".showSecondary"] = true;
        updates[path + ".showSeal"] = true;
        updates[path + ".showFooter"] = false;
        updates[path + ".showRule"] = false;
        updates[path + ".contentWidth"] = 340;
        updates[path + ".contentHeight"] = 620;
    } else {
        updates[path + ".primarySize"] = 72;
        updates[path + ".secondarySize"] = 18;
        updates[path + ".primaryColumns"] = 2;
        updates[path + ".secondaryColumns"] = 2;
        updates[path + ".columnGap"] = 14;
        updates[path + ".mirrorLayout"] = false;
        updates[path + ".showSecondary"] = true;
        updates[path + ".showSeal"] = true;
        updates[path + ".showFooter"] = true;
        updates[path + ".showRule"] = true;
        updates[path + ".contentWidth"] = 330;
        updates[path + ".contentHeight"] = 600;
    }
    return updates;
}

function palette(path, preset) {
    const updates = {};
    updates[path + ".palettePreset"] = preset;
    updates[path + ".paletteMode"] = preset === "adaptive" ? "adaptive" : "manual";
    if (preset === "sumi") {
        updates[path + ".primaryColor"] = "#17130F";
        updates[path + ".secondaryColor"] = "#493D31";
        updates[path + ".detailColor"] = "#6A5847";
        updates[path + ".sealColor"] = "#9D382B";
        updates[path + ".ruleColor"] = "#8B6B49";
    } else if (preset === "ivory") {
        updates[path + ".primaryColor"] = "#F3E8D3";
        updates[path + ".secondaryColor"] = "#D8C3A2";
        updates[path + ".detailColor"] = "#BCA37D";
        updates[path + ".sealColor"] = "#C76049";
        updates[path + ".ruleColor"] = "#C89B61";
    } else if (preset === "sunset") {
        updates[path + ".primaryColor"] = "#E6C49A";
        updates[path + ".secondaryColor"] = "#C39D73";
        updates[path + ".detailColor"] = "#A78261";
        updates[path + ".sealColor"] = "#A94B37";
        updates[path + ".ruleColor"] = "#C47C47";
    } else if (preset === "cinema") {
        updates[path + ".primaryColor"] = "#F1EEE7";
        updates[path + ".secondaryColor"] = "#C9C2B8";
        updates[path + ".detailColor"] = "#AAA299";
        updates[path + ".sealColor"] = "#D9684B";
        updates[path + ".ruleColor"] = "#E0B46A";
    }
    return updates;
}

function font(path, preset) {
    const updates = {};
    updates[path + ".fontPreset"] = preset;
    if (preset === "gothic") {
        updates[path + ".fontFamily"] = "sans-serif";
        updates[path + ".secondaryFontFamily"] = "sans-serif";
        updates[path + ".latinFontFamily"] = "sans-serif";
        updates[path + ".primaryWeight"] = 700;
        updates[path + ".secondaryWeight"] = 500;
        updates[path + ".latinWeight"] = 600;
        updates[path + ".letterSpacing"] = 1;
        updates[path + ".secondaryLetterSpacing"] = 1;
    } else if (preset === "mixed") {
        updates[path + ".fontFamily"] = "serif";
        updates[path + ".secondaryFontFamily"] = "sans-serif";
        updates[path + ".latinFontFamily"] = "sans-serif";
        updates[path + ".primaryWeight"] = 600;
        updates[path + ".secondaryWeight"] = 400;
        updates[path + ".latinWeight"] = 600;
        updates[path + ".letterSpacing"] = 2;
        updates[path + ".secondaryLetterSpacing"] = 1;
    } else {
        updates[path + ".fontFamily"] = "serif";
        updates[path + ".secondaryFontFamily"] = "";
        updates[path + ".latinFontFamily"] = "";
        updates[path + ".primaryWeight"] = 500;
        updates[path + ".secondaryWeight"] = 400;
        updates[path + ".latinWeight"] = 600;
        updates[path + ".letterSpacing"] = 2;
        updates[path + ".secondaryLetterSpacing"] = 1;
    }
    return updates;
}
