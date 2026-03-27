#version 120

// Załączanie bibliotek modularnych
#include "/lib/math/noise.glsl"
#include "/lib/sky/clouds.glsl"
#include "/lib/sky/lightning.glsl"
#include "/lib/sky/weather_config.glsl"
#include "/lib/sky/sky_gradient.glsl"
#include "/lib/sky/fog.glsl"
#include "/lib/sky/stars.glsl"
#include "/lib/sky/aurora.glsl"

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 cameraPosition;

uniform float frameTimeCounter; 
uniform float thunderStrength;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 fogColor;

// Flagi efektów gracza i fizyki
uniform int isEyeInWater;
uniform float blindness;

varying vec2 texcoord;

void main() {
    vec2 uv = texcoord;
    
    vec3 color = texture2D(colortex0, uv).rgb;
    float depth = texture2D(depthtex0, uv).r;

    vec4 fragPosView = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
    fragPosView /= fragPosView.w;
    
    vec3 viewDir = normalize((gbufferModelViewInverse * vec4(fragPosView.xyz, 0.0)).xyz);
    
    vec4 terrainPos = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    terrainPos /= terrainPos.w;
    float terrainDist = length(terrainPos.xyz);

    vec3 sunDirWorld = normalize((gbufferModelViewInverse * vec4(normalize(sunPosition), 0.0)).xyz);

    float safeTime = mod(frameTimeCounter, 3600.0);
    float globalTime = mod(safeTime * 10.0, 1000.0) * 0.5 * GLOBAL_SPEED;

    // --- 3. RYSOWANIE NIEBA ---
    if (depth >= 1.0) {
        vec3 vanillaSky = color;
        vec3 customGradient = getSkyColor(viewDir, sunDirWorld, fogColor, rainStrength);
        
        color = customGradient + vanillaSky;
        
        float nightFactor = smoothstep(0.0, -0.2, sunDirWorld.y);
        if (nightFactor > 0.01) {
            float stars = getStars(viewDir, safeTime);
            color += stars * nightFactor * (1.0 - rainStrength);
        }

        if (nightFactor > 0.1) {
            vec3 aurora = getAurora(viewDir, safeTime, rainStrength);
            color += aurora * nightFactor * 0.5;
        }
    }

    // --- 4. RYSOWANIE BŁYSKAWIC ---
    float stormFactorForLightning = clamp(thunderStrength, 0.0, 1.0);
    float flashIntensity = getLightningFlash(safeTime, stormFactorForLightning);
    vec3 flashColor = vec3(0.65, 0.8, 1.0) * 8.0; 
    float timeSeed = floor(safeTime * 2.0 * LIGHTNING_FREQUENCY);
    float boltYaw = mix(-3.14159, 3.14159, hash1(timeSeed * 1.23)); 
    vec3 flashDir = normalize(vec3(sin(boltYaw), 0.4, cos(boltYaw)));

    if (depth >= 1.0 && flashIntensity > 0.01) {
        float boltAlpha = drawLightningBolt(viewDir, safeTime, stormFactorForLightning, boltYaw);
        color += flashColor * boltAlpha * 2.0; 
        
        float currentYaw = atan(viewDir.x, viewDir.z);
        float diffYaw = currentYaw - boltYaw;
        if (diffYaw > 3.14159) diffYaw -= 6.28318;
        if (diffYaw < -3.14159) diffYaw += 6.28318;
        
        float boltHalo = smoothstep(0.4, 0.0, abs(diffYaw)) * smoothstep(0.0, 0.5, viewDir.y);
        color += flashColor * boltHalo * flashIntensity * 0.3;
    }

    // --- 5. APLIKACJA MGŁY ATMOSFERYCZNEJ (LOD Support) ---
    // Aplikujemy mgłę tylko na bloki terenu i wodę (depth < 1.0)
    if (depth < 1.0) {
        color = applyAtmosphericFog(color, viewDir, terrainDist, sunDirWorld, rainStrength, fogColor, isEyeInWater, blindness);
    }

    // --- 6. RENDEROWANIE CHMUR ---
    if (abs(viewDir.y) > 0.001) {
        float safeViewY = sign(viewDir.y) * max(abs(viewDir.y), 0.001);
        
        float tHigh = (HEIGHT_HIGH - cameraPosition.y) / safeViewY;
        float tMid = (HEIGHT_MID - cameraPosition.y) / safeViewY;
        float tLow = (HEIGHT_LOW - cameraPosition.y) / safeViewY;

        float lowDensity = mix(0.55, 0.25, rainStrength);
        vec3 lowColor = mix(vec3(1.0, 1.0, 1.0), vec3(0.15, 0.18, 0.22), rainStrength); 
        float lowAlpha = mix(0.95, 1.0, rainStrength);

        float midDensity = mix(0.53, 0.35, rainStrength);
        vec3 midColor = mix(vec3(0.95, 0.95, 0.98), vec3(0.25, 0.28, 0.32), rainStrength);

        float highDensity = mix(0.50, 0.40, rainStrength);
        vec3 highColor = vec3(1.0, 1.0, 1.0);

        float sunDot = max(0.0, dot(viewDir, sunDirWorld));
        vec3 directionalGlow = mix(vec3(1.0), fogColor * 1.8, pow(sunDot, 3.0) * 0.9);
        float ambientLight = clamp(length(fogColor), 0.08, 1.0);
        vec3 globalLighting = directionalGlow * ambientLight;

        if (flashIntensity > 0.01) {
            float cloudFlashDot = max(0.0, dot(viewDir, flashDir));
            float localFlashGlow = pow(cloudFlashDot, 2.0) * 2.0 + 0.3; 
            globalLighting += flashColor * flashIntensity * localFlashGlow;
        }

        vec3 cLow = lowColor * globalLighting;
        vec3 cMid = midColor * globalLighting;
        vec3 cHigh = highColor * globalLighting;

        if (viewDir.y > 0.0) {
            #ifdef ENABLE_HIGH_CLOUDS
            vec4 highLayer = getCloudLayer(tHigh, BLOCK_SIZE_HIGH, vec2(0.0005, 0.002), highDensity, 0.5 + rainStrength, cHigh, 0.60, viewDir, terrainDist, depth, globalTime, cameraPosition);
            color = mix(color, highLayer.rgb, highLayer.a);
            #endif
            
            #ifdef ENABLE_MID_CLOUDS
            vec4 midLayer = getCloudLayer(tMid, BLOCK_SIZE_MID, vec2(0.003, 0.003), midDensity, 1.0 + rainStrength, cMid, 0.85, viewDir, terrainDist, depth, globalTime, cameraPosition);
            color = mix(color, midLayer.rgb, midLayer.a);
            #endif
            
            #ifdef ENABLE_LOW_CLOUDS
            vec4 lowLayer = getCloudLayer(tLow, BLOCK_SIZE_LOW, vec2(0.004, 0.004), lowDensity, 1.5 + rainStrength * 2.0, cLow, lowAlpha, viewDir, terrainDist, depth, globalTime, cameraPosition);
            color = mix(color, lowLayer.rgb, lowLayer.a);
            #endif
        } else {
            #ifdef ENABLE_LOW_CLOUDS
            vec4 lowLayer = getCloudLayer(tLow, BLOCK_SIZE_LOW, vec2(0.004, 0.004), lowDensity, 1.5 + rainStrength * 2.0, cLow, lowAlpha, viewDir, terrainDist, depth, globalTime, cameraPosition);
            color = mix(color, lowLayer.rgb, lowLayer.a);
            #endif
            
            #ifdef ENABLE_MID_CLOUDS
            vec4 midLayer = getCloudLayer(tMid, BLOCK_SIZE_MID, vec2(0.003, 0.003), midDensity, 1.0 + rainStrength, cMid, 0.85, viewDir, terrainDist, depth, globalTime, cameraPosition);
            color = mix(color, midLayer.rgb, midLayer.a);
            #endif
            
            #ifdef ENABLE_HIGH_CLOUDS
            vec4 highLayer = getCloudLayer(tHigh, BLOCK_SIZE_HIGH, vec2(0.0005, 0.002), highDensity, 0.5 + rainStrength, cHigh, 0.60, viewDir, terrainDist, depth, globalTime, cameraPosition);
            color = mix(color, highLayer.rgb, highLayer.a);
            #endif
        }
    }

    gl_FragData[0] = vec4(color, 1.0);
}