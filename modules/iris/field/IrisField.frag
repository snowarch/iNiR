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
    // x: light where the edge faces up, y: the line elsewhere, z: its width in pixels, w: 1 when solid bodies wear it too.
    vec4 edgeGlass;
    // Afterglow (IrisStyle.afterglow*). x: on, y: chrome, z: bloom, w: signal, each 0..1.
    vec4 glowMix;
    // rgb: the grade's shadow hue; a: 1 on a paper scheme.
    vec4 glowShadow;
    // rgb: the grade's key light; a: atmosphere 0..1.
    vec4 glowLight;
    // rgb: the bloom's colour; a: its radius in pixels.
    vec4 glowBloom;
    // x: bevel width, y: scanline pitch, z: convergence, all in pixels.
    vec4 glowShape;
    // The shadow the bodies cast (IrisStyle.shadow): one shadow of the joined silhouette, so a weld or a notch's
    // shoulders cast with the body and two bodies that meet never darken twice. Bodies that paint themselves bring
    // their own. Premultiplied, as Qt hands a QML color to a shader.
    vec4 shade;
    // x: how far down it falls, y: its blur, in pixels; z: 1 while it is drawn.
    vec4 shadeShape;
} u;
layout(binding = 1) uniform sampler2D backdrop;

const float FAR = 1e8;

float roundedBox(vec2 p, vec2 centre, vec2 halfSize, float radius) {
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 q = abs(p - centre) - (halfSize - r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// The chrome bevel's environment by elevation e: -1 ground, 0 horizon, 1 sky.
vec3 chromeAt(float e, vec3 sky, vec3 hot, vec3 ground, vec3 deep) {
    vec3 c = e > 0.0 ? mix(hot, sky, smoothstep(0.0, 0.75, e)) : mix(ground, deep, smoothstep(0.0, 0.55, -e));
    return c + hot * exp(-(e * e) / 0.014) * 0.6;
}

float bayer4(vec2 p) {
    ivec2 i = ivec2(mod(floor(p), 4.0));
    int k = i.x + i.y * 4;
    float m = k == 0 ? 0.0 : k == 1 ? 8.0 : k == 2 ? 2.0 : k == 3 ? 10.0 : k == 4 ? 12.0 : k == 5 ? 4.0 : k == 6 ? 14.0 : k == 7 ? 6.0
        : k == 8 ? 3.0 : k == 9 ? 11.0 : k == 10 ? 1.0 : k == 11 ? 9.0 : k == 12 ? 15.0 : k == 13 ? 7.0 : k == 14 ? 13.0 : 5.0;
    return m / 16.0 - 0.5;
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

// How much of a Gaussian-blurred edge reaches a point `x` sigmas outside it: 0.5 erfc(x / sqrt 2), with erf from an
// exp-only tanh (GLSL ES 1.00 has no tanh).
float blurredEdge(float x) {
    float y = x * 0.70710678;
    float t = 2.0 * y * (1.12838 + 0.10091 * y * y);
    float erfApprox = 1.0 - 2.0 / (exp(clamp(t, -30.0, 30.0)) + 1.0);
    return 0.5 - 0.5 * erfApprox;
}

// Interleaved gradient noise (Jimenez 2014): a dither under a level of 8 bits breaks the bands a blurred wallpaper and
// a long shadow ramp leave, without a texture.
float ign(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
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
    // Places can render their own field in a window inset by the band.
    // Sample the frame in output coordinates so their joins stay aligned.
    vec2 frameP = p + u.scene.xy;
    vec2 size = max(u.scene.zw, vec2(1.0));
    vec2 frameCentre = size * 0.5;
    vec2 frameHalf = size * 0.5;
    if (u.field.y > 0.5) {
        float t = u.waveClock.x;
        float alongY = 0.60 + 0.24 * sin(frameP.y * 0.011 + t) + 0.16 * sin(frameP.y * 0.027 - t * 1.4);
        float alongX = 0.60 + 0.24 * sin(frameP.x * 0.009 - t) + 0.16 * sin(frameP.x * 0.023 + t * 1.2);
        vec2 lo = vec2(u.field.z + u.edgeWave.x * alongY, u.field.z + u.edgeWave.y * alongX);
        vec2 hi = size - vec2(u.field.z + u.edgeWave.z * alongY, u.field.z + u.edgeWave.w * alongX);
        frameCentre = (lo + hi) * 0.5;
        frameHalf = max((hi - lo) * 0.5, vec2(0.0));
        frameDistance = -roundedBox(frameP, frameCentre, frameHalf, u.field.w);
        united = frameDistance;
    }
    float frameClusterDistance = frameDistance;

    // Material is blended by a soft minimum of distances, so where a solid body
    // melts into glass the fillet shades from one to the other instead of cutting.
    vec3 weights = vec3(0.0);
    // Every material solid (the default) skips twenty exponentials a pixel: the branch is uniform.
    bool anyGlass = u.glass.y > 0.5 || dot(u.glassA + u.glassB + u.glassC + u.glassD + u.glassE, vec4(1.0)) > 0.5;
    if (anyGlass && u.field.y > 0.5) {
        float w = exp(-clamp(frameDistance, -40.0, 40.0) / 2.0);
        weights += w * vec3(u.glass.y < 0.5 ? 1.0 : 0.0, u.glass.y > 0.5 && u.glass.y < 1.5 ? 1.0 : 0.0, u.glass.y > 1.5 ? 1.0 : 0.0);
    }
    float bodies[20];
    // What the compositor's blur region holds (IrisBlurRegion): the compositor-glass bodies and their joins with
    // each other; the band and its joins only while the frame is compositor glass too.
    float held = FAR * 10.0;
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
        if (m > 1.5)
            held = min(held, bodies[i]);
        if (anyGlass) {
            float w = exp(-clamp(bodies[i], -40.0, 40.0) / 2.0);
            weights += w * vec3(m < 0.5 ? 1.0 : 0.0, m > 0.5 && m < 1.5 ? 1.0 : 0.0, m > 1.5 ? 1.0 : 0.0);
        }
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
        bool blurred = blockValue(block, slot, u.glassA, u.glassB, u.glassC, u.glassD, u.glassE) > 1.5;
        if (join < -0.5 || join > 0.5) {
            int j = int(join + 0.5) - 1;
            float other = join < 0.0 ? frameDistance : bodies[j];
            if (other < FAR) {
                float fused = smoothUnion(other, bodies[i], k);
                united = min(united, fused);
                if (join < 0.0)
                    frameClusterDistance = min(frameClusterDistance, fused);
                else if (blurred && blockValue(j / 4, j - (j / 4) * 4, u.glassA, u.glassB, u.glassC, u.glassD, u.glassE) > 1.5)
                    held = min(held, fused);
            }
        }
        if (also < -0.5 || also > 0.5) {
            int j = int(also + 0.5) - 1;
            float other = also < 0.0 ? frameDistance : bodies[j];
            if (other < FAR) {
                float fused = smoothUnion(other, bodies[i], k);
                united = min(united, fused);
                if (also < 0.0)
                    frameClusterDistance = min(frameClusterDistance, fused);
                else if (blurred && blockValue(j / 4, j - (j / 4) * 4, u.glassA, u.glassB, u.glassC, u.glassD, u.glassE) > 1.5)
                    held = min(held, fused);
            }
        }
    }

    if (united > FAR) {
        fragColor = vec4(0.0);
        return;
    }
    // Derivatives at the top level: inside a branch that differs between neighbours they are undefined.
    // The gradient in the item's own space (y down on every backend): screen derivatives run y up on OpenGL.
    vec2 dp = vec2(dFdx(p.x), dFdy(p.y));
    vec2 unitedSlope = vec2(dFdx(united), dFdy(united)) / vec2(abs(dp.x) > 1e-6 ? dp.x : 1.0, abs(dp.y) > 1e-6 ? dp.y : 1.0);
    // One pixel of coverage, so the contour stays crisp at any scale.
    float coverage = 1.0 - smoothstep(-0.7, 0.7, united);
    if (u.options.x > 0.5 && u.field.y > 0.5)
        coverage *= smoothstep(-0.7, 0.7, frameDistance);
    float fillAlpha = coverage * u.tint.a * u.qt_Opacity;
    vec3 colour = u.tint.rgb * fillAlpha;
    float alpha = fillAlpha;
    vec3 share = anyGlass ? weights / max(1e-4, weights.x + weights.y + weights.z) : vec3(1.0, 0.0, 0.0);
    // With the frame in another material (the music frame's wallpaper glass, whose band moves every frame) the
    // region carries no band and no join to it, so compositor glass there was a thin tint over the unblurred scene:
    // the fillets under a body and the band beside it showed sharp through. There the band's own material holds.
    if (u.field.y > 0.5 && u.glass.y < 1.5 && share.z > 0.0) {
        float fillet = min(frameDistance, held) - frameClusterDistance;
        float band = max(smoothstep(0.0, 1.0, fillet), 1.0 - smoothstep(-0.7, 0.7, frameDistance));
        float given = share.z * band * smoothstep(-1.5, -0.5, held);
        share.z -= given;
        if (u.glass.y > 0.5) share.y += given; else share.x += given;
    }
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
    if (u.glowMix.x > 0.5) {
        bool paper = u.glowShadow.a > 0.5;
        float bevel = max(1.0, u.glowShape.x);
        float radiusBloom = max(1.0, u.glowBloom.a);
        // Blended by nearness so a join shades from one body into the other instead of creasing.
        float gouraudSum = 0.0;
        float weightSum = 0.0;
        float nearest = frameDistance;
        float nearestHalf = 1e4;
        if (u.field.y > 0.5) {
            float w = exp(-clamp(frameDistance - united, 0.0, 60.0) / 12.0);
            vec2 t = clamp(frameP / size, 0.0, 1.0);
            gouraudSum += w * mix(mix(1.0, 0.82, t.x), mix(0.34, 0.22, t.x), t.y);
            weightSum += w;
        }
        for (int i = 0; i < 20; ++i) {
            if (bodies[i] > FAR)
                continue;
            vec4 s = shapeAt(i);
            float w = exp(-clamp(bodies[i] - united, 0.0, 60.0) / 12.0);
            vec2 t = clamp((p - s.xy + s.zw) / max(2.0 * s.zw, vec2(1.0)), 0.0, 1.0);
            gouraudSum += w * mix(mix(1.0, 0.82, t.x), mix(0.34, 0.22, t.x), t.y);
            weightSum += w;
            if (bodies[i] < nearest) {
                nearest = bodies[i];
                nearestHalf = min(s.z, s.w);
            }
        }
        // A small body wears a lip in proportion, never a panel's.
        float lip = min(bevel, max(2.0, 0.3 * nearestHalf));
        float gouraud = weightSum > 0.0 ? gouraudSum / weightSum : 0.6;
        // Normals from the joined field (central differences): per-body normals break at welds. Corners tighter than the
        // bevel are rounded for the normal only, or a box's gradient creases along its diagonal. Costly: near edges only.
        vec2 grad = vec2(0.0, -1.0);
        if (abs(united) < bevel + 3.5 * radiusBloom + 2.0) {
            grad = vec2(0.0);
            for (int k = 0; k < 4; ++k) {
                vec2 o = k == 0 ? vec2(1.0, 0.0) : k == 1 ? vec2(-1.0, 0.0) : k == 2 ? vec2(0.0, 1.0) : vec2(0.0, -1.0);
                vec2 q = p + o;
                float frameQ = FAR * 10.0;
                float unitedQ = FAR * 10.0;
                if (u.field.y > 0.5) {
                    frameQ = -roundedBox(q + u.scene.xy, frameCentre, frameHalf, max(u.field.w, bevel));
                    unitedQ = frameQ;
                }
                float bodiesQ[20];
                for (int i = 0; i < 20; ++i) {
                    bodiesQ[i] = FAR * 10.0;
                    if (bodies[i] > FAR)
                        continue;
                    vec4 s = shapeAt(i);
                    int block = i / 4;
                    int slot = i - block * 4;
                    float radius = blockValue(block, slot, u.radiiA, u.radiiB, u.radiiC, u.radiiD, u.radiiE);
                    bodiesQ[i] = roundedBox(q, s.xy, s.zw, max(radius, bevel));
                    unitedQ = min(unitedQ, bodiesQ[i]);
                }
                for (int i = 0; i < 20; ++i) {
                    if (bodiesQ[i] > FAR)
                        continue;
                    int block = i / 4;
                    int slot = i - block * 4;
                    float kq = max(0.0, blockValue(block, slot, u.fuseA, u.fuseB, u.fuseC, u.fuseD, u.fuseE));
                    float join = blockValue(block, slot, u.joinA, u.joinB, u.joinC, u.joinD, u.joinE);
                    float also = blockValue(block, slot, u.alsoA, u.alsoB, u.alsoC, u.alsoD, u.alsoE);
                    if (join < -0.5 || join > 0.5) {
                        float other = join < 0.0 ? frameQ : bodiesQ[int(join + 0.5) - 1];
                        if (other < FAR)
                            unitedQ = min(unitedQ, smoothUnion(other, bodiesQ[i], kq));
                    }
                    if (also < -0.5 || also > 0.5) {
                        float other = also < 0.0 ? frameQ : bodiesQ[int(also + 0.5) - 1];
                        if (other < FAR)
                            unitedQ = min(unitedQ, smoothUnion(other, bodiesQ[i], kq));
                    }
                }
                grad += o * unitedQ * 0.5;
            }
        }
        float slopeLength = length(grad);
        vec2 n = grad / max(slopeLength, 1e-4);
        float facing = dot(n, vec2(-0.42, -0.91));
        // A smooth union is not a true distance inside its fillet: measured by its own slope the bevel keeps its width.
        float depth = -united / clamp(slopeLength, 0.5, 1.0);
        float atmosphere = u.glowLight.a;
        float chrome = u.glowMix.y;
        float bloom = u.glowMix.z;
        float signal = u.glowMix.w;
        vec3 shade = u.glowShadow.rgb;
        vec3 key = u.glowLight.rgb;

        vec3 base = alpha > 1e-4 ? colour / alpha : u.tint.rgb;
        vec3 lit = paper
            ? base * mix(vec3(1.0), mix(shade, key, gouraud), atmosphere * 0.16) * mix(0.9, 1.0, gouraud)
            : base + shade * atmosphere * (0.05 + 0.42 * (1.0 - gouraud) * (1.0 - gouraud)) + key * atmosphere * 0.14 * gouraud * gouraud;

        // Paper: one pearl lip, no dark ground band (it read as a second contour).
        vec3 sky = paper ? vec3(1.0) : key * 0.92;
        vec3 hot = paper ? mix(key, vec3(1.0), 0.7) : mix(key, vec3(1.0), 0.55);
        vec3 ground = paper ? mix(lit, vec3(1.0), 0.25) : lit * 0.5 + shade * (0.55 + 0.6 * atmosphere);
        vec3 deep = lit;
        // Misconverged guns at more than a fraction of a pixel drew a rainbow outline round every body.
        float spread = paper ? 0.0 : min(0.6, u.glowShape.z * signal);
        vec3 env = vec3(0.0);
        vec3 amount = vec3(0.0);
        for (int c = 0; c < 3; ++c) {
            float d = depth + n.x * spread * float(c - 1);
            float t = clamp(d / lip, 0.0, 1.0);
            float slope = (1.0 - t) * (1.0 - t * 0.5);
            float e = (-n.y * 0.95 - n.x * 0.3) * (slope * 1.55 - 0.55) - 0.12 * (1.0 - slope);
            vec3 reflected = chromeAt(e, sky, hot, ground, deep);
            env[c] = reflected[c];
            amount[c] = (1.0 - smoothstep(0.8, 1.0, t)) * chrome;
        }
        vec3 material = mix(lit, env, amount);
        material += u.glowBloom.rgb * bloom * (paper ? 0.12 : 0.3) * exp(-max(depth, 0.0) / radiusBloom) * (0.35 + 0.65 * max(facing, 0.0));
        float a = mix(alpha, coverage * u.qt_Opacity, max(amount.r, max(amount.g, amount.b)));
        colour = min(material, vec3(1.0)) * a;
        alpha = a;

        // The band round the screen blooms at half: it is a frame, not a light. Paper never blooms: it read as a white cloud.
        if (united > 0.0 && !paper) {
            float halo = bloom * exp(-united / radiusBloom) * (0.45 + 0.55 * max(facing, 0.0)) * (1.0 - coverage) * u.qt_Opacity;
            if (u.field.y > 0.5 && frameDistance - united < 0.5)
                halo *= 0.5;
            colour += u.glowBloom.rgb * halo * 0.42;
        }
        float pitch = max(2.0, u.glowShape.y);
        float line = 0.5 + 0.5 * cos(6.2831853 * (frameP.y + 0.5) / pitch);
        colour *= 1.0 - signal * (paper ? 0.1 : 0.3) * (1.0 - line);
        colour += bayer4(frameP) * (1.5 / 255.0) * alpha;
        colour = max(colour, vec3(0.0));
    }
    // Glass has a cut edge that catches the light from above, like Liquid Glass: bright where it faces up, a faint
    // line elsewhere, in the scene's own light. Without it wallpaper glass over a dimmed desktop has no edge at
    // all, and compositor blur's 1-bit edge (a wl_region, no AA in Niri) reads as a step instead of glass.
    float glassShare = max(share.y + share.z, u.edgeGlass.w);
    if (glassShare > 0.0) {
        float depth = -united;
        vec2 g = unitedSlope;
        float facing = clamp(-g.y / max(length(g), 1e-4), 0.0, 1.0);
        float lip = coverage * (1.0 - smoothstep(u.edgeGlass.z - 0.5, u.edgeGlass.z + 0.5, depth));
        float seal = lip * mix(u.edgeGlass.y, u.edgeGlass.x, facing * facing) * glassShare * u.sheen.a * u.qt_Opacity;
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
    float shadowAlpha = 0.0;
    if (u.shadeShape.z > 0.5 && u.shade.a > 0.0) {
        // The casters' silhouette one offset lower: bodies that do not paint themselves, the joins between them, and
        // for a body grown out of the frame its fillet with the band less the band's own share, so the shoulders cast
        // and the band does not.
        vec2 ps = p - vec2(0.0, u.shadeShape.x);
        float frameShade = FAR * 10.0;
        if (u.field.y > 0.5)
            frameShade = -roundedBox(ps + u.scene.xy, frameCentre, frameHalf, u.field.w);
        float alone = FAR * 10.0;
        float withFrame = FAR * 10.0;
        float casters[20];
        for (int i = 0; i < 20; ++i) {
            casters[i] = FAR * 10.0;
            if (bodies[i] > FAR)
                continue;
            int block = i / 4;
            int slot = i - block * 4;
            if (blockValue(block, slot, u.paintsA, u.paintsB, u.paintsC, u.paintsD, u.paintsE) > 0.5)
                continue;
            vec4 s = shapeAt(i);
            casters[i] = roundedBox(ps, s.xy, s.zw, blockValue(block, slot, u.radiiA, u.radiiB, u.radiiC, u.radiiD, u.radiiE));
            alone = min(alone, casters[i]);
        }
        for (int i = 0; i < 20; ++i) {
            if (casters[i] > FAR)
                continue;
            int block = i / 4;
            int slot = i - block * 4;
            float k = max(0.0, blockValue(block, slot, u.fuseA, u.fuseB, u.fuseC, u.fuseD, u.fuseE));
            float join = blockValue(block, slot, u.joinA, u.joinB, u.joinC, u.joinD, u.joinE);
            float also = blockValue(block, slot, u.alsoA, u.alsoB, u.alsoC, u.alsoD, u.alsoE);
            if (join < -0.5 && frameShade < FAR)
                withFrame = min(withFrame, smoothUnion(frameShade, casters[i], k));
            else if (join > 0.5 && casters[int(join + 0.5) - 1] < FAR)
                alone = min(alone, smoothUnion(casters[int(join + 0.5) - 1], casters[i], k));
            if (also < -0.5 && frameShade < FAR)
                withFrame = min(withFrame, smoothUnion(frameShade, casters[i], k));
            else if (also > 0.5 && casters[int(also + 0.5) - 1] < FAR)
                alone = min(alone, smoothUnion(casters[int(also + 0.5) - 1], casters[i], k));
        }
        float sigma = max(1.0, u.shadeShape.y * 0.5);
        float thrown = alone < FAR ? blurredEdge(alone / sigma) : 0.0;
        if (withFrame < FAR)
            thrown = max(thrown, max(0.0, blurredEdge(withFrame / sigma) - blurredEdge(frameShade / sigma)));
        // Under glass the body shows what is behind it: the shadow stays outside, never a grey film inside.
        float reachHere = thrown * u.qt_Opacity * (1.0 - coverage * (share.y + share.z)) * (1.0 - alpha);
        shadowAlpha = u.shade.a * reachHere;
        colour += u.shade.rgb * reachHere;
        alpha += shadowAlpha;
    }
    // Wallpaper glass is a half-resolution blur stretched over the body: eight bits of it band. A dither under one level
    // breaks the bands (a shadow's ramp is short enough not to need it).
    float ramp = share.y * coverage;
    if (ramp > 0.0)
        colour = max(colour + (ign(floor(frameP)) - 0.5) * (1.0 / 255.0) * ramp, vec3(0.0));
    fragColor = vec4(colour, alpha);
}
