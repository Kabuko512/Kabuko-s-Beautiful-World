// --- /lib/materials/lighting.glsl ---

// Włącznik efektu (pojawi się w menu)
#define ENABLE_CUSTOM_BLOCK_LIGHT

// Suwak krzywej światła. 
// 1.0 = Vanilla (liniowo i nudno). 
// 2.5 = Inverse-Square (mocny rdzeń, klimatyczne, głębokie cienie)
#define LIGHT_CURVE 2.5 // [1.0 1.5 2.0 2.5 3.0 4.0]

vec3 getCustomLighting(sampler2D lightmap, vec2 lmcoord) {
    #ifdef ENABLE_CUSTOM_BLOCK_LIGHT
        // 1. POBRANIE ŚWIATŁA NIEBA (Słońce / Księżyc)
        // Oś Y w lmcoord to oświetlenie z nieba. Pobieramy je z "lewej krawędzi" (x=0.03125 to minimalna wartość, zero),
        // aby uzyskać czyste słońce/księżyc bez waniliowego światła pochodni.
        vec3 skyLight = texture2D(lightmap, vec2(0.03125, lmcoord.y)).rgb;
        
        // 2. EKSTRAKCJA SUROWEGO ŚWIATŁA Z POCHODNI (Oś X)
        // Minecraft podaje je w zakresie od ok. 0.03 do 0.96. Skalujemy to do idealnego 0.0 - 1.0.
        float blockLightRaw = clamp((lmcoord.x - 0.03125) / 0.9375, 0.0, 1.0);
        
        // 3. INVERSE-SQUARE (Krzywa kinowa)
        // Tu dzieje się magia! Liniowe 0.5 podniesione do potęgi 2.5 staje się 0.17.
        // Oznacza to, że światło błyskawicznie "gaśnie", zostawiając głęboki i nastrojowy mrok w kopalniach.
        float blockLightSq = pow(blockLightRaw, LIGHT_CURVE);
        
        // 4. TERMICZNE MAPOWANIE (Blackbody)
        vec3 coreColor = vec3(1.0, 0.85, 0.6); // Bardzo jasny, biało-żółty środek (przy samej pochodni)
        vec3 edgeColor = vec3(1.0, 0.25, 0.0); // Krwisto-pomarańczowy, nasycony kolor na krawędziach cienia
        
        // Płynne mieszanie: blisko = coreColor, daleko = edgeColor
        vec3 lightTint = mix(edgeColor, coreColor, blockLightSq);
        
        // 5. ZŁOŻENIE W CAŁOŚĆ
        // Mnożnik 2.0 podbija rdzeń pochodni, by pomimo głębokich cieni nie było całkowicie ciemno obok niej.
        vec3 customBlockLight = lightTint * blockLightSq * 2.0;
        
        return skyLight + customBlockLight;
    #else
        // Tryb zapasowy - czyste oświetlenie z Minecrafta
        return texture2D(lightmap, lmcoord).rgb;
    #endif
}