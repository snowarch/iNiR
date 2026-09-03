#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    float spin;
    float energy;
    float onset;
    float pulse;
    float amplitude;
    float reveal;
    float deformationStrength;
    float pulseStrength;
    float compression;
    float idleMotion;
    float glowStrength;
    float presentationScale;
    float baseRadius;
    float hollowAmount;
    float presentationMode;
    float aspectRatio;
    float edgeBaseRadius;
    vec2 edgeCardHalf;
    vec2 edgeReachHalf;
    float edgeCornerRadius;
    vec4 edgeReachScales;
    vec4 edgeDirections;
    vec4 bandsA;
    vec4 bandsB;
    vec4 bandsC;
    vec4 peaksA;
    vec4 peaksB;
    vec4 peaksC;
    vec4 primaryColor;
    vec4 secondaryColor;
    vec4 tertiaryColor;
} ubuf;

const float TAU = 6.28318530718;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    return 0.56 * noise(p)
        + 0.29 * noise(p * 2.03 + vec2(4.7, 11.3))
        + 0.15 * noise(p * 4.07 + vec2(17.1, 3.2));
}

float sample12(vec4 a, vec4 b, vec4 c, int index) {
    int i = index - (index / 12) * 12;
    if (i < 4)
        return a[i];
    if (i < 8)
        return b[i - 4];
    return c[i - 8];
}

float angularSpectrum(float angle, vec4 a, vec4 b, vec4 c,
        float compression) {
    float position = fract(angle / TAU + 0.5) * 12.0;
    int base = int(floor(position));
    float blend = smoothstep(0.0, 1.0, fract(position));
    float current = sample12(a, b, c, base);
    float next = sample12(a, b, c, base + 1);
    float continuousSpectrum = mix(current, next, blend);

    // Compression is spatial rather than audio-level compression. Increase
    // local contrast without cutting the continuous angular field into fixed
    // sectors: weak regions settle inward while active regions keep a broad,
    // smooth shoulder into their neighbours.
    float amount = clamp(compression, 0.0, 1.0);
    float compressionFloor = amount * 0.38;
    float focusedSpectrum = smoothstep(
        compressionFloor, 1.0, continuousSpectrum);
    return mix(continuousSpectrum, focusedSpectrum, amount * 0.82);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - 0.5) * 2.0;
    float t = ubuf.phase * TAU;
    bool edgeMode = ubuf.presentationMode > 1.5;
    float radialDistance = length(p);
    float edgeDistanceNormalized = 0.0;
    float presentationMask = 1.0;
    vec2 dir = radialDistance > 0.0001 ? p / radialDistance : vec2(1.0, 0.0);

    if (edgeMode) {
        vec2 halfCard = clamp(ubuf.edgeCardHalf, vec2(0.08), vec2(0.96));
        vec2 shapedP = vec2(p.x * ubuf.aspectRatio, p.y);
        vec2 shapedHalf = vec2(halfCard.x * ubuf.aspectRatio, halfCard.y);

        // The player boundary is the exact analogue of the artwork boundary in
        // the standalone Visualizer: Organic starts there and only the exterior
        // portion remains visible because the player is drawn above it.
        float cornerRadius = clamp(ubuf.edgeCornerRadius, 0.0,
            min(shapedHalf.x, shapedHalf.y) - 0.001);
        vec2 roundedQ = abs(shapedP) - (shapedHalf - vec2(cornerRadius));
        float cardDistance = length(max(roundedQ, vec2(0.0)))
            + min(max(roundedQ.x, roundedQ.y), 0.0) - cornerRadius;
        float perimeterAA = max(fwidth(cardDistance) * 1.25, 0.0014);
        float outsideMask = smoothstep(-perimeterAA, perimeterAA, cardDistance);
        presentationMask = outsideMask;

        vec2 reachHalf = clamp(ubuf.edgeReachHalf, halfCard, vec2(0.98));
        float xReach = max(0.02, ubuf.aspectRatio * (reachHalf.x - halfCard.x));
        float yReach = max(0.02, reachHalf.y - halfCard.y);
        float availableReach = max(0.02, min(xReach, yReach));
        edgeDistanceNormalized = max(0.0, cardDistance) / availableReach;

        // Keep the angular field continuous, like the radial Visualizer. The old
        // nearest-side unwrap changed parametrization across dx == dy, producing
        // four diagonal seams that looked like an invisible diamond around Media.
        vec2 perimeterDirection = vec2(
            shapedP.x / max(shapedHalf.x, 0.001),
            shapedP.y / max(shapedHalf.y, 0.001));
        float perimeterLength = length(perimeterDirection);
        dir = perimeterLength > 0.0001
            ? perimeterDirection / perimeterLength : vec2(1.0, 0.0);
    }

    float cs = cos(ubuf.spin);
    float sn = sin(ubuf.spin);
    vec2 rotatedDir = vec2(dir.x * cs - dir.y * sn, dir.x * sn + dir.y * cs);

    vec2 orbitA = vec2(cos(t), sin(t)) * 0.95;
    vec2 orbitB = vec2(cos(t * 1.9 + 1.7), sin(t * 1.9 + 1.7)) * 0.55;
    float n1 = fbm(rotatedDir * 1.45 + orbitA);
    float n2 = fbm(rotatedDir * 2.25 + orbitB);
    float organic = smoothstep(0.27, 0.73, mix(n1, n2, 0.34));

    float angle = atan(rotatedDir.y, rotatedDir.x);
    float spatialCompression = clamp(ubuf.compression, 0.0, 1.0);
    float liveSpectrum = angularSpectrum(angle, ubuf.bandsA, ubuf.bandsB,
        ubuf.bandsC, spatialCompression);
    float peakSpectrum = angularSpectrum(angle, ubuf.peaksA, ubuf.peaksB,
        ubuf.peaksC, spatialCompression);
    float spectrum = mix(liveSpectrum, peakSpectrum, 0.18);
    float shapedSpectrum = pow(clamp(spectrum, 0.0, 1.0), 0.72);

    float rangeScale = mix(0.72, 1.36, clamp(ubuf.amplitude, 0.0, 1.0));
    float motionScale = rangeScale * ubuf.deformationStrength;
    float centeredSpectrum = shapedSpectrum - ubuf.energy * 0.64;
    float spectrumPush = (centeredSpectrum * 0.50 * motionScale
        + shapedSpectrum * 0.115 * motionScale) * ubuf.presentationScale;
    spectrumPush += ubuf.onset * (0.040 + shapedSpectrum * 0.110)
        * motionScale * ubuf.presentationScale;
    float localActivity = smoothstep(0.10, 0.82, shapedSpectrum);
    spectrumPush += spatialCompression * localActivity
        * (ubuf.pulse * ubuf.pulseStrength * 0.024
            + ubuf.onset * ubuf.pulseStrength * 0.014)
        * motionScale * ubuf.presentationScale;
    spectrumPush *= mix(1.0, 0.86 + organic * 0.26,
        spatialCompression);
    spectrumPush = clamp(spectrumPush, -0.055, 0.285);

    float breath = sin(t * 0.82) * (0.004 + ubuf.idleMotion * 0.010);
    float pulsePush = (ubuf.pulse * ubuf.pulseStrength * 0.058
        + ubuf.onset * ubuf.pulseStrength * 0.020)
        * mix(1.0, 0.58, spatialCompression) * ubuf.presentationScale;
    float baseRadius = (ubuf.baseRadius + breath + pulsePush) * ubuf.presentationScale;
    float contour = (organic - 0.5) * (0.030 + 0.028 * ubuf.energy
        + ubuf.idleMotion * 0.016) * ubuf.presentationScale;
    float microMotion = sin(angle * 4.0 + t * 0.62) *
        (0.005 + ubuf.energy * 0.012 + ubuf.idleMotion * 0.006);
    float blobRadius = min(0.82, baseRadius + contour + microMotion + spectrumPush);

    float innerRadius = 0.565 * ubuf.hollowAmount * ubuf.presentationScale;
    // Media maps distance from the rounded card perimeter into the same radial
    // coordinate used by the standalone Organic ring. Only this coordinate map
    // differs; every visual calculation below is shared.
    // Media only remaps distance from the player boundary. All deformation stays
    // in the shared blobRadius calculation above; applying a second edge warp
    // here makes peaks exceed Reach and eventually collide with the render FBO.
    // Reach describes the usable outward field, not a wall for the animated
    // contour. Keep radial headroom beyond blobRadius's 0.82 ceiling so peaks
    // and pulse decay naturally instead of flattening against an invisible edge.
    float edgeRadialSpan = max(0.18, 0.94 - ubuf.edgeBaseRadius);
    float r = edgeMode
        ? ubuf.edgeBaseRadius
            + edgeDistanceNormalized * edgeRadialSpan
        : radialDistance;
    float aa = max(fwidth(r) * 1.5, 0.0025);
    float body = 1.0 - smoothstep(blobRadius - aa, blobRadius + aa, r);
    float innerFade = ubuf.hollowAmount < 0.01 ? 1.0
        : smoothstep(innerRadius - 0.035, innerRadius + 0.018, r);

    float edgeDistance = max(0.0, r - blobRadius);
    float haloDecay = mix(34.0, 18.0, ubuf.glowStrength)
        * (edgeMode ? 0.72 : 1.0);
    float halo = exp(-edgeDistance * haloDecay) * (1.0 - body)
        * ubuf.glowStrength * (edgeMode ? 1.34 : 1.0)
        * (0.055 + ubuf.energy * 0.13
            + ubuf.pulse * 0.16 + ubuf.onset * 0.14);

    float depth = clamp(1.0 - r / max(blobRadius, 0.001), 0.0, 1.0);
    float chroma = clamp(0.22 + depth * 0.64 + organic * 0.18, 0.0, 1.0);
    float huePhase = fract(angle / TAU + 0.5 + ubuf.phase * 0.035);
    vec3 paletteColor;
    if (huePhase < 0.3333333) {
        paletteColor = mix(ubuf.primaryColor.rgb, ubuf.secondaryColor.rgb,
            huePhase * 3.0);
    } else if (huePhase < 0.6666667) {
        paletteColor = mix(ubuf.secondaryColor.rgb, ubuf.tertiaryColor.rgb,
            (huePhase - 0.3333333) * 3.0);
    } else {
        paletteColor = mix(ubuf.tertiaryColor.rgb, ubuf.primaryColor.rgb,
            (huePhase - 0.6666667) * 3.0);
    }
    vec3 bodyColor = mix(paletteColor, ubuf.primaryColor.rgb, chroma * 0.28);
    bodyColor *= 0.88 + depth * 0.12 + shapedSpectrum * 0.24;
    vec3 haloColor = mix(paletteColor, ubuf.secondaryColor.rgb, 0.22);
    float ringBody = body * innerFade;
    float localAlpha = 0.38 + shapedSpectrum * 0.40
        + ubuf.pulse * 0.10 + ubuf.onset * 0.10;
    float alpha = ringBody * min(0.92, localAlpha) + halo;
    vec3 rgb = bodyColor * ringBody + haloColor * halo;

    float sourceAlpha = min(1.0, max(max(ubuf.primaryColor.a,
        ubuf.secondaryColor.a), ubuf.tertiaryColor.a));
    float revealAlpha = smoothstep(0.0, 0.35, ubuf.reveal);
    alpha *= presentationMask * sourceAlpha * ubuf.qt_Opacity * revealAlpha;
    rgb *= presentationMask * sourceAlpha * ubuf.qt_Opacity * revealAlpha;
    fragColor = vec4(rgb, alpha);
}
