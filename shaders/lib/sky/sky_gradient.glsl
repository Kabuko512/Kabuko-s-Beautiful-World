// --- /lib/sky/sky_gradient.glsl ---

// ==========================================================
// 🧪 TWOJE LABORATORIUM KOLORÓW (EDYTUJ ŚMIAŁO!)
// Wartości RGB od 0.0 do 1.0 (Czerwony, Zielony, Niebieski)
// ==========================================================

// --- 1. KOLORY SAMEGO NIEBA (Tło za chmurami) ---
// Mogą być ciemniejsze. Dzięki temu niebo nad głową jest głębokie i nie psuje ekspozycji (HDR).
#define SKY_DAY_ZENITH    vec3(0.04, 0.12, 0.35)
#define SKY_DAY_HORIZON   vec3(0.12, 0.28, 0.50)

#define SKY_NIGHT_ZENITH  vec3(0.01, 0.01, 0.03)
#define SKY_NIGHT_HORIZON vec3(0.02, 0.02, 0.06)

#define SKY_SUNSET        vec3(0.80, 0.30, 0.10)

// --- 2. KOLORY MGŁY ATMOSFERYCZNEJ (LOD, Voxy, DH) ---
// Tutaj dajemy czadu! Mgła może być bardzo jasna. 
// Rozjaśnij FOG_DAY, aby uzyskać efekt anime / Ghibli, nie psując przy tym nieba!
#define FOG_DAY           vec3(0.85, 0.85, 0.85) 
#define FOG_NIGHT         vec3(0.02, 0.03, 0.06)
#define FOG_SUNSET        vec3(0.90, 0.40, 0.15)

// ==========================================================


// Funkcja 1: Wylicza kolor NIEBA (Tła)
vec3 getSkyColor(vec3 viewDir, vec3 sunDir, vec3 fogColVanilla, float rain) {
    float sunHeight = sunDir.y;
    float dayFactor = smoothstep(-0.2, 0.2, sunHeight); 
    float sunsetFactor = smoothstep(0.3, -0.1, abs(sunHeight - 0.1)); 

    vec3 zenith = mix(SKY_NIGHT_ZENITH, SKY_DAY_ZENITH, dayFactor);
    vec3 horizon = mix(SKY_NIGHT_HORIZON, SKY_DAY_HORIZON, dayFactor);
    
    // Dodatek blasku zachodu słońca
    horizon = mix(horizon, SKY_SUNSET, sunsetFactor * (1.0 - rain));

    float up = max(viewDir.y, 0.0);
    vec3 sky = mix(horizon, zenith, pow(up, 0.6));

    // Deszcz przyciemnia niebo
    vec3 rainSky = fogColVanilla * 0.4;
    sky = mix(sky, rainSky, rain);

    return sky;
}

// Funkcja 2: Wylicza kolor MGŁY (Nakładany na teren i Voxy/DH)
vec3 getAtmosphericFogColor(vec3 viewDir, vec3 sunDir, vec3 fogColVanilla, float rain) {
    float sunHeight = sunDir.y;
    float dayFactor = smoothstep(-0.2, 0.2, sunHeight); 
    float sunsetFactor = smoothstep(0.3, -0.1, abs(sunHeight - 0.1)); 

    // Bierzemy od razu Twój jasny kolor mgły z ustawień
    vec3 fogBase = mix(FOG_NIGHT, FOG_DAY, dayFactor);
    
    // Obliczamy "płaski" dystans do słońca, by mgła była pomarańczowa tylko tam, gdzie zachodzi słońce!
    vec3 flatView = vec3(viewDir.x, 0.0, viewDir.z);
    vec3 flatSun = vec3(sunDir.x, 0.0, sunDir.z);
    float sunGlow = 0.0;
    
    if (length(flatView) > 0.001 && length(flatSun) > 0.001) {
        sunGlow = pow(max(dot(normalize(flatView), normalize(flatSun)), 0.0), 2.0);
    }
    
    fogBase = mix(fogBase, FOG_SUNSET, sunsetFactor * sunGlow * (1.0 - rain));

    // Podczas deszczu mgła staje się mocno szara (pobiera kolor mgły z gry)
    fogBase = mix(fogBase, fogColVanilla * 0.7, rain);

    return fogBase;
}