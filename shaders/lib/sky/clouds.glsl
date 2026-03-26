// Włączniki (pojawią się jako przyciski ON/OFF)
#define ENABLE_HIGH_CLOUDS   
#define ENABLE_MID_CLOUDS    
#define ENABLE_LOW_CLOUDS    

// Slidery (pojawią się jako suwaki dzięki liście wartości w nawiasach)
#define HEIGHT_HIGH 350.0 // [200.0 250.0 300.0 350.0 400.0 450.0]
#define HEIGHT_MID 220.0  // [150.0 180.0 220.0 250.0 280.0]
#define HEIGHT_LOW 120.0  // [80.0 100.0 120.0 150.0 180.0]

#define BLOCK_SIZE_HIGH 32.0 // [8.0 16.0 32.0 64.0]
#define BLOCK_SIZE_MID 16.0  // [8.0 16.0 32.0 64.0]
#define BLOCK_SIZE_LOW 16.0  // [8.0 16.0 32.0 64.0]

#define GLOBAL_SPEED 1.0     // [0.1 0.5 1.0 1.5 2.0 3.0]

#define Z_FIGHTING_BIAS 0.2  

// Zwraca vec4: rgb = kolor chmury, a = przeźroczystość (alpha)
vec4 getCloudLayer(float t, float blockSize, vec2 scale, float density, float speedMult, vec3 baseColor, float maxAlpha, vec3 viewDir, float terrainDist, float depth, float globalTime, vec3 cameraPos) {
    // Odcięcie rysowania, gdy patrzymy na teren, który jest bliżej niż chmura
    if (t <= 0.0 || (depth < 0.99999 && t > terrainDist - Z_FIGHTING_BIAS)) return vec4(0.0);

    vec3 hitPos = cameraPos + viewDir * t;
    vec2 calcPos = floor(hitPos.xz / blockSize) * blockSize;
    calcPos.x += globalTime * speedMult;
    
    float val = fbm2(calcPos * scale);

    if (val > density) {
        vec3 cColor = baseColor;
        
        // Sprawdzanie krawędzi dla sztucznego cieniowania
        float edgeCheck = fbm2((calcPos + vec2(blockSize)) * scale);
        if (edgeCheck < density + 0.02) {
            cColor *= 0.85;
        }
        
        // Mgła dystansowa dla chmur
        float fogFactor = exp(-t * 0.0006);
        float finalAlpha = clamp(fogFactor, 0.0, 1.0) * maxAlpha;
        
        return vec4(cColor, finalAlpha);
    }
    
    return vec4(0.0);
}