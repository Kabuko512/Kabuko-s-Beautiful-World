#version 120

uniform sampler2D texture;
uniform sampler2D lightmap; 

uniform vec3 skyColor;
uniform float rainStrength; // Dodane: pobiera moc deszczu

varying vec2 texcoord;
varying vec2 lmcoord;       
varying vec4 glcolor;

varying vec3 normal;
varying vec3 viewVector;
varying float isEndStone;

// --- DODANE DLA EFEKTU MOKRYCH POWIERZCHNI ---
varying vec3 vWorldPos;
varying vec3 worldNormal;

void main() {
    // Nałożenie tekstury bloku
    vec4 color = texture2D(texture, texcoord) * glcolor;
    vec4 light = texture2D(lightmap, lmcoord);
    
    // Zapobiega przezroczystości
    if (color.a < 0.1) {
        discard;
    }
    
    // ========================================================
    // EFEKT MOKRYCH POWIERZCHNI I KAŁUŻ (Fake Wetness)
    // ========================================================
    // Aktywuje się tylko podczas deszczu. 
    // worldNormal.y > 0.5 oznacza, że patrzymy na PŁASKĄ powierzchnię do góry (podłogę/trawę).
    // lmcoord.t > 0.85 oznacza, że padają na nią bezpośrednie promienie (światło) ze skyboxa - jest "pod gołym niebem".
    if (rainStrength > 0.01 && worldNormal.y > 0.5 && lmcoord.t > 0.85) {
        
        // 1. Tani generator geometrycznych kałuż (bazujący na ułożeniu świata, super tani)
        float wx = vWorldPos.x;
        float wz = vWorldPos.z;
        float noise = sin(wx * 0.8) * cos(wz * 0.8) + sin(wx * 0.2 + wz * 0.5);
        // Przekładamy hałas na mapę od 0.0 (suche) do 1.0 (głębokie kałuże)
        float puddle = smoothstep(0.0, 0.9, noise * 0.5 + 0.5);

        // Nawet bez głębokiej kałuży wszystko jest lekko mokre i lśniące (min. 0.3 mokrości)
        float wetness = rainStrength * mix(0.3, 1.0, puddle);

        // 2. Fizyka światła materiału (woda wnika w drewno/kamień i je przyciemnia)
        color.rgb *= mix(1.0, 0.55, wetness);

        // 3. Fake'owe Odbicie Nieba (Efekt Fresnela)
        vec3 n = normalize(normal);
        vec3 v = normalize(viewVector);
        // Odbicia są najsilniejsze na płaskich kątach względem kamery
        float fresnel = pow(clamp(1.0 - dot(n, v), 0.0, 1.0), 3.0);

        // Definiujemy szaro-bure światło od deszczowego nieba
        vec3 skyReflection = vec3(0.6, 0.65, 0.7);
        // W nocy niebo jest ciemne, więc mnożymy odbicie przez światło słońca/księżyca (light.g to zielony kanał światła dziennego)
        skyReflection *= light.g;

        // 4. Dodajemy lśniące krawędzie kałuż na wierzch koloru!
        color.rgb += skyReflection * fresnel * wetness * 1.5;
    }

    // ========================================================
    // EFEKT 5: KOSMICZNY POŁYSK END STONE'U (Astral Reflection)
    // ========================================================
    if (isEndStone > 0.5 && length(skyColor) < 0.001) {
        vec3 n = normalize(normal);
        vec3 v = normalize(viewVector);
        float fresnel = pow(1.0 - max(dot(n, v), 0.0), 3.0);
        vec3 astralGlow = vec3(0.5, 0.2, 0.9);
        color.rgb += astralGlow * fresnel * 0.7;
    }
    
    // Ostateczny wynik mnożymy przez światło i wychodzimy na ekran
    gl_FragColor = color * light;
}