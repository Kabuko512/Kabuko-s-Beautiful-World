#version 120

// Wczytujemy naszą bibliotekę świateł
#include "/lib/materials/lighting.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glColor;

void main() {
    // 1. Kolor bloku (i ew. zablokowane waniliowe Ambient Occlusion w glColor)
    vec4 color = texture2D(texture, texcoord) * glColor;
    
    // 2. NOWE, MIESISTE OŚWIETLENIE Z NASZEJ FUNKCJI!
    vec3 lightColor = getCustomLighting(lightmap, lmcoord);
    
    color.rgb *= lightColor;

    gl_FragData[0] = color;
}