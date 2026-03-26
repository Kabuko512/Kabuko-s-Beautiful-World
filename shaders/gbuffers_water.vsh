#version 120

#include "/lib/materials/fluid_waves.glsl"

#define WATER_STYLE 2 // [0 1 2]

attribute vec4 mc_Entity;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

varying vec2 texcoord;
varying vec2 lmcoord; // NOWE: Przekazywanie współrzędnych światłocienia (Lightmap)
varying vec4 glColor;
varying vec3 normal;

#define WATER_WAVE_SPEED 1.5
#define WATER_WAVE_AMPLITUDE 0.15
#define WATER_WAVE_SCALE 1.2

void main() {
    texcoord = gl_MultiTexCoord0.st;
    
    // Pobranie koordynatów jasności (jak jasno jest od słońca i pochodni)
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    
    glColor = gl_Color;
    normal = gl_NormalMatrix * gl_Normal;
    
    int blockId = int(mc_Entity.x + 0.5);
    
    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    vec3 worldPos = (gbufferModelViewInverse * position).xyz + cameraPosition;
    
    if (normal.y > 0.5 && blockId == 100) {
        #if WATER_STYLE == 1
            position.y += sin(worldPos.x * WATER_WAVE_SCALE + frameTimeCounter * WATER_WAVE_SPEED) * WATER_WAVE_AMPLITUDE;
            
        #elif WATER_STYLE == 2
            vec3 waveOffset = calculateFluidWaves(worldPos, WATER_WAVE_SPEED, WATER_WAVE_AMPLITUDE, WATER_WAVE_SCALE, frameTimeCounter);
            position.y += waveOffset.y;
        #endif
    }
    
    // Wbudowana w silnik zmienna odległości, potrzebna do przeliczenia mgły
    gl_FogFragCoord = length(position.xyz);
    
    gl_Position = gl_ProjectionMatrix * position;
}