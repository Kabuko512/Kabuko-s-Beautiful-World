#version 120

uniform sampler2D texture;
uniform sampler2D lightmap; // NOWE: Tekstura oryginalnego oświetlenia Minecrafta

varying vec2 texcoord;
varying vec2 lmcoord; // Otrzymane z pliku vsh
varying vec4 glColor;

void main() {
    // 1. Podstawowy kolor tekstury połączony z barwą biomu (np. bagnisty lub oceaniczny kolor)
    vec4 color = texture2D(texture, texcoord) * glColor;
    
    // 2. APLIKACJA ŚWIATŁOCIENIA (Lightmap)
    // Bez tego woda ignoruje porę dnia i cień od chmur/deszczu, przez co wyglądała na jasną (neonową)
    vec3 lightColor = texture2D(lightmap, lmcoord).rgb;
    color.rgb *= lightColor;

    // 3. APLIKACJA ORYGINALNEJ MGŁY (Dla zgrania się z Voxy)
    // Voxy nakłada na dalekie bloki mgłę. Jeśli my tego nie zrobimy na naszych blokach, 
    // powstanie ostre odcięcie. Obliczamy tu standardową "waniliową" mgłę Minecrafta.
    float fogFactor = (gl_Fog.end - gl_FogFragCoord) / (gl_Fog.end - gl_Fog.start);
    fogFactor = clamp(fogFactor, 0.0, 1.0);
    
    // Nakładamy kolor mgły (szary/niebieski w trakcie deszczu)
    color.rgb = mix(gl_Fog.color.rgb, color.rgb, fogFactor);

    // 4. Wyrzucenie finalnego koloru na ekran
    gl_FragData[0] = color;
}