// --- /lib/sky/aurora.glsl ---

vec3 getAurora(vec3 viewDir, float time, float rain) {
    if (viewDir.y < 0.1 || rain > 0.5) return vec3(0.0);

    // Warstwa zorzy na dużej wysokości
    float altitude = 1500.0;
    float t = altitude / max(viewDir.y, 0.001);
    vec3 pos = viewDir * t;
    
    vec2 uv = pos.xz * 0.0002;
    float n = 0.0;
    
    // FBM dla efektu "wstęg"
    float speed = time * 0.05;
    n += customNoise2D(uv * 1.0 + vec2(speed, 0.0)) * 0.50;
    n += customNoise2D(uv * 2.1 - vec2(0.0, speed)) * 0.25;
    
    // Wyostrzenie wstęg
    n = pow(n, 3.0) * 2.0;
    
    // Kolorystyka zorzy (Zieleń przechodząca w fiolet)
    vec3 col1 = vec3(0.1, 1.0, 0.3); // Zielony
    vec3 col2 = vec3(0.4, 0.1, 1.0); // Fioletowy
    vec3 auroraCol = mix(col1, col2, customNoise2D(uv * 0.5));
    
    // Wygaszenie przy horyzoncie i zanikanie
    float mask = smoothstep(0.1, 0.4, viewDir.y) * smoothstep(1.0, 0.5, n);
    
    return auroraCol * n * mask * (1.0 - rain);
}