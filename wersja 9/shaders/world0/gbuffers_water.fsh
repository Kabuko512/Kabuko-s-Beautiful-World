#version 120

// --- TRYB WODY ---
#define WATER_STYLE 2 // [0 1 2] Tryb wody: 0 = Czysty Vanilla, 1 = Enhanced Vanilla, 2 = Stylizowana (Voronoi)

// --- USTAWIENIA WODY (Tylko dla trybu 2) ---
// Usunąłem sztuczne kolory (WATER_R/G/B), ponieważ teraz pobieramy kolor idealnie z Vanilla/Voxy
#define WATER_OPACITY 0.75    // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0] Przezroczystość wody
#define CAUSTIC_SPEED 1.0     // [0.5 1.0 1.5 2.0 3.0] Prędkość falowania piany
#define CAUSTIC_SCALE 1.5     // [0.5 1.0 1.5 2.0 3.0] Skala komórek Voronoi (jak gęsta jest sieć)
#define CAUSTIC_INTENSITY 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0] Siła jasnego wzoru

uniform sampler2D texture;
uniform sampler2D lightmap;   // <-- DODANE: Pobranie systemowej jasności z Minecrafta
uniform float frameTimeCounter;

varying vec2 texcoord;
varying vec2 lmcoord;         // <-- DODANE: Koordynaty lightmapy z Vertex Shadera
varying vec4 glColor;
varying vec3 absWorldPos;

// Szybka funkcja losowa do szumu
vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

// Algorytm Voronoi (Celullar Noise)
float getWaterCaustics(vec2 p, float time) {
    vec2 n = floor(p);
    vec2 f = fract(p);
    
    float F1 = 8.0; 
    float F2 = 8.0; 
    
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash22(n + g);
            
            o = 0.5 + 0.5 * sin(time + 6.2831 * o); 
            
            vec2 r = g + o - f;
            float d = dot(r, r);
            
            if (d < F1) {
                F2 = F1;
                F1 = d;
            } else if (d < F2) {
                F2 = d;
            }
        }
    }
    
    return sqrt(F2) - sqrt(F1);
}

void main() {
    // Pobieramy naturalne oświetlenie dla tego bloku (reaguje na słońce, księżyc, pochodnie)
    vec3 lightmapColor = texture2D(lightmap, lmcoord).rgb;

    // Tryb 0: Oryginalna woda Minecraft (żadnych zmian poza nałożeniem światła)
    if (WATER_STYLE == 0) {
        vec4 texColor = texture2D(texture, texcoord) * glColor;
        gl_FragData[0] = vec4(texColor.rgb * lightmapColor, texColor.a);
        return;
    }

    // Ochrona precyzji zmiennoprzecinkowej
    float safeTime = mod(frameTimeCounter, 3600.0);

    // Tryb 1: Enhanced Vanilla
    if (WATER_STYLE == 1) {
        vec2 warpVanilla = vec2(sin(safeTime * 1.0 + absWorldPos.z * 0.8),
                                cos(safeTime * 0.9 + absWorldPos.x * 0.8)) * 0.0015;
        
        vec4 texColor = texture2D(texture, texcoord + warpVanilla) * glColor;
        gl_FragData[0] = vec4(texColor.rgb * lightmapColor, texColor.a);
        return;
    }

    // Tryb 2: Stylizowana woda (Voronoi Caustics) + Oświetlenie MC
    safeTime *= CAUSTIC_SPEED;

    vec2 worldCoord = absWorldPos.xz * 0.5 * CAUSTIC_SCALE;
    vec2 warp = vec2(sin(safeTime * 1.2 + worldCoord.y * 2.5), 
                     cos(safeTime * 1.1 + worldCoord.x * 2.5)) * 0.15;
    
    float edges1 = getWaterCaustics(worldCoord + warp, safeTime * 1.5);
    float edges2 = getWaterCaustics((worldCoord * 0.75) - warp, safeTime * 0.9);
    
    float c1 = smoothstep(0.12, 0.02, edges1);
    float c2 = smoothstep(0.15, 0.03, edges2) * 0.6;
    
    float caustics = max(c1, c2) * CAUSTIC_INTENSITY;
    float glow = smoothstep(0.3, 0.0, min(edges1, edges2)) * 0.3 * CAUSTIC_INTENSITY;

    // --- 1. TEKSTURA MINECRAFTA (Idealna baza) ---
    // Zamiast wymyślać własny kolor, bierzemy ten prosto z Voxy/Minecrafta
    // Mnożenie przez glColor daje nam odpowiedni, dynamiczny odcień biomu!
    vec4 vanillaBaseColor = texture2D(texture, texcoord) * glColor;
    
    vec3 finalColor = vanillaBaseColor.rgb;
    vec3 brightWaterGlow = vec3(0.7, 0.95, 1.0); 

    // --- 2. APLIKACJA WZORU ---
    // Subtelnie dodajemy sieć na wierzch koloru z silnika
    finalColor += brightWaterGlow * (caustics + glow) * 0.8;

    // --- 3. APLIKACJA OŚWIETLENIA (Kluczowa zmiana) ---
    // Mnożymy finalny wynik przez lightmapę.
    // W nocy 'lightmapColor' ma ciemne, niebieskawe barwy, więc cała woda
    // (włączając w to jasne kreski z Voronoi) pięknie ściemnieje!
    finalColor *= lightmapColor;

    // Przekazanie rezultatu na ekran
    gl_FragData[0] = vec4(finalColor, WATER_OPACITY);
}