/* * ==============================================================================
 * PLIK 1: gbuffers_terrain.vsh (VERTEX SHADER)
 * Ten plik odpowiada za "falowanie" wierzchołków lawy i fizyczne wypychanie 
 * krawędzi Voronoi w górę.
 * ==============================================================================
 */

#version 120

// Standardowe zmienne OptiFine / Iris
attribute vec4 mc_Entity;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition; // <-- DODANO: Zmienna przechowująca absolutną pozycję kamery w świecie
uniform float frameTimeCounter;

varying vec2 texcoord;
varying vec4 glColor;
varying float vEdgeHeight; // Wysyłamy wysokość wypukłości do fragment shadera
varying float vIsLava;     // Flaga przekazująca informację, że to lawa

// Funkcja Hash do szumu
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// Obliczanie Voronoi
vec3 voronoi(vec2 x, float time) {
    vec2 n = floor(x);
    vec2 f = fract(x);

    float F1 = 8.0;
    float F2 = 8.0;

    for(int j = -1; j <= 1; j++) {
        for(int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash2(n + g);
            
            // Płynna animacja punktów
            o = 0.5 + 0.5 * sin(time * 1.5 + 6.2831 * o);
            
            vec2 r = g + o - f;
            float d = dot(r, r);

            if(d < F1) {
                F2 = F1;
                F1 = d;
            } else if(d < F2) {
                F2 = d;
            }
        }
    }
    // Zwraca (Dystans_F1, Dystans_F2, Różnica F2 - F1)
    return vec3(sqrt(F1), sqrt(F2), F2 - F1);
}

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    glColor = gl_Color;
    
    vec4 position = gl_Vertex;
    
    // Konwersja do przestrzeni świata relatywnie do gracza
    vec4 playerPos = gbufferModelViewInverse * gl_ModelViewMatrix * position;
    
    // <-- ZMIANA 1: Prawdziwa i stała koordynata świata, niezależna od ruchu gracza
    vec3 worldPosAbsolute = playerPos.xyz + cameraPosition;
    
    // Weryfikacja po ID. Wymaga pliku block.properties wpisującego lawę pod ID 10 i 11.
    if (mc_Entity.x == 10.0 || mc_Entity.x == 11.0) {
        vIsLava = 1.0; // Oznaczamy blok jako lawę dla Fragment Shadera
        
        // <-- ZMIANA 2: Zapętlamy czas co 3600 sekund (1h). Zapobiega to utracie precyzji zmiennych float 
        // przy wysokich ilościach klatek, co powodowało klatkowanie animacji szumu.
        float safeTime = mod(frameTimeCounter, 3600.0);

        // Generowanie kordów dla szumu z wykorzystaniem STAŁYCH koordynatów
        vec2 uv = worldPosAbsolute.xz * 0.8; 
        uv.y -= safeTime * 0.4;
        uv.x -= safeTime * 0.15;

        // Obliczamy wzór Voronoi na podstawie bezpiecznego czasu
        vec3 v = voronoi(uv, safeTime);
        
        // Maska z Voronoi: Im mniejsza wartość (F2-F1), tym bliżej krawędzi
        float edge = 1.0 - smoothstep(0.0, 0.25, v.z);
        
        // FIZYCZNE PODNIESIENIE WIERZCHOŁKA
        position.y += edge * 0.4; 
        
        vEdgeHeight = edge;
    } else {
        vIsLava = 0.0;
        vEdgeHeight = 0.0;
    }

    gl_Position = gl_ModelViewProjectionMatrix * position;
}