#version 120

// --- USTAWIENIA PIKSELIZACJI CAŁEGO EKRANU (GLOBAL) ---
// 0 = Wyłączone (działa odległość), 1 = Cały ekran spikselowany na stałe
#define GLOBAL_PIXELATION_MODE 0 // [0 1]
#define GLOBAL_PIXEL_SIZE 4.0 // [2.0 3.0 4.0 6.0 8.0 16.0]

// --- USTAWIENIA PIKSELIZACJI ODLEGŁOŚCI (DISTANT PIXELATION) ---
#define ENABLE_DISTANCE_PIXELATION

// Od ilu kratek zaczyna się pikselizacja
#define DISTANCE_PIXEL_START 48.0 // [24.0 48.0 90.0 128.0]

// Dystans maksymalnego piksela (Zwiększ do 1024/2048 jeśli używasz Distant Horizons)
#define DISTANCE_PIXEL_MAX_DIST 512.0 // [256.0 512.0 1024.0 2048.0 4096.0]

// Wielkość klocka na horyzoncie w pikselach ekranu
#define DISTANCE_PIXEL_MAX_SIZE 12.0 // [2.0 4.0 8.0 12.0 16.0]

// --- USTAWIENIA ODBIĆ LAWY (VORONOI CAUSTICS) ---
#define ENABLE_LAVA_CAUSTICS
#define CAUSTICS_SCALE 0.25      // Skala pajęczyny świetlnej (mniejsza wartość = większe komórki)
#define CAUSTICS_SPEED 0.6       // Prędkość falowania światła
#define CAUSTICS_SHARPNESS 0.50  // Zwiększone dla jeszcze delikatniejszego, rozmytego przejścia (wcześniej 0.40)
#define CAUSTICS_STRENGTH 0.15   // Zmniejszone dla większej subtelności efektu (wcześniej 0.35)
#define CAUSTICS_COLOR vec3(1.0, 0.35, 0.05) // Kolor odbicia (mocny pomarańczowo-czerwony)


uniform sampler2D colortex0;
uniform sampler2D depthtex0;

// Zmienne potrzebne do animacji falowania i wykrywania zanurzenia
uniform float frameTimeCounter;
uniform int isEyeInWater;

// Oficjalne zmienne dla Distant Horizons (Iris)
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform mat4 dhProjectionInverse;
#endif

// Zmienne macierzy i kamery (do uzyskania pozycji świata)
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform float viewWidth;  
uniform float viewHeight; 

varying vec2 texcoord;

// ==========================================
// FUNKCJE VORONOI DLA ODBIĆ ŚWIATŁA
// ==========================================
vec2 hash2(vec2 p) {
    // Prosty hash dla pseudolosowych przesunięć komórek
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// Generuje siatkę komórkową (Pajęczyna / Kaustyka)
float voronoi_network(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);

    // Szukamy dwóch najbliższych punktów (F1 i F2), by znaleźć odległość do granicy komórek
    float F1 = 8.0;
    float F2 = 8.0;

    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash2(n + g);
            
            // Animacja punktów Voronoi w czasie (pływanie światła)
            o = 0.5 + 0.5 * sin(frameTimeCounter * CAUSTICS_SPEED + 6.2831 * o);
            
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
    // Różnica (F2 - F1) daje idealną siatkę/pajęczynę używaną do refleksów wodnych i podświetleń
    return F2 - F1;
}
// ==========================================

void main() {
    vec2 uv = texcoord;

    // --- 1. ZAKRZYWIENIE EKRANU W LAWIE (Jak pod wodą) ---
    // isEyeInWater: 0 = powietrze, 1 = woda, 2 = lawa
    if (isEyeInWater == 2) {
        // Mocne, gęste falowanie charakterystyczne dla lawy
        uv.x += sin(uv.y * 15.0 + frameTimeCounter * 3.0) * 0.015;
        uv.y += cos(uv.x * 15.0 + frameTimeCounter * 2.5) * 0.015;
    }

    // --- 2. EFEKT GORĄCEGO POWIETRZA (Heat Haze) NAD LAWĄ ---
    if (isEyeInWater == 0) {
        // Pobieramy wstępny kolor, żeby sprawdzić, czy patrzymy na coś gorącego
        vec3 preColor = texture2D(colortex0, uv).rgb;
        
        // Sprawdzamy, czy kolor przypomina lawę/ogień (dużo czerwieni, trochę zieleni, mało niebieskiego)
        bool isHot = (preColor.r > 0.7 && preColor.g > 0.15 && preColor.g < 0.6 && preColor.b < 0.2);
        
        if (isHot) {
            // Szybkie, drobne drgania symulujące uginanie się światła w gorącym powietrzu
            uv.x += sin(uv.y * 40.0 + frameTimeCounter * 6.0) * 0.0015;
            uv.y += cos(uv.x * 40.0 + frameTimeCounter * 5.0) * 0.0015;
        }
    }

    // --- SYSTEM PIKSELIZACJI ODLEGŁOŚCI / GLOBALNEJ ---
    vec2 finalUV = uv;
    
    #if GLOBAL_PIXELATION_MODE == 1
        // Opcja 1: Cały ekran jest twardo spikselowany
        vec2 res = vec2(viewWidth, viewHeight);
        finalUV = floor(uv * res / GLOBAL_PIXEL_SIZE) * GLOBAL_PIXEL_SIZE / res;
        finalUV += (GLOBAL_PIXEL_SIZE * 0.5) / res; 
    #else
        // Opcja 2: Pikselizacja oparta na odległości (wsparcie DH)
        #ifdef ENABLE_DISTANCE_PIXELATION
            float initialDepth = texture2D(depthtex0, uv).r;
            float distForPix = -1.0;
            
            if (initialDepth < 0.99999) { 
                vec4 initialPos = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, initialDepth * 2.0 - 1.0, 1.0);
                initialPos /= initialPos.w;
                distForPix = length(initialPos.xyz);
            } 
            #ifdef DISTANT_HORIZONS
            else {
                float dhDepth = texture2D(dhDepthTex, uv).r;
                if (dhDepth < 0.99999) {
                    vec4 initialPos = dhProjectionInverse * vec4(uv * 2.0 - 1.0, dhDepth * 2.0 - 1.0, 1.0);
                    initialPos /= initialPos.w;
                    distForPix = length(initialPos.xyz);
                    initialDepth = dhDepth; 
                }
            }
            #endif

            if (distForPix < 0.0) {
                distForPix = DISTANCE_PIXEL_MAX_DIST;
            }

            if (distForPix >= 0.0) {
                if (distForPix > DISTANCE_PIXEL_START) {
                    float factor = (distForPix - DISTANCE_PIXEL_START) / (DISTANCE_PIXEL_MAX_DIST - DISTANCE_PIXEL_START);
                    factor = clamp(factor, 0.0, 1.0);
                    
                    float pixelSize = mix(1.0, DISTANCE_PIXEL_MAX_SIZE, factor * factor); 
                    
                    if (pixelSize > 1.0) {
                        vec2 res = vec2(viewWidth, viewHeight);
                        finalUV = floor(uv * res / pixelSize) * pixelSize / res;
                        finalUV += (pixelSize * 0.5) / res; 
                    }
                }
            }
        #endif
    #endif

    // Wczytujemy finalny kolor obrazu
    vec3 color = texture2D(colortex0, finalUV).rgb;

    // Ochrona Edge-Bleed: Zapobiega rozmazywaniu się nieba na krawędzie bloków
    #if GLOBAL_PIXELATION_MODE == 0
        #ifdef ENABLE_DISTANCE_PIXELATION
            float sampledDepth = texture2D(depthtex0, finalUV).r;
            if (distForPix >= 0.0 && sampledDepth >= 0.99999) {
                color = texture2D(colortex0, uv).rgb;
            }
        #endif
    #endif

    // --- 3. RETRO ODBICIA LAWY (VORONOI CAUSTICS) ---
    #ifdef ENABLE_LAVA_CAUSTICS
    if (isEyeInWater == 0) {
        float currentDepth = texture2D(depthtex0, finalUV).r;
        bool isTerrain = currentDepth < 0.99999;
        vec4 viewPos;
        
        // Rekonstrukcja widoku
        if (isTerrain) {
            vec4 ndcPos = vec4(finalUV * 2.0 - 1.0, currentDepth * 2.0 - 1.0, 1.0);
            viewPos = gbufferProjectionInverse * ndcPos;
            viewPos /= viewPos.w;
        }
        
        // Wsparcie dla głębi z Distant Horizons
        #ifdef DISTANT_HORIZONS
        else {
            float dhDepth = texture2D(dhDepthTex, finalUV).r;
            if (dhDepth < 0.99999) {
                isTerrain = true;
                vec4 ndcPos = vec4(finalUV * 2.0 - 1.0, dhDepth * 2.0 - 1.0, 1.0);
                viewPos = dhProjectionInverse * ndcPos;
                viewPos /= viewPos.w;
            }
        }
        #endif

        if (isTerrain) {
            // Pozycja w świecie gier
            vec4 playerPos = gbufferModelViewInverse * viewPos;
            vec3 worldPos = playerPos.xyz + cameraPosition;
            
            // --- WYLICZANIE KIERUNKU ŚCIANY (Normal) ---
            // Używamy pochodnych ekranowych (dFdx/dFdy), by obliczyć kąt nachylenia bloku
            vec3 dX = dFdx(worldPos);
            vec3 dY = dFdy(worldPos);
            vec3 normal = normalize(cross(dX, dY));
            
            // Upewniamy się, że wektor patrzy w stronę gracza
            vec3 viewDir = normalize(playerPos.xyz);
            if (dot(normal, viewDir) > 0.0) normal = -normal;
            
            // Maska blokująca efekt na górnych powierzchniach bloków.
            // normal.y waha się od -1.0 (dół) do 1.0 (góra). 
            // smoothstep płynnie redukuje efekt do 0.0, gdy patrzymy na górę bloku.
            float surfaceMask = smoothstep(0.5, 0.2, normal.y);
            
            if (surfaceMask > 0.0) {
                // MAPOWANIE KLASYCZNE: rzutowanie tylko z góry w dół (X oraz Z).
                vec2 causticUV = worldPos.xz * CAUSTICS_SCALE;
                
                // Pomalutku przesuwamy całą "pajęczynę" z duchem czasu
                causticUV.x += frameTimeCounter * (CAUSTICS_SPEED * 0.15);
                causticUV.y += frameTimeCounter * (CAUSTICS_SPEED * 0.15);
                
                // Obliczamy wzór Voronoi
                float network = voronoi_network(causticUV);
                
                // Konwertujemy sieć Voronoi na miękkie promienie światła (większy CAUSTICS_SHARPNESS)
                float causticLight = 1.0 - smoothstep(0.0, CAUSTICS_SHARPNESS, network);
                
                // Dodajemy lekkie pulsowanie, żeby przypominało żarzącą się lawę
                float pulse = 0.85 + 0.15 * sin(frameTimeCounter * 1.5);
                causticLight *= pulse;
                
                // Delikatne wygaszanie w oddali (efekt ambientu)
                float dist = length(playerPos.xyz);
                float distFade = 1.0 - clamp(dist / 128.0, 0.0, 1.0); // Zanika łagodnie od 0 do 128 bloku od gracza (wcześniej 48)

                // Finalny kolor dodanego światła, pomnożony przez surfaceMask, aby zablokować górę
                vec3 finalCausticColor = CAUSTICS_COLOR * causticLight * CAUSTICS_STRENGTH * distFade * surfaceMask;
                
                // Mieszanie addytywne - delikatnie rozjaśnia oryginalny kolor bloku od dołu i z boku
                color += finalCausticColor;
            }
        }
    }
    #endif

    // Jeśli jesteśmy w lawie, nakładamy głęboki pomarańczowo-czerwony filtr na cały ekran
    if (isEyeInWater == 2) {
        color *= vec3(0.8, 0.2, 0.05);
    }

    gl_FragColor = vec4(color, 1.0);
}