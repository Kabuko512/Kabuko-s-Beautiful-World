#version 120

// Wczytujemy naszą bibliotekę świateł
#include "/lib/materials/lighting.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;

uniform vec4 entityColor;

varying vec4 color;
varying vec2 coord0;
varying vec2 coord1; // To jest to samo co lmcoord, inna nazwa

void main() {
    // Aplikujemy nasze światło na owce, zombie i latające bloki!
    vec3 light = getCustomLighting(lightmap, coord1);
    
    vec4 col = color * vec4(light, 1.0) * texture2D(texture, coord0);
    
    // Kolor otrzymywanych obrażeń u mobów
    col.rgb = mix(col.rgb, entityColor.rgb, entityColor.a);

    gl_FragData[0] = col;
}