// --- /lib/sky/fog.glsl ---
// Ten plik odpowiada za płynną mgłę atmosferyczną.
// Inteligentnie dopasowuje się do Render Distance oraz do modów Voxy/Distant Horizons!

uniform float far; // Pobiera rzeczywisty dystans rysowania (Render Distance) z gry

// DODANO: Ręczny przełącznik (będziesz mógł dodać go do menu gry)
// ZAKOMENTOWANE: abyś mógł od razu przetestować mgłę Vanilla po wklejeniu kodu!
//#define ENABLE_LOD_SUPPORT

vec3 applyAtmosphericFog(vec3 terrainColor, vec3 viewDir, float terrainDist, vec3 sunDirWorld, float rainStrength, vec3 fogColorVanilla, int isEyeInWater, float blindness) {
    
    float fogFactor = 1.0;
    vec3 finalFogColor = fogColorVanilla;

    if (isEyeInWater == 1) {
        // Mgła pod wodą
        float waterDensity = 0.05;
        fogFactor = exp(-pow(terrainDist * waterDensity, 1.5));
        float sunDot = max(dot(viewDir, sunDirWorld), 0.0);
        finalFogColor += vec3(0.1, 0.3, 0.4) * pow(sunDot, 4.0) * 0.5;
        
    } else if (isEyeInWater == 2) {
        // Mgła w lawie
        float lavaDensity = 0.5;
        fogFactor = exp(-pow(terrainDist * lavaDensity, 1.5));
        finalFogColor = vec3(0.8, 0.1, 0.0); 
        
    } else {
        if (blindness > 0.0) {
            float blindDensity = mix(0.005, 0.2, blindness);
            fogFactor = exp(-pow(terrainDist * blindDensity, 1.5));
            finalFogColor = vec3(0.0);
        } else {
            // Wykorzystanie oddzielnego koloru mgły (z Twojego laboratorium w sky_gradient.glsl)
            vec3 horizonViewDir = vec3(viewDir.x, 0.0, viewDir.z);
            if (length(horizonViewDir) > 0.001) {
                horizonViewDir = normalize(horizonViewDir);
            } else {
                horizonViewDir = vec3(1.0, 0.0, 0.0); 
            }
            
            finalFogColor = getAtmosphericFogColor(horizonViewDir, sunDirWorld, fogColorVanilla, rainStrength);

            // Blask słońca
            float sunDot = max(dot(viewDir, sunDirWorld), 0.0);
            float sunGlare = pow(sunDot, 8.0) * 0.5 * (1.0 - rainStrength);
            vec3 glareColor = vec3(1.0, 0.8, 0.4); 
            finalFogColor += glareColor * sunGlare;
            
            // =======================================================
            // 🌫️ RĘCZNY WYBÓR TRYBU MGŁY (VANILLA vs LOD)
            // =======================================================
            
            #ifdef ENABLE_LOD_SUPPORT
                // 1. TRYB LOD (Voxy / Distant Horizons)
                // Ignorujemy zbugowane zmienne gry i ustawiamy sztywny, bardzo powolny spadek mgły.
                float lodBaseDensity = 0.0003; // <-- Zmniejsz to (np. do 0.0001), aby widzieć LOD jeszcze dalej!
                float lodRainDensity = 0.002; 
                float lodDensity = mix(lodBaseDensity, lodRainDensity, rainStrength);
                
                fogFactor = exp(-pow(terrainDist * lodDensity, 1.5));
            #else
                // 2. TRYB VANILLA (Standardowy Render Distance z gry)
                // Ściągamy granicę mgły lekko do siebie, aby szybciej odcinała i w 100% ukryła urwane chunki!
                float fogEnd = far * 0.90;   // Pełne zakrycie pojawia się już na 90% odległości z opcji gry
                float fogStart = far * 0.50; // Zaczynamy gęstnieć wcześniej (od połowy dystansu)
                
                // Matematyczne odcięcie świata (pomiędzy fogStart a fogEnd)
                float vanillaEdge = clamp((fogEnd - terrainDist) / max(fogEnd - fogStart, 1.0), 0.0, 1.0);
                
                // Leciutka, błękitna mgiełka wewnątrz załadowanych chunków (dla atmosfery)
                float atmosphere = exp(-pow(terrainDist * 0.002, 1.5));
                
                // Zawsze wybieramy to co skuteczniej ukrywa pustkę (zwykle krawędź)
                fogFactor = min(atmosphere, vanillaEdge);
            #endif
        }
    }

    fogFactor = clamp(fogFactor, 0.0, 1.0);
    return mix(finalFogColor, terrainColor, fogFactor);
}