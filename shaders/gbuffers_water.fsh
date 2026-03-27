#version 120

// Wczytujemy naszą bibliotekę świateł
#include "/lib/materials/lighting.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glColor;

void main() {
    vec4 color = texture2D(texture, texcoord) * glColor;
    
    // Używamy naszego kinowego światła!
    vec3 lightColor = getCustomLighting(lightmap, lmcoord);
    
    color.rgb *= lightColor;

    gl_FragData[0] = color;
}