#version 120

// Zmienne pobierane bezpośrednio z gry
attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;

// Uniformy udostępniane przez Iris / OptiFine
uniform int worldTime;          // Czas świata w tickach (odporny na błąd FPS, 20 ticków/sekundę)
uniform float rainStrength;     // Siła deszczu (0.0 - bezchmurnie, 1.0 - deszcz/burza)
uniform vec3 cameraPosition;    // Pozycja kamery w świecie

varying vec2 texcoord;
varying vec2 lmcoord;           // Koordynaty mapy światła (światło blokowe + słońce)
varying vec4 glcolor;

void main() {
    // Przekazanie koordynatów tekstury, światła i koloru do fragment shadera
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
    glcolor = gl_Color;

    // Pobranie lokalnej pozycji wierzchołka
    vec4 position = gl_Vertex;

    // Detekcja, czy dany blok to roślina, na podstawie block.properties
    // ID 10000 = Trawa, kwiaty itp. | ID 10001 = Liście
    bool isPlant = mc_Entity.x == 10000.0;
    bool isLeaves = mc_Entity.x == 10001.0;

    if (isPlant || isLeaves) {
        // Obliczanie, czy wierzchołek znajduje się w górnej połowie bloku.
        float isTop = step(gl_MultiTexCoord0.t, mc_midTexCoord.t);

        // Chcemy, aby liście ruszały się w całości, a trawa falowała tylko na górze
        float waveAmount = isPlant ? isTop : 1.0;

        if (waveAmount > 0.0) {
            // -- LOGIKA POGODY --
            
            // Używamy worldTime zamiast frameTimeCounter, aby uniknąć problemu z precyzją float i uniezależnić się od FPS
            float time = float(worldTime) * 0.05;
            vec3 worldPos = position.xyz + cameraPosition;

            // 1. Fale dla spokojnej pogody (stała, wolna prędkość)
            float calmWave1 = sin(time * 1.0 + worldPos.x * 0.8 + worldPos.z * 0.8);
            float calmWave2 = cos(time * 0.7 + worldPos.x * 1.5 + worldPos.z * 1.5);
            vec3 calmOffset = vec3(calmWave1 + calmWave2, 0.0, calmWave1 - calmWave2) * 0.05;

            // 2. Fale dla burzy/deszczu (stała, szybka prędkość)
            float stormWave1 = sin(time * 2.5 + worldPos.x * 0.8 + worldPos.z * 0.8);
            float stormWave2 = cos(time * 1.7 + worldPos.x * 1.5 + worldPos.z * 1.5);
            vec3 stormOffset = vec3(stormWave1 + stormWave2, 0.0, stormWave1 - stormWave2) * 0.20;

            // Płynne przejście między spokojnym a burzowym wiatrem w zależności od rainStrength
            // Dzięki temu rozwiązujemy problem "turbo prędkości" podczas zmiany pogody
            vec3 windOffset = mix(calmOffset, stormOffset, rainStrength) * waveAmount;

            // 3. Ekstremalne porywy wiatru tylko w trakcie silnej burzy (gdy rainStrength jest bliskie 1.0)
            if (rainStrength > 0.7) {
                // Dodatkowa, bardzo szybka fala imitująca mocniejsze szarpnięcia wiatru
                float gust = sin(time * 6.0 + worldPos.x + worldPos.z) * 0.15 * rainStrength;
                windOffset.x += gust * waveAmount;
                windOffset.z += gust * waveAmount;
            }

            // Zaaplikowanie wiatru do pozycji wierzchołka
            position.xyz += windOffset;
        }
    }

    // Przekazanie ostatecznej pozycji na ekran
    gl_Position = gl_ModelViewProjectionMatrix * position;
}