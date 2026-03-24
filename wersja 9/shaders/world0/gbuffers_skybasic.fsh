#version 120

// ==========================================
// --- USTAWIENIA SHADERA ---
// ==========================================
#define WLACZ_GWIAZDY true        // [true false] Wlacza lub wylacza gwiazdy
#define INTENSYWNOSC_GWIAZD 1.0   // [0.2 0.5 0.8 1.0 1.2 1.5 2.0] Jasnosc gwiazd

#define WLACZ_ZORZE true          // [true false] Wlacza lub wylacza zorze polarna
#define SKUPIENIE_ZORZY 0.3       // [0.1 0.2 0.3 0.5 0.7 1.0] Wielkosc skupisk zorzy (0.3 = widoczna tylko na ~30% nieba jako oddzielne plamy)
#define POKRYCIE_ZORZY 0.6        // [0.2 0.4 0.6 0.8 1.0] Grubosc samych fal zorzy wewnatrz tych skupisk
#define INTENSYWNOSC_ZORZY 0.5    // [0.1 0.3 0.5 0.8 1.0 1.5] Jasnosc zorzy
#define ZASIEG_ZORZY 0.4          // [0.2 0.4 0.6 0.8 1.0] Jak wysoko siega zorza na niebie
#define PREDKOSC_ZORZY 1.0        // [0.0 0.1 0.2 0.5 1.0 1.5 2.0] Predkosc animacji zorzy (0.0 = statyczna)
// ==========================================

uniform int worldTime; // Używamy czasu gry do animacji migania gwiazd i zorzy

varying vec4 glcolor;
varying vec3 starPos;

// Prosta matematyczna funkcja szumu do generowania losowych wartości
float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void main() {
    vec4 color = glcolor;

    // --- DETEKCJA GWIAZD ---
    // Gwiazdy w grze są renderowane jako białe/szare kwadraty.
    // Gradient nieba ma różne kolory, więc jeśli R == G == B, to na 99% patrzymy na gwiazdę.
    // Upewniamy się też, że kolor jest jaśniejszy niż 0.01 (żeby nie modyfikować czarnego nieba).
    bool isStar = (color.r == color.g && color.g == color.b && color.r > 0.01);
    
    if (isStar) {
        if (WLACZ_GWIAZDY) {
            // --- LOGIKA GWIAZD ---
            // 1. Unikalne ID dla prędkości i fazy migania
            float starId = hash(floor(starPos / 5.0)); 
            // 2. Unikalne ID dla "temperatury" (koloru) gwiazdy
            float starType = hash(floor(starPos / 5.0) + vec3(12.3, 4.5, 6.7)); 
            
            float time = float(worldTime) * 0.05;
            
            // Scyntylacja atmosferyczna (zależność od wysokości)
            float height = clamp(abs(starPos.y) / 50.0, 0.0, 1.0); 
            float speedMultiplier = mix(12.0, 4.0, height); 
            float maxBrightness = mix(3.5, 2.0, height); 
            float minBrightness = mix(0.05, 0.4, height);

            // Generujemy pulsowanie
            float twinkle = sin(time * (1.0 + starId * 2.0) + starId * speedMultiplier);
            twinkle = twinkle * 0.5 + 0.5; // Zakres 0.0 do 1.0
            
            // Obliczamy ostateczną jasność gwiazdy
            float brightness = mix(minBrightness, maxBrightness, twinkle);
            
            // Aplikujemy mnożnik z ustawień na górze pliku
            color.rgb *= brightness * INTENSYWNOSC_GWIAZD;

            // Temperatura gwiazd (Realistyczne kolory)
            if (brightness > 1.0) {
                if (starType < 0.2) {
                    // Błękitne olbrzymy
                    color.b *= 1.4;
                    color.g *= 1.1;
                } else if (starType > 0.85) {
                    // Czerwone karły
                    color.r *= 1.5;
                    color.g *= 0.9;
                    color.b *= 0.6;
                } else if (starType > 0.6) {
                    // Żółte karły
                    color.r *= 1.2;
                    color.g *= 1.1;
                    color.b *= 0.8;
                }
            }
        }
    } else {
        if (WLACZ_ZORZE) {
            // --- ZORZA POLARNA (Aurora Borealis) ---
            // Normalizujemy pozycję na niebie, aby otrzymać kierunek (od -1.0 do 1.0)
            vec3 dir = normalize(starPos);
            
            // Rysujemy zorzę tylko w górnej połowie nieba (nad horyzontem)
            if (dir.y > 0.0) {
                // Rzutowanie wektora 3D na płaską mapę 2D (aby uzyskać efekt sklepienia nad graczem)
                vec2 uv = dir.xz / (dir.y + 0.3); 
                
                // Czas pomnożony przez naszą nową zmienną z ustawień
                float time = float(worldTime) * 0.01 * PREDKOSC_ZORZY;
                
                // 1. Złożenie kilku fal sinus, aby utworzyć organiczny ruch kurtyn (szczegóły)
                float wave1 = sin(uv.x * 3.0 + time * 0.8 + sin(uv.y * 2.0 - time * 0.5));
                float wave2 = sin(uv.y * 2.0 - time * 0.6 + sin(uv.x * 2.5 + time * 0.4));
                float baseAurora = wave1 * wave2 * 0.5 + 0.5;
                
                // Wyostrzamy pasma na podstawie POKRYCIE_ZORZY
                float bands = pow(smoothstep(1.0 - POKRYCIE_ZORZY, 1.0, baseAurora), 3.0);
                
                // 2. Maska Skupisk (Odcina ogromne obszary nieba, zostawiając duże plamy)
                float clusterTime = time * 0.3; // Plamy poruszają się wolniej niż fale wewnątrz nich
                float zoneMask = sin(dir.x * 3.0 + clusterTime) * sin(dir.z * 3.0 - clusterTime * 0.8);
                zoneMask = zoneMask * 0.5 + 0.5; // Zakres 0.0 do 1.0
                // Docinamy plamy – im mniejsze SKUPIENIE_ZORZY, tym rzadsze skupiska
                zoneMask = smoothstep(1.0 - SKUPIENIE_ZORZY, 1.0, zoneMask);
                
                // 3. Kolorowanie
                // Gradient zorzy: zielona niżej, fioletowa/niebieskawa bliżej zenitu
                vec3 auroraColor = mix(vec3(0.0, 1.0, 0.4), vec3(0.3, 0.1, 0.8), dir.y);
                
                // 4. Maska wertykalna (Wysokość)
                float fadeUp = smoothstep(0.0, ZASIEG_ZORZY * 0.2, dir.y); // płynnie pojawia się od horyzontu
                float fadeDown = 1.0 - smoothstep(ZASIEG_ZORZY * 0.5, ZASIEG_ZORZY, dir.y); // płynnie znika na wysokości zasięgu
                float viewFade = fadeUp * fadeDown;
                
                // 5. System detekcji dnia/nocy
                float skyBrightness = dot(color.rgb, vec3(0.333));
                float nightFade = smoothstep(0.2, 0.02, skyBrightness); 
                
                // Mnożymy wszystko razem: fale * plamy(zoneMask) * wygaszanie krawędzi * noc
                color.rgb += auroraColor * bands * zoneMask * viewFade * nightFade * 2.0 * INTENSYWNOSC_ZORZY;
            }
        }
    }

    // Wyrzucamy gotowy kolor na ekran
    gl_FragData[0] = color;
}