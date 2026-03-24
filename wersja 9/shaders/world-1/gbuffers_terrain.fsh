
/* * ==============================================================================
 * PLIK 2: gbuffers_terrain.fsh (FRAGMENT SHADER)
 * Ten plik odpowiada za kolory lawy bazujące na wypukłości Voronoi, 
 * a także za maskę głębokości (rozjaśnianie brzegów stykających się z blokami).
 * ==============================================================================
 */

#version 120

uniform sampler2D texture;
uniform sampler2D depthtex0; // Bufor głębokości do maski głębi
uniform sampler2D depthtex1; // Niektóre paczki używają depthtex1 dla solidnych bloków
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

varying vec2 texcoord;
varying vec4 glColor;
varying float vEdgeHeight; // Wysokość krawędzi odebrana z vertex shadera
varying float vIsLava;     // Sprawdzamy, czy aktualnie renderowany piksel to lawa

// Funkcja zamieniająca nieliniową głębię na liniową odległość (potrzebne do maski)
float linearizeDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

void main() {
    // Podstawowa tekstura bloku (trawa, kamień, lawa itd.)
    vec4 albedo = texture2D(texture, texcoord) * glColor;
    
    // Wykonujemy efekty TYLKO na lawie, żeby reszta świata nie świeciła
    if (vIsLava > 0.5) {
        // --- 1. Kolorowanie na podstawie Maski Wysokości Voronoi ---
        vec3 magmaDark = vec3(0.3, 0.05, 0.0);
        vec3 magmaRed = vec3(0.8, 0.15, 0.0);
        vec3 lavaOrange = vec3(1.0, 0.4, 0.0);
        vec3 lavaYellow = vec3(1.0, 0.9, 0.2);

        // Mieszamy kolory: nisko jest ciemna magma, wysoko (krawędzie voronoi) jasna lawa
        vec3 lavaColor = mix(magmaDark, magmaRed, smoothstep(0.0, 0.3, vEdgeHeight));
        lavaColor = mix(lavaColor, lavaOrange, smoothstep(0.3, 0.7, vEdgeHeight));
        lavaColor = mix(lavaColor, lavaYellow, smoothstep(0.7, 1.0, vEdgeHeight));
        
        // Zostawiam część oryginalnej tekstury
        albedo.rgb = mix(albedo.rgb, lavaColor, 0.85);

        // --- 2. Maska Głębokości (Depth Mask) dla brzegów jeziora lawy ---
        vec2 screenCoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
        
        // Głębokość tła (bloki skalne pod/obok lawy)
        float backgroundDepth = texture2D(depthtex1, screenCoord).r; 
        float currentDepth = gl_FragCoord.z; 

        // Konwersja
        float linearBG = linearizeDepth(backgroundDepth);
        float linearCurrent = linearizeDepth(currentDepth);
        
        float depthDiff = linearBG - linearCurrent;
        
        // Maska brzegu
        float shorelineMask = 1.0 - smoothstep(0.0, 0.5, depthDiff);
        
        // Dodajemy jasne świecenie na styku z brzegiem
        albedo.rgb += vec3(1.0, 0.6, 0.1) * shorelineMask;
    }

    // Wypisanie na ekran
    gl_FragData[0] = albedo;
}