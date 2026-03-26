#version 120

// Wykorzystujemy tę samą bibliotekę co przy wodzie!
#include "/lib/materials/fluid_waves.glsl"

#define LAVA_STYLE 2 // [0 1 2]

attribute vec4 mc_Entity;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glColor;
varying vec3 normal;

// Ustawienia dla Lawy: Gęstsza ciecz = wolniejsze i mniejsze fale
#define LAVA_WAVE_SPEED 0.4
#define LAVA_WAVE_AMPLITUDE 0.08
#define LAVA_WAVE_SCALE 0.8

void main() {
    texcoord = gl_MultiTexCoord0.st;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glColor = gl_Color;
    normal = gl_NormalMatrix * gl_Normal;
    
    int blockId = int(mc_Entity.x + 0.5);
    
    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    vec3 worldPos = (gbufferModelViewInverse * position).xyz + cameraPosition;
    
    // ID 10 to statyczna lawa (podzieliliśmy to wcześniej w block.properties)
    if (normal.y > 0.5 && blockId == 10) {
        #if LAVA_STYLE == 1
            position.y += sin(worldPos.x * LAVA_WAVE_SCALE + frameTimeCounter * LAVA_WAVE_SPEED) * LAVA_WAVE_AMPLITUDE;
            
        #elif LAVA_STYLE == 2
            vec3 waveOffset = calculateFluidWaves(worldPos, LAVA_WAVE_SPEED, LAVA_WAVE_AMPLITUDE, LAVA_WAVE_SCALE, frameTimeCounter);
            position.y += waveOffset.y;
        #endif
    }
    
    gl_FogFragCoord = length(position.xyz);
    
    gl_Position = gl_ProjectionMatrix * position;
}