#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec4 edges;
    vec4 depths;
    vec4 geometry;
    vec4 material;
    vec4 appearance;
    vec4 response;
    vec4 effects;
    vec4 topology;
    vec4 motion;
    vec4 activity;
    vec4 bandsA;
    vec4 bandsB;
    vec4 bandsC;
    vec4 peaksA;
    vec4 peaksB;
    vec4 peaksC;
    vec4 primaryColor;
    vec4 secondaryColor;
    vec4 tertiaryColor;
} u;
const float TAU = 6.28318530718;
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), w.x),
        mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), w.x), w.y);
}
float liveBand(int i) {
    i = i - (i / 12) * 12;
    if (i < 4) return u.bandsA[i];
    if (i < 8) return u.bandsB[i - 4];
    return u.bandsC[i - 8];
}
float peakBand(int i) {
    i = i - (i / 12) * 12;
    if (i < 4) return u.peaksA[i];
    if (i < 8) return u.peaksB[i - 4];
    return u.peaksC[i - 8];
}
float spectrum(float position) {
    float p = clamp(position, 0.0, 0.9999) * 12.0;
    int i = int(floor(p));
    float f = smoothstep(0.0, 1.0, fract(p));
    float live = mix(liveBand(i), liveBand(i + 1), f);
    float peak = mix(peakBand(i), peakBand(i + 1), f);
    float level = mix(live, peak, 0.16);
    return mix(level, smoothstep(u.activity.w * 0.38, 1.0, level), u.activity.w);
}
float liveSpectrum(float position) {
    float p = fract(position) * 12.0;
    int i = int(floor(p));
    float f = smoothstep(0.0, 1.0, fract(p));
    return mix(liveBand(i), liveBand(i + 1), f);
}
float peakSpectrum(float position) {
    float p = fract(position) * 12.0;
    int i = int(floor(p));
    float f = smoothstep(0.0, 1.0, fract(p));
    return mix(peakBand(i), peakBand(i + 1), f);
}
vec3 palette(float t) {
    t = fract(t) * 3.0;
    if (t < 1.0) return mix(u.primaryColor.rgb, u.secondaryColor.rgb, smoothstep(0.0, 1.0, t));
    if (t < 2.0) return mix(u.secondaryColor.rgb, u.tertiaryColor.rgb, smoothstep(0.0, 1.0, t - 1.0));
    return mix(u.tertiaryColor.rgb, u.primaryColor.rgb, smoothstep(0.0, 1.0, t - 2.0));
}
float smoothMinField(float first, float second, float radius) {
    if (radius <= 0.0001)
        return min(first, second);
    float h = max(radius - abs(first - second), 0.0) / radius;
    return min(first, second) - h * h * radius * 0.25;
}
void edgeInterval(int side, out float intervalStart, out float intervalEnd) {
    float span = clamp(u.geometry.x, 0.0, 1.0);
    float center = side >= 2 ? 1.0 - u.geometry.y : u.geometry.y;
    intervalStart = clamp(center - span * 0.5, 0.0, 1.0 - span);
    intervalEnd = intervalStart + span;
}
bool cornerJoined(int previousSide, int nextSide) {
    if (u.topology.x < 0.5 || u.edges[previousSide] < 0.5 || u.edges[nextSide] < 0.5)
        return false;
    float previousStart = 0.0;
    float previousEnd = 0.0;
    float nextStart = 0.0;
    float nextEnd = 0.0;
    edgeInterval(previousSide, previousStart, previousEnd);
    edgeInterval(nextSide, nextStart, nextEnd);
    return previousEnd > 0.999 && nextStart < 0.001;
}
float edgeEndpointMask(int side, float edgeT, bool joinPrevious, bool joinNext) {
    float intervalStart = 0.0;
    float intervalEnd = 0.0;
    edgeInterval(side, intervalStart, intervalEnd);
    if (edgeT < intervalStart || edgeT > intervalEnd)
        return 0.0;
    float width = max(0.0005, (intervalEnd - intervalStart) * u.geometry.z * 0.5);
    float startMask = joinPrevious ? 1.0
        : smoothstep(intervalStart, intervalStart + width, edgeT);
    float endMask = joinNext ? 1.0
        : 1.0 - smoothstep(intervalEnd - width, intervalEnd, edgeT);
    return startMask * endMask;
}
float contourReach(float local, float t, vec2 orbit, float bassEnergy,
        float midEnergy, float trebleEnergy) {
    float theta = local * TAU;
    vec2 direction = vec2(cos(theta), sin(theta));
    float detail = 1.35 + u.material.y * 4.8;
    float n = noise(direction * detail + orbit * 0.72) * 0.64
        + noise(direction * detail * 2.13 - orbit * 0.46) * 0.36;
    float liveLevel = clamp(liveSpectrum(local), 0.0, 1.0);
    float peakLevel = clamp(peakSpectrum(local), 0.0, 1.0);
    float level = pow(clamp(mix(liveLevel, peakLevel, 0.16), 0.0, 1.0), 0.74);
    float localTransient = max(0.0, peakLevel - liveLevel) + u.activity.z * liveLevel;
    float centeredLevel = level - u.activity.x * 0.62;
    float activity = clamp((centeredLevel * 0.34 + level * 0.12) * u.motion.w,
        -0.055, 0.32);
    activity *= mix(0.45, 1.25, u.appearance.w);
    float shape = u.effects.w;
    float breath = sin(theta * 2.0 + t * 0.58) * (0.006 + u.motion.y * 0.014);
    float contour = (n - 0.5) * (0.035 + u.material.y * 0.035
        + u.motion.y * 0.022 + max(0.0, activity) * 0.022);
    if (shape > 0.5 && shape < 1.5) {
        float ribbon = sin(theta + t * 0.48)
            + 0.42 * sin(theta * 2.0 - t * 0.31);
        breath = ribbon * (0.005 + u.motion.y * 0.010)
            + centeredLevel * 0.014;
        contour *= 0.55;
    } else if (shape >= 1.5 && shape < 2.5) {
        float cells = pow(0.5 + 0.5 * sin(theta * 6.0 - t * 0.82
            + liveLevel * 2.4), 3.0);
        breath = (cells - 0.38) * (0.010 + u.motion.y * 0.018)
            + localTransient * 0.020;
        contour = contour * 0.72 + (cells - 0.5) * level * 0.026;
    } else if (shape >= 2.5) {
        float filament = sin(theta * 9.0 + t * 0.94)
            * sin(theta * 4.0 - t * 0.37);
        breath = filament * (0.004 + trebleEnergy * 0.012 + u.motion.y * 0.006);
        contour = contour * 0.46 + filament * (0.008 + localTransient * 0.024);
    }
    float baseReach = mix(0.040, 0.165, clamp(u.material.x, 0.0, 1.0));
    float bassPush = bassEnergy * u.response.x * u.activity.y
        * (0.018 + liveLevel * 0.024);
    float groovePush = level * (u.activity.y * 0.026 + localTransient * 0.034)
        + midEnergy * level * 0.010;
    float spectrumPush = activity + bassPush;
    float transientPush = (u.activity.y * 0.030 + u.activity.z * u.motion.w * 0.024)
        * u.response.z;
    return clamp(baseReach + breath + contour + spectrumPush + groovePush + transientPush,
        0.025, 0.72);
}
void main() {
    vec2 size = max(u.resolution, vec2(1.0));
    vec2 p = qt_TexCoord0 * size;
    vec4 distances = vec4(p.y, size.x - p.x, size.y - p.y, p.x);
    vec4 along = vec4(p.x, p.y, size.x - p.x, size.y - p.y);
    vec4 extents = vec4(size.x, size.y, size.x, size.y);
    bool joinTR = cornerJoined(0, 1);
    bool joinBR = cornerJoined(1, 2);
    bool joinBL = cornerJoined(2, 3);
    bool joinTL = cornerJoined(3, 0);
    bool unifiedPath = joinTR || joinBR || joinBL || joinTL;
    vec4 reachable = step(distances, u.depths) * u.edges;
    if (!unifiedPath) {
        for (int side = 0; side < 4; ++side) {
            if (reachable[side] < 0.5)
                continue;
            float intervalStart = 0.0;
            float intervalEnd = 0.0;
            edgeInterval(side, intervalStart, intervalEnd);
            float edgeT = along[side] / max(1.0, extents[side]);
            if (edgeT < intervalStart || edgeT > intervalEnd)
                reachable[side] = 0.0;
        }
        if (dot(reachable, vec4(1)) < 0.5) {
            fragColor = vec4(0); return;
        }
    }
    float radius = min(u.geometry.w, min(size.x, size.y) * 0.5);
    float mask = 1.0;
    bool nearHorizontalCorner = p.x < radius || p.x > size.x - radius;
    bool nearVerticalCorner = p.y < radius || p.y > size.y - radius;
    if (radius > 0.0 && nearHorizontalCorner && nearVerticalCorner) {
        vec2 q = abs(p - size * 0.5) - (size * 0.5 - radius);
        float sd = length(max(q, vec2(0))) + min(max(q.x, q.y), 0.0) - radius;
        mask = 1.0 - smoothstep(-1.0, 0.5, sd);
    }
    float flowDirection = u.topology.y < 0.0 ? -1.0 : 1.0;
    float t = u.motion.x * TAU * flowDirection;
    vec2 orbit = vec2(cos(t), sin(t));
    float bassEnergy = max(max(u.bandsA.x, u.bandsA.y), u.bandsA.z);
    float midEnergy = max(max(u.bandsB.x, u.bandsB.y), max(u.bandsB.z, u.bandsB.w));
    float trebleEnergy = max(max(u.bandsC.y, u.bandsC.z), u.bandsC.w);
    float connectedFieldRatio = 1e9;
    float connectedDepth = 1.0;
    float connectedLocal = 0.0;
    if (unifiedPath) {
        float cornerBlend = clamp(u.topology.z, 0.0, 1.0);
        float blendRadius = mix(0.035, 0.28, cornerBlend);
        bool hasConnectedField = false;
        float connectedWeight = 0.0;
        float connectedDepthSum = 0.0;
        vec2 connectedPhase = vec2(0.0);
        for (int side = 0; side < 4; ++side) {
            if (u.edges[side] < 0.5)
                continue;
            float extent = extents[side];
            float edgeT = along[side] / max(1.0, extent);
            float intervalStart = 0.0;
            float intervalEnd = 0.0;
            edgeInterval(side, intervalStart, intervalEnd);
            if (edgeT < intervalStart || edgeT > intervalEnd)
                continue;
            float segmentLocal = clamp((edgeT - intervalStart)
                / max(0.0001, intervalEnd - intervalStart), 0.0, 1.0);
            int previous = side == 0 ? 3 : side - 1;
            int next = side == 3 ? 0 : side + 1;
            float endpointMask = edgeEndpointMask(side, edgeT,
                cornerJoined(previous, side), cornerJoined(side, next));
            float sideReach = contourReach(segmentLocal, t, orbit,
                bassEnergy, midEnergy, trebleEnergy);
            sideReach *= mix(0.08, 1.0, endpointMask);
            float effectiveSideDepth = u.depths[side];
            float transitionPx = clamp(min(size.x, size.y)
                * mix(0.018, 0.085, cornerBlend), 18.0, 180.0);
            float transitionT = transitionPx / max(1.0, extent);
            if (cornerJoined(previous, side)) {
                float sharedDepth = min(u.depths[previous], u.depths[side]);
                float recovery = smoothstep(0.0, transitionT,
                    max(0.0, edgeT - intervalStart));
                effectiveSideDepth = mix(sharedDepth, effectiveSideDepth, recovery);
            }
            if (cornerJoined(side, next)) {
                float sharedDepth = min(u.depths[side], u.depths[next]);
                float recovery = smoothstep(0.0, transitionT,
                    max(0.0, intervalEnd - edgeT));
                effectiveSideDepth = mix(sharedDepth, effectiveSideDepth, recovery);
            }
            float sideRatio = distances[side]
                / max(1.0, effectiveSideDepth * sideReach);
            float phaseWeight = exp(-min(sideRatio, 3.0) * 2.4);
            connectedPhase += vec2(cos(segmentLocal * TAU), sin(segmentLocal * TAU))
                * phaseWeight;
            connectedDepthSum += effectiveSideDepth * phaseWeight;
            connectedWeight += phaseWeight;
            if (!hasConnectedField) {
                connectedFieldRatio = sideRatio;
                hasConnectedField = true;
            } else {
                connectedFieldRatio = smoothMinField(connectedFieldRatio,
                    sideRatio, blendRadius);
            }
        }
        if (!hasConnectedField || connectedFieldRatio > 2.8) {
            fragColor = vec4(0); return;
        }
        connectedDepth = connectedDepthSum / max(0.0001, connectedWeight);
        connectedLocal = atan(connectedPhase.y, connectedPhase.x) / TAU;
        if (connectedLocal < 0.0)
            connectedLocal += 1.0;
    }
    float alpha = 0.0;
    vec3 weightedColor = vec3(0);
    float totalWeight = 0.0;
    for (int iteration = 0; iteration < 4; ++iteration) {
        if (unifiedPath && iteration > 0) continue;
        int side = iteration;
        if (!unifiedPath && reachable[side] < 0.5) continue;
        float local = unifiedPath ? connectedLocal : 0.0;
        float ends = 1.0;
        if (!unifiedPath) {
            float extent = extents[side];
            float length = extent * u.geometry.x;
            float center = side >= 2 ? 1.0 - u.geometry.y : u.geometry.y;
            float start = clamp(extent * center - length * 0.5, 0.0, extent - length);
            float a = along[side] - start;
            if (a < 0.0 || a > length) continue;
            float endWidth = max(1.0, length * u.geometry.z * 0.5);
            ends = smoothstep(0.0, endWidth, a)
                * smoothstep(0.0, endWidth, length - a);
            local = clamp(a / max(length, 1.0), 0.0, 1.0);
        }
        float theta = local * TAU;
        vec2 direction = vec2(cos(theta), sin(theta));
        float detail = 1.35 + u.material.y * 4.8;
        float n = noise(direction * detail + orbit * 0.72) * 0.64
            + noise(direction * detail * 2.13 - orbit * 0.46) * 0.36;
        float liveLevel = clamp(liveSpectrum(local), 0.0, 1.0);
        float peakLevel = clamp(peakSpectrum(local), 0.0, 1.0);
        float level = pow(clamp(mix(liveLevel, peakLevel, 0.16), 0.0, 1.0), 0.74);
        float localTransient = max(0.0, peakLevel - liveLevel) + u.activity.z * liveLevel;
        float centeredLevel = level - u.activity.x * 0.62;
        float activity = clamp((centeredLevel * 0.34 + level * 0.12) * u.motion.w,
            -0.055, 0.32);
        activity *= mix(0.45, 1.25, u.appearance.w);
        float shape = u.effects.w;
        float breath = sin(theta * 2.0 + t * 0.58) * (0.006 + u.motion.y * 0.014);
        float contour = (n - 0.5) * (0.035 + u.material.y * 0.035
            + u.motion.y * 0.022 + max(0.0, activity) * 0.022);
        if (shape > 0.5 && shape < 1.5) {
            float ribbon = sin(theta + t * 0.48)
                + 0.42 * sin(theta * 2.0 - t * 0.31);
            breath = ribbon * (0.005 + u.motion.y * 0.010)
                + centeredLevel * 0.014;
            contour *= 0.55;
        } else if (shape >= 1.5 && shape < 2.5) {
            float cells = pow(0.5 + 0.5 * sin(theta * 6.0 - t * 0.82
                + liveLevel * 2.4), 3.0);
            breath = (cells - 0.38) * (0.010 + u.motion.y * 0.018)
                + localTransient * 0.020;
            contour = contour * 0.72 + (cells - 0.5) * level * 0.026;
        } else if (shape >= 2.5) {
            float filament = sin(theta * 9.0 + t * 0.94)
                * sin(theta * 4.0 - t * 0.37);
            breath = filament * (0.004 + trebleEnergy * 0.012 + u.motion.y * 0.006);
            contour = contour * 0.46 + filament * (0.008 + localTransient * 0.024);
        }
        float baseReach = mix(0.040, 0.165, clamp(u.material.x, 0.0, 1.0));
        float bassPush = bassEnergy * u.response.x * u.activity.y
            * (0.018 + liveLevel * 0.024);
        float groovePush = level * (u.activity.y * 0.026 + localTransient * 0.034)
            + midEnergy * level * 0.010;
        float spectrumPush = activity + bassPush;
        float transientPush = (u.activity.y * 0.030 + u.activity.z * u.motion.w * 0.024)
            * u.response.z;
        float reach = clamp(baseReach + breath + contour + spectrumPush
            + groovePush + transientPush, 0.025, 0.72);
        reach *= mix(0.08, 1.0, smoothstep(0.0, 1.0, ends));
        float effectiveDepth = unifiedPath ? connectedDepth : u.depths[side];
        float d = unifiedPath ? connectedFieldRatio * max(reach, 0.025)
            : distances[side] / max(1.0, effectiveDepth);
        float aa = 1.5 / max(1.0, effectiveDepth);
        float fieldRatio = unifiedPath ? connectedFieldRatio : d / max(reach, 0.025);
        float fieldAa = unifiedPath
            ? max(0.010, 1.5 / max(1.0, effectiveDepth * max(reach, 0.025)))
            : max(0.010, aa / max(reach, 0.025));
        float body = 1.0 - smoothstep(1.0 - fieldAa, 1.0 + fieldAa, fieldRatio);
        float relativeDepth = clamp(fieldRatio, 0.0, 1.0);
        float rim = exp(-abs(fieldRatio - 1.0) / max(fieldAa, 0.035));
        float haloDecay = unifiedPath
            ? mix(12.0, 3.5, u.appearance.z)
            : mix(54.0, 14.0, u.appearance.z) * max(reach, 0.025);
        float halo = exp(-max(0.0, fieldRatio - 1.0) * haloDecay)
            * (1.0 - body) * u.material.z
            * (0.035 + max(0.0, activity) * 0.15 + u.activity.y * 0.045
                + trebleEnergy * u.response.y * 0.08
                + u.activity.y * u.response.w * 0.10);
        float crestBias = smoothstep(0.38, 0.92, relativeDepth);
        float rootVeil = exp(-relativeDepth * 5.2);
        float fill = body * u.appearance.x * (rootVeil * 0.040
            + crestBias * (0.12 + max(0.0, activity) * 0.20));
        float flowHue = local + sin(t) * u.motion.z * 0.18 + n * 0.055;
        float hue = flowHue;
        if (u.effects.z > 0.5 && u.effects.z < 1.5)
            hue = local + level * 0.08 + n * 0.025;
        else if (u.effects.z >= 1.5 && u.effects.z < 2.5)
            hue = 0.04 + u.activity.y * 0.22 + u.activity.z * 0.18
                + trebleEnergy * 0.12 + local;
        else if (u.effects.z >= 2.5)
            hue = local * (u.topology.x > 0.5 ? 1.0 : 0.16) + n * 0.018;
        if (u.material.w < 0.5) {
            float sheenCenter = 0.62 + sin(theta + t * 0.44) * 0.10;
            float sheen = exp(-pow((relativeDepth - sheenCenter) / 0.16, 2.0));
            fill += body * u.appearance.x * sheen * crestBias
                * (0.030 + max(0.0, activity) * 0.060);
            fill += rim * u.appearance.y * (0.11 + max(0.0, activity) * 0.20
                + trebleEnergy * u.response.y * 0.07
                + u.activity.y * u.response.w * 0.08);
            hue += sheen * 0.08 + relativeDepth * 0.08;
        } else if (u.material.w < 1.5) {
            float curtains = pow(0.5 + 0.5 * sin(theta * 11.0 + n * 5.0 + t * 0.7), 5.0);
            fill += body * u.appearance.x * curtains
                * (0.055 + max(0.0, activity) * 0.14);
            hue += relativeDepth * 0.18;
            fill += rim * u.appearance.y
                * (0.10 + trebleEnergy * u.response.y * 0.05
                    + u.activity.y * u.response.w * 0.06);
        } else if (u.material.w < 2.5) {
            fill = rim * u.appearance.y * (0.46 + max(0.0, activity) * 0.30
                + trebleEnergy * u.response.y * 0.08
                + u.activity.y * u.response.w * 0.10)
                + body * u.appearance.x * 0.018;
            halo *= 0.62;
        } else {
            fill = body * u.appearance.x
                * (0.10 + crestBias * 0.16 + max(0.0, activity) * 0.17)
                + rim * u.appearance.y * (0.14 + max(0.0, activity) * 0.13
                    + trebleEnergy * u.response.y * 0.06
                    + u.activity.y * u.response.w * 0.07);
            hue += n * 0.10;
        }

        float effect = clamp(u.effects.y, 0.0, 1.0);
        if (u.effects.x > 0.5 && u.effects.x < 1.5) {
            float sparks = pow(max(0.0, sin(theta * 19.0 + n * 8.0 + t * 1.8)), 14.0);
            float sparkle = rim * sparks * effect
                * (0.025 + trebleEnergy * u.response.y * 0.15 + u.activity.z * 0.12);
            fill += sparkle;
            halo += sparkle * (0.30 + u.appearance.z * 0.45);
            hue += sparks * 0.10 * effect;
        } else if (u.effects.x >= 1.5 && u.effects.x < 2.5) {
            float echoRim;
            if (unifiedPath) {
                float echoRatio = 1.10 + u.activity.y * 0.08;
                echoRim = exp(-abs(fieldRatio - echoRatio)
                    / max(fieldAa * 1.7, 0.055));
            } else {
                float echoReach = min(0.80, reach + 0.018 + u.activity.y * 0.018);
                echoRim = exp(-abs(d - echoReach) / max(aa * 1.7, 0.014));
            }
            fill += echoRim * effect * u.appearance.y
                * (0.035 + u.activity.y * 0.050 + u.activity.z * 0.030);
        } else if (u.effects.x >= 2.5 && u.effects.x < 3.5) {
            float chroma = sin(theta * 5.0 - t * 0.7 + relativeDepth * 8.0);
            float prismEnergy = clamp(trebleEnergy * u.response.y * 0.72
                + level * 0.22 + localTransient * 0.42, 0.0, 1.0);
            hue += chroma * effect * (0.018 + prismEnergy * 0.105
                + u.activity.z * 0.040);
            fill += rim * effect * (0.008 + prismEnergy * 0.040);
        } else if (u.effects.x >= 3.5 && u.effects.x < 4.5) {
            float bloomDistance = unifiedPath ? max(0.0, fieldRatio - 1.0)
                : max(0.0, d - reach);
            float bloomDecay = unifiedPath ? mix(8.0, 2.5, u.appearance.z)
                : mix(28.0, 8.0, u.appearance.z);
            float bloom = exp(-bloomDistance * bloomDecay) * (1.0 - body);
            float bloomEnergy = clamp(bassEnergy * u.response.x * 0.82
                + u.activity.y * 0.34 + u.activity.z * 0.18, 0.0, 1.0);
            halo += bloom * effect * u.material.z
                * (0.012 + bloomEnergy * 0.090);
        } else if (u.effects.x >= 4.5 && u.effects.x < 5.5) {
            float causticWave = 0.5 + 0.5 * sin(relativeDepth * 19.0
                + theta * 3.0 - t * 1.15 + n * 4.0);
            float caustic = pow(causticWave, 7.0) * body * effect
                * (0.018 + midEnergy * 0.055 + trebleEnergy * 0.040
                    + localTransient * 0.085);
            fill += caustic;
            halo += caustic * (0.24 + u.appearance.z * 0.32);
            hue += causticWave * 0.045 * effect;
        } else if (u.effects.x >= 5.5) {
            float afterRim;
            if (unifiedPath) {
                float afterRatio = 1.12 + peakLevel * 0.14;
                afterRim = exp(-abs(fieldRatio - afterRatio)
                    / max(fieldAa * 2.2, 0.065));
            } else {
                float afterReach = min(0.84, reach + 0.024 + peakLevel * 0.034);
                afterRim = exp(-abs(d - afterReach) / max(aa * 2.2, 0.018));
            }
            float after = afterRim * effect * u.material.z
                * (0.020 + peakLevel * 0.075 + u.activity.z * 0.065
                    + trebleEnergy * u.response.y * 0.035);
            halo += after;
            fill += after * 0.32;
        }
        float fieldClip = unifiedPath
            ? 1.0 - smoothstep(1.9, 2.7, fieldRatio)
            : 1.0 - smoothstep(0.88, 1.0, d);
        float weight = clamp((fill + halo) * ends, 0.0, 0.82) * fieldClip;
        alpha = u.topology.x > 0.5 ? max(alpha, weight)
            : 1.0 - (1.0 - alpha) * (1.0 - weight);
        weightedColor += palette(hue) * weight;
        totalWeight += weight;
    }
    vec3 color = weightedColor / max(0.0001, totalWeight);
    alpha *= mask * u.qt_Opacity;
    fragColor = vec4(color * alpha, alpha);
}
