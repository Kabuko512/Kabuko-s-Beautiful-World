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

// Zmienne (varying) przekazujące dane do efektu połysku (Fresnela)
varying vec3 normal;
varying vec3 viewVector;
varying float isEndStone;

// --- DODANE DLA EFEKTU MOKRYCH POWIERZCHNI ---
varying vec3 vWorldPos;
varying vec3 worldNormal;

void main() {
    // Przekazanie koordynatów tekstury, światła i koloru do fragment shadera
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
    glcolor = gl_Color;

    // Obliczenie wektora normalnego ściany i wektora patrzenia
    normal = normalize(gl_NormalMatrix * gl_Normal);
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    viewVector = normalize(-viewPos.xyz);

    // Przekazujemy absolutną orientację w świecie by wiedzieć co jest "podłogą"
    worldNormal = gl_Normal;

    // Pobranie lokalnej pozycji wierzchołka
    vec4 position = gl_Vertex;

    // Detekcja bloków na podstawie block.properties
    bool isPlant = mc_Entity.x == 10000.0;
    bool isLeaves = mc_Entity.x == 10001.0;
    isEndStone = (mc_Entity.x == 10002.0) ? 1.0 : 0.0;

    // Pozycja w świecie i ujednolicony czas
    vec3 worldPos = position.xyz + cameraPosition;
    
    // Przekazanie fizycznej pozycji w świecie do fragment shadera (aby kałuże były przypięte do ziemi)
    vWorldPos = worldPos;
    
    float time = float(worldTime) * 0.05;

    // ========================================================
    // EFEKT 1: LEWITUJĄCE WYSPY ENDU (Zero Gravity Islands)
    // ========================================================
    if (isEndStone > 0.5) {
        float floatOffset = sin(time * 0.15 + worldPos.x * 0.02 + worldPos.z * 0.02) * 0.35;
        floatOffset += cos(time * 0.1 + worldPos.x * 0.01 - worldPos.z * 0.01) * 0.15;
        position.y += floatOffset;
    }

    // ========================================================
    // LOGIKA POGODY I WIATRU (Dla Roślin i Liści)
    // ========================================================
    if (isPlant || isLeaves) {
        float isTop = step(gl_MultiTexCoord0.t, mc_midTexCoord.t);
        float waveAmount = isPlant ? isTop : 1.0;

        if (waveAmount > 0.0) {
            float calmWave1 = sin(time * 1.0 + worldPos.x * 0.8 + worldPos.z * 0.8);
            float calmWave2 = cos(time * 0.7 + worldPos.x * 1.5 + worldPos.z * 1.5);
            vec3 calmOffset = vec3(calmWave1 + calmWave2, 0.0, calmWave1 - calmWave2) * 0.05;

            float stormWave1 = sin(time * 2.5 + worldPos.x * 0.8 + worldPos.z * 0.8);
            float stormWave2 = cos(time * 1.7 + worldPos.x * 1.5 + worldPos.z * 1.5);
            vec3 stormOffset = vec3(stormWave1 + stormWave2, 0.0, stormWave1 - stormWave2) * 0.20;

            vec3 windOffset = mix(calmOffset, stormOffset, rainStrength) * waveAmount;

            if (rainStrength > 0.7) {
                float gust = sin(time * 6.0 + worldPos.x + worldPos.z) * 0.15 * rainStrength;
                windOffset.x += gust * waveAmount;
                windOffset.z += gust * waveAmount;
            }

            position.xyz += windOffset;
        }
    }

    // Przekazanie ostatecznej pozycji na ekran
    gl_Position = gl_ModelViewProjectionMatrix * position;
}