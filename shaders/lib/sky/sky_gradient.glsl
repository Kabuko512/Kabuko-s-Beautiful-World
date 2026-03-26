// --- /lib/sky/sky_gradient.glsl ---

vec3 getSkyColor(vec3 viewDir, vec3 sunDir, vec3 fogCol, float rain) {
    // 1. Sprawdzamy porę dnia na podstawie wysokości słońca
    float sunHeight = sunDir.y;
    float dayFactor = smoothstep(-0.2, 0.2, sunHeight); // 1.0 = dzień, 0.0 = noc
    float sunsetFactor = smoothstep(0.3, -0.1, abs(sunHeight - 0.1)); // Błysk przy horyzoncie

// 2. Definiujemy kolory Zenitu (czubek głowy) i Horyzontu
    
    // Ustawiamy globalny mnożnik jasności dnia, żeby łatwiej było to kalibrować
    float dayBrightness = 0.15; // Zmieniaj tę wartość (np. od 0.05 do 0.5), by zbalansować dzień

    // Dzień: Ekstremalnie zaniżone wartości bazowe (tonemapper je podbije)
    vec3 dayZenith = vec3(0.02, 0.08, 0.25) * dayBrightness; 
    vec3 dayHorizon = vec3(0.1, 0.25, 0.4) * dayBrightness;

    // Noc i zachód bez zmian, skoro wyglądają dobrze
    vec3 nightZenith = vec3(0.02, 0.02, 0.05);
    vec3 nightHorizon = vec3(0.05, 0.05, 0.1);
    vec3 sunsetCol = vec3(1.0, 0.4, 0.15);

    // 3. Mieszamy kolory zależnie od dnia/nocy
    vec3 zenith = mix(nightZenith, dayZenith, dayFactor);
    vec3 horizon = mix(nightHorizon, dayHorizon, dayFactor);

    // Dodajemy ciepły blask zachodu słońca przy horyzoncie (bez zmian)
    horizon = mix(horizon, sunsetCol, sunsetFactor * (1.0 - rain));

    // 4. Obliczamy końcowy gradient
    // Wykorzystujemy viewDir.y (od -1.0 do 1.0)
    float up = max(viewDir.y, 0.0);
    
    // Potęga pow(up, 0.5) sprawia, że przejście jest miękkie i naturalne
    vec3 sky = mix(horizon, zenith, pow(up, 0.6));

    // 5. Wygaszenie nieba podczas deszczu (szary filtr)
    vec3 rainSky = fogCol * 0.5;
    sky = mix(sky, rainSky, rain);

    return sky;
}