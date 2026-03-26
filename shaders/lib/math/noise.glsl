// --- /lib/math/noise.glsl ---

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise1D(float p) {
    float fl = floor(p);
    float fc = fract(p);
    return mix(hash1(fl), hash1(fl + 1.0), fc);
}

float customNoise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i + vec2(0.0, 0.0)), hash2(i + vec2(1.0, 0.0)), u.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Fractional Brownian Motion - używane m.in. w chmurach
float fbm2(vec2 p) {
    float f = 0.0;
    f += 0.5000 * customNoise2D(p);
    p = p * 2.02;
    f += 0.2500 * customNoise2D(p); p = p * 2.03;
    f += 0.1250 * customNoise2D(p);
    return f;
}