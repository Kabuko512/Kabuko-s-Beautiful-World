// --- /lib/materials/fluid_waves.glsl ---
// Ten plik zawiera uniwersalną logikę falowania dla wody, lawy i innych płynów.

// Używamy prostych, ale płynnych fal opartych na sinusach połączonych z pozycją świata.
// Dzięki temu fale są ciągłe i płynne pomiędzy blokami.
vec3 calculateFluidWaves(vec3 worldPos, float speed, float amplitude, float scale, float time) {
    vec3 offset = vec3(0.0);
    
    // Unikalny offset czasowy oparty na współrzędnych X i Z
    float waveTime = time * speed;
    
    // Kombinacja fal w różnych kierunkach dla naturalnego efektu "wzburzenia"
    float wave1 = sin(worldPos.x * scale + waveTime) * cos(worldPos.z * scale + waveTime);
    float wave2 = sin(worldPos.x * scale * 1.5 - waveTime * 1.2) * cos(worldPos.z * scale * 0.8 + waveTime * 0.9);
    
    // Nakładamy fale tylko na oś Y (góra/dół)
    // Zmniejszamy siłę fali na brzegach bloku, aby nie "odklejała" się od ziemi
    float finalWave = (wave1 + wave2) * 0.5 * amplitude;
    
    offset.y = finalWave;
    
    return offset;
}