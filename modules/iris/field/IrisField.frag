#version 440
// One pass of the iRiS field. Every body iRiS draws on an output is a rounded
// box in a signed-distance field, smooth-unioned: a shape that comes near
// another does not overlap it — the two fuse, and pulling them apart draws a
// neck that thins and lets go. One silhouette, however many things are on it.
//
// A body that paints itself (anything that clips its content, carries a
// hairline, or must stay opaque for reasons of its own) stays in the field for
// the joins it makes. The field is drawn *under* every body, and every body iRiS
// paints is opaque black, so the field fills the whole union and lets the bodies
// cover what they cover. It used to subtract their interiors instead, and that
// subtraction was what made a closing card look like it was switching off the
// piece underneath it: a body on its way out punched its own shape out of the
// bodies it passed over, and they came back the instant it finished. A hole in
// the material is not a morph.
//
// There is one pass, over the bounding box of what it has to draw: `viewport` is
// where it sits on the output and every shape is given in screen pixels. One
// pass and not one per cluster, because the cost of this is per ShaderEffect and
// not per pixel — four small passes measured five times the CPU of a single
// large one, on the same bodies.
//
// Shapes are packed four scalars at a time because a uniform array of structs is
// not portable across the backends Qt targets: `shapeN` is (centre.x, centre.y,
// half.x, half.y) in screen pixels, `radiiA..C` their corner radii and
// `paintsA..C` which of them bring their own material.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // This pass: where it sits on the output, and how big it is.
    vec4 viewport;
    // The output, so the frame can be evaluated in screen space from any pass.
    vec2 screen;
    // x: the default join depth, in pixels, used by the frame. y: 1 while the
    // frame is part of the field. z: the frame's band. w: its inner corner radius.
    vec4 field;
    vec4 tint;
    // The hairline that holds the silhouette over dark windows. One outline for
    // one shape: drawn from the union, so it never crosses a weld, and drawn
    // over the bodies that paint themselves so theirs is the same line.
    vec4 rim;
    // x: how wide that hairline is, in pixels. y: 1 while it is drawn.
    vec4 edge;
    vec4 shape0; vec4 shape1; vec4 shape2; vec4 shape3;
    vec4 shape4; vec4 shape5; vec4 shape6; vec4 shape7;
    vec4 shape8; vec4 shape9; vec4 shape10; vec4 shape11;
    vec4 shape12; vec4 shape13; vec4 shape14; vec4 shape15;
    vec4 shape16; vec4 shape17; vec4 shape18; vec4 shape19;
    vec4 radiiA; vec4 radiiB; vec4 radiiC; vec4 radiiD; vec4 radiiE;
    // Which bodies paint themselves. Kept in the block because the QML side
    // still needs the flag (a body that paints itself brings its own shadow);
    // the union does not treat them differently any more.
    vec4 paintsA; vec4 paintsB; vec4 paintsC; vec4 paintsD; vec4 paintsE;
    // How deep each body's own joins are. A body that is an extension of what
    // opened it melts generously; a satellite beside the Island keeps a crisp
    // edge. The pair takes the depth of whichever body is folded in later, which
    // is the one that arrived — the thing that grew is what decides how it meets
    // what it grew from.
    vec4 fuseA; vec4 fuseB; vec4 fuseC; vec4 fuseD; vec4 fuseE;
    // Whom each body melts into: 0 nothing, -1 the frame, n the shape at n - 1.
    // A body melts only into what it grew from. Folding every body into the
    // union of everything before it made a panel melt into the satellites
    // beside its origin, and a morph that sticks to whatever is near is a
    // simulation of one.
    vec4 joinA; vec4 joinB; vec4 joinC; vec4 joinD; vec4 joinE;
    // A second body it belongs to, same encoding: a satellite grows out of the
    // Island and rests on the edge, and melts into both.
    vec4 alsoA; vec4 alsoB; vec4 alsoC; vec4 alsoD; vec4 alsoE;
    // Each body's material: 0 solid, 1 glass over the blurred wallpaper, 2 glass
    // the compositor blurs from behind.
    vec4 glassA; vec4 glassB; vec4 glassC; vec4 glassD; vec4 glassE;
    // x: 1 once the blurred wallpaper is ready. y: the frame's material, same
    // encoding. z: how much of the tint stays over glass. w: the glass edge light.
    vec4 glass;
    // How far the band's inner line swells on each side (left, top, right,
    // bottom) with the music, and x: the travelling phase of that swell.
    vec4 edgeWave;
    vec4 waveClock;
    // x: appearance (0 sculpted, 1 etched, 2 satin); y: music level;
    // z: light opacity; w: treatment width in screen pixels.
    vec4 frameLight;
    vec4 frameInk;
    // Where this field's window sits on its output (x, y) and the output's size (z, w), so a
    // field in a small window (a menu) samples the wallpaper glass at the right place.
    vec4 scene;
    // x: 1 when another window paints the band, so this field draws only the bodies and their joins.
    vec4 options;
    // Left, top, right, bottom of an inner rectangle nothing reaches: its pixels skip the whole pass.
    vec4 quiet;
    // The colour that lights the cut edge of blurred glass (IrisStyle.glassEdgeColour).
    vec4 sheen;
    // x: light where the edge faces up, y: the line elsewhere, z: its width in pixels.
    vec4 edgeGlass;
} u;
layout(binding = 1) uniform sampler2D backdrop;

const float FAR = 1e8;

float roundedBox(vec2 p, vec2 centre, vec2 halfSize, float radius) {
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 q = abs(p - centre) - (halfSize - r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Polynomial smooth minimum: the join is a fillet `k` pixels deep, which is what
// makes two bodies read as one that swelled rather than two that overlap.
float smoothUnion(float a, float b, float k) {
    if (k <= 0.001)
        return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

vec4 shapeAt(int i) {
    if (i < 8) {
        if (i < 4) return i == 0 ? u.shape0 : i == 1 ? u.shape1 : i == 2 ? u.shape2 : u.shape3;
        return i == 4 ? u.shape4 : i == 5 ? u.shape5 : i == 6 ? u.shape6 : u.shape7;
    }
    if (i < 16) {
        if (i < 12) return i == 8 ? u.shape8 : i == 9 ? u.shape9 : i == 10 ? u.shape10 : u.shape11;
        return i == 12 ? u.shape12 : i == 13 ? u.shape13 : i == 14 ? u.shape14 : u.shape15;
    }
    return i == 16 ? u.shape16 : i == 17 ? u.shape17 : i == 18 ? u.shape18 : u.shape19;
}

float blockValue(int block, int slot, vec4 a, vec4 b, vec4 c, vec4 d, vec4 e) {
    vec4 v = block == 0 ? a : block == 1 ? b : block == 2 ? c : block == 3 ? d : e;
    return slot == 0 ? v.x : slot == 1 ? v.y : slot == 2 ? v.z : v.w;
}

void main() {
    vec2 p = u.viewport.xy + qt_TexCoord0 * max(u.viewport.zw, vec2(1.0));
    if (p.x > u.quiet.x && p.y > u.quiet.y && p.x < u.quiet.z && p.y < u.quiet.w) {
        fragColor = vec4(0.0);
        return;
    }
    float united = FAR * 10.0;

    // The frame is the complement of the screen's inner rounded rectangle: every
    // pixel outside it is material, so the band and its concentric inner corners
    // come out of the same formula the bodies use, and a body that reaches the
    // edge fuses with it instead of sitting on it.
    float frameDistance = FAR * 10.0;
    if (u.field.y > 0.5) {
        // Places can render their own field in a window inset by the band.
        // Sample the frame in output coordinates so their joins stay aligned.
        vec2 frameP = p + u.scene.xy;
        vec2 size = max(u.scene.zw, vec2(1.0));
        float t = u.waveClock.x;
        float alongY = 0.60 + 0.24 * sin(frameP.y * 0.011 + t) + 0.16 * sin(frameP.y * 0.027 - t * 1.4);
        float alongX = 0.60 + 0.24 * sin(frameP.x * 0.009 - t) + 0.16 * sin(frameP.x * 0.023 + t * 1.2);
        vec2 lo = vec2(u.field.z + u.edgeWave.x * alongY, u.field.z + u.edgeWave.y * alongX);
        vec2 hi = size - vec2(u.field.z + u.edgeWave.z * alongY, u.field.z + u.edgeWave.w * alongX);
        frameDistance = -roundedBox(frameP, (lo + hi) * 0.5, max((hi - lo) * 0.5, vec2(0.0)), u.field.w);
        united = frameDistance;
    }
    float frameClusterDistance = frameDistance;

    // Material is blended by a soft minimum of distances, so where a solid body
    // melts into glass the fillet shades from one to the other instead of cutting.
    vec3 weights = vec3(0.0);
    if (u.field.y > 0.5) {
        float w = exp(-clamp(frameDistance, -40.0, 40.0) / 2.0);
        weights += w * vec3(u.glass.y < 0.5 ? 1.0 : 0.0, u.glass.y > 0.5 && u.glass.y < 1.5 ? 1.0 : 0.0, u.glass.y > 1.5 ? 1.0 : 0.0);
    }
    float bodies[20];
    for (int i = 0; i < 20; ++i) {
        vec4 s = shapeAt(i);
        bodies[i] = FAR * 10.0;
        if (s.z <= 0.0 || s.w <= 0.0)
            continue;
        int block = i / 4;
        int slot = i - block * 4;
        float radius = blockValue(block, slot, u.radiiA, u.radiiB, u.radiiC, u.radiiD, u.radiiE);
        bodies[i] = roundedBox(p, s.xy, s.zw, radius);
        united = min(united, bodies[i]);
        float m = blockValue(block, slot, u.glassA, u.glassB, u.glassC, u.glassD, u.glassE);
        float w = exp(-clamp(bodies[i], -40.0, 40.0) / 2.0);
        weights += w * vec3(m < 0.5 ? 1.0 : 0.0, m > 0.5 && m < 1.5 ? 1.0 : 0.0, m > 1.5 ? 1.0 : 0.0);
    }
    // The joins, each only between a body and the one it belongs to. A smooth
    // union is never above the plain one, so taking the minimum adds the fillet
    // there and nowhere else.
    for (int i = 0; i < 20; ++i) {
        if (bodies[i] > FAR)
            continue;
        int block = i / 4;
        int slot = i - block * 4;
        float k = max(0.0, blockValue(block, slot, u.fuseA, u.fuseB, u.fuseC, u.fuseD, u.fuseE));
        float join = blockValue(block, slot, u.joinA, u.joinB, u.joinC, u.joinD, u.joinE);
        float also = blockValue(block, slot, u.alsoA, u.alsoB, u.alsoC, u.alsoD, u.alsoE);
        if (join < -0.5 || join > 0.5) {
            float other = join < 0.0 ? frameDistance : bodies[int(join + 0.5) - 1];
            if (other < FAR) {
                united = min(united, smoothUnion(other, bodies[i], k));
                if (join < 0.0)
                    frameClusterDistance = min(frameClusterDistance, smoothUnion(frameDistance, bodies[i], k));
            }
        }
        if (also < -0.5 || also > 0.5) {
            float other = also < 0.0 ? frameDistance : bodies[int(also + 0.5) - 1];
            if (other < FAR) {
                united = min(united, smoothUnion(other, bodies[i], k));
                if (also < 0.0)
                    frameClusterDistance = min(frameClusterDistance, smoothUnion(frameDistance, bodies[i], k));
            }
        }
    }

    if (united > FAR) {
        fragColor = vec4(0.0);
        return;
    }
    // One pixel of coverage, so the contour stays crisp at any scale.
    float coverage = 1.0 - smoothstep(-0.7, 0.7, united);
    if (u.options.x > 0.5 && u.field.y > 0.5)
        coverage *= smoothstep(-0.7, 0.7, frameDistance);
    float fillAlpha = coverage * u.tint.a * u.qt_Opacity;
    vec3 colour = u.tint.rgb * fillAlpha;
    float alpha = fillAlpha;
    vec3 share = weights / max(1e-4, weights.x + weights.y + weights.z);
    if (u.glass.x < 0.5) { share.x += share.y; share.y = 0.0; }
    if (share.x < 0.999) {
        float a = coverage * u.qt_Opacity;
        vec3 behind = share.y > 0.0 ? texture(backdrop, clamp((p + u.scene.xy) / max(u.scene.zw, vec2(1.0)), 0.0, 1.0)).rgb : vec3(0.0);
        vec4 solid = vec4(u.tint.rgb, 1.0) * u.tint.a;
        vec4 glassy = vec4(mix(behind, u.tint.rgb, u.glass.z), 1.0);
        vec4 blurred = vec4(u.tint.rgb * u.glass.z, u.glass.z);
        vec4 mixed = (solid * share.x + glassy * share.y + blurred * share.z) * a;
        colour = mixed.rgb;
        alpha = mixed.a;
    }
    // Compositor blur has a 1-bit edge (a wl_region, no AA in Niri). The cut edge of the glass catches the
    // light from above, like Liquid Glass: bright where it faces up, a faint line elsewhere, in the scene's own
    // light, so the step reads as the edge of glass and not as a drawn frame.
    if (share.z > 0.0) {
        float depth = -united;
        vec2 g = vec2(dFdx(united), dFdy(united));
        float facing = clamp(-g.y / max(length(g), 1e-4), 0.0, 1.0);
        float lip = coverage * (1.0 - smoothstep(u.edgeGlass.z * 0.4, u.edgeGlass.z + 0.1, depth));
        float seal = lip * mix(u.edgeGlass.y, u.edgeGlass.x, facing * facing) * share.z * u.sheen.a * u.qt_Opacity;
        colour = u.sheen.rgb * seal + colour * (1.0 - seal);
        alpha = seal + alpha * (1.0 - seal);
    }
    if (u.edge.y > 0.5) {
        // A band just inside the silhouette, so it lands on the body's own edge
        // rather than half outside it.
        float inner = 1.0 - smoothstep(-0.7, 0.7, united + max(0.5, u.edge.x));
        float rimAlpha = max(0.0, coverage - inner) * u.rim.a * u.qt_Opacity;
        colour = u.rim.rgb * rimAlpha + colour * (1.0 - rimAlpha);
        alpha = rimAlpha + alpha * (1.0 - rimAlpha);
    }
    // The light follows the frame and the bodies actually joined to it. A
    // floating body has no frame join and keeps its own material and contour.
    if (u.field.y > 0.5 && u.frameLight.x > 0.5 && u.frameLight.y > 0.001) {
        float inside = max(0.0, -frameClusterDistance);
        float wall = 1.0 - smoothstep(-0.7, 0.7, frameClusterDistance);
        float width = max(1.0, u.frameLight.w);
        float etched = 1.0 - smoothstep(0.0, width, abs(inside - 1.25));
        float satin = exp(-inside / (width * 2.4));
        float treatment = u.frameLight.x < 1.5 ? etched : satin;
        float lightAlpha = coverage * wall * treatment * u.frameLight.y * u.frameLight.z * u.qt_Opacity;
        colour = u.frameInk.rgb * lightAlpha + colour * (1.0 - lightAlpha);
        alpha = lightAlpha + alpha * (1.0 - lightAlpha);
    }
    fragColor = vec4(colour, alpha);
}
