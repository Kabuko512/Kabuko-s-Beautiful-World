#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glColor;

void main() {
    // 1. Pobranie tekstury bloku (ziemi, kamienia, lawy itp.)
    vec4 color = texture2D(texture, texcoord) * glColor;
    
    // 2. APLIKACJA ŚWIATŁOCIENIA
    // Lawa naturalnie ignoruje mrok i świeci sama z siebie - Vanilla lightmap świetnie to obsługuje,
    // więc nie musimy pisać osobnej logiki świecenia. Po prostu mnożymy przez światło.
    vec3 lightColor = texture2D(lightmap, lmcoord).rgb;
    color.rgb *= lightColor;

    // 3. MGŁA VANILLA (Dla zgrania z horyzontem / Voxy)
    float fogFactor = (gl_Fog.end - gl_FogFragCoord) / (gl_Fog.end - gl_Fog.start);
    fogFactor = clamp(fogFactor, 0.0, 1.0);
    color.rgb = mix(gl_Fog.color.rgb, color.rgb, fogFactor);

    // 4. Wyrzucenie na ekran
    gl_FragData[0] = color;
}