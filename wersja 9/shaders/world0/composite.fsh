#version 120

// --- USTAWIENIA CHMUR WIELOWARSTWOWYCH ---
#define ENABLE_HIGH_CLOUDS   
#define ENABLE_MID_CLOUDS    
#define ENABLE_LOW_CLOUDS    

#define HEIGHT_HIGH 350.0 // [200.0 250.0 300.0 350.0 400.0 450.0]
#define HEIGHT_MID 220.0  // [150.0 180.0 220.0 250.0 280.0]
#define HEIGHT_LOW 120.0  // [80.0 100.0 120.0 150.0 180.0]

#define BLOCK_SIZE_HIGH 32.0 // [8.0 16.0 32.0 64.0]
#define BLOCK_SIZE_MID 16.0  // [8.0 16.0 32.0 64.0]
#define BLOCK_SIZE_LOW 16.0  // [8.0 16.0 32.0 64.0]

#define GLOBAL_SPEED 1.0     // [0.1 0.5 1.0 1.5 2.0 3.0]
#define Z_FIGHTING_BIAS 0.2  

// --- NOWE USTAWIENIA DRAMATYZMU POGODY ---
// Jak bardzo kolory blakną w czasie burzy (0.0 - 1.0)
#define WEATHER_DESATURATION 0.6 // [0.0 0.2 0.4 0.6 0.8 1.0]
// Siła przyciemnienia brzegów w czasie deszczu (0.0 - 1.0)
#define WEATHER_VIGNETTE 0.5     // [0.0 0.2 0.5 0.8 1.0]
// Mnożnik dystansu mgły w deszczu (0.4 = 40% widoczności)
#define FOG_DENSITY_RAIN 0.4     // [0.1 0.2 0.4 0.6 0.8 1.0]
// Mnożnik dystansu mgły w burzy (0.15 = 15% widoczności)
#define FOG_DENSITY_THUNDER 0.15 // [0.05 0.1 0.15 0.2 0.3 0.5]
// Częstotliwość piorunów 
#define LIGHTNING_FREQUENCY 1.0 // [0.5 1.0 2.0 5.0 10.0]

// --- USTAWIENIA NIEBA I HORYZONTU ---
#define SUN_HALO_INTENSITY 1.0  // [0.0 0.5 1.0 1.5 2.0 3.0]

// --- USTAWIENIA ZORZY POLARNEJ ---
#define ENABLE_AURORA           
#define AURORA_SIZE 1.0         // [0.5 1.0 1.5 2.0]
#define AURORA_INTENSITY 1.0    // [0.0 0.5 1.0 1.5 2.0 3.0]

// --- USTAWIENIA PIKSELIZACJI CAŁEGO EKRANU (GLOBAL) ---
// 0 = Wyłączone (działa odległość), 1 = Cały ekran spikselowany na stałe
#define GLOBAL_PIXELATION_MODE 0 // [0 1]
#define GLOBAL_PIXEL_SIZE 4.0 // [2.0 3.0 4.0 6.0 8.0 16.0]

// --- USTAWIENIA PIKSELIZACJI ODLEGŁOŚCI (DISTANT PIXELATION) ---
#define ENABLE_DISTANCE_PIXELATION

// Od ilu kratek zaczyna się pikselizacja
#define DISTANCE_PIXEL_START 48.0 // [24.0 48.0 90.0 128.0]

// Dystans maksymalnego piksela (Zwiększ do 1024/2048 jeśli używasz Distant Horizons)
#define DISTANCE_PIXEL_MAX_DIST 512.0 // [256.0 512.0 1024.0 2048.0 4096.0]

// Wielkość klocka na horyzoncie w pikselach ekranu
#define DISTANCE_PIXEL_MAX_SIZE 12.0 // [2.0 4.0 8.0 12.0 16.0]

// --- USTAWIENIA PIKSELIZACJI (MINECRAFT STYLE) ---
// Mniejsza wartość = grubsze, bardziej kanciaste zygzaki piorunów
#define LIGHTNING_PIXELATION 40.0 // [10.0 20.0 40.0 80.0]
// Mniejsza wartość = większe, wyraźniejsze "bloki" zorzy na niebie
#define AURORA_PIXELATION 18.0 // [8.0 18.0 32.0 64.0]
// 0 = gładkie przejścia kolorów zorzy, 1 = twarde kolory zorzy
#define PIXELATE_AURORA_COLORS 1 // [0 1]

// --- USTAWIENIA LOD ---
#define AUTO_LOD_DETECTION      

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

// Oficjalne zmienne dla Distant Horizons (Iris)
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform mat4 dhProjectionInverse;
#endif

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 cameraPosition;

uniform float frameTimeCounter; 
uniform float rainStrength;
uniform float thunderStrength; 
uniform vec3 sunPosition; 
uniform vec3 fogColor;    
uniform float far; 
uniform int worldId;
uniform int isEyeInWater; 

uniform float viewWidth;  
uniform float viewHeight; 

varying vec2 texcoord;

// --- FUNKCJE SZUMU I POGODY ---

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise1D(float p) {
    float fl = floor(p);
    float fc = fract(p);
    return mix(hash1(fl), hash1(fl + 1.0), fc);
}

float customNoise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i + vec2(0.0, 0.0)), hash2(i + vec2(1.0, 0.0)), u.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm2(vec2 p) {
    float f = 0.0;
    f += 0.5000 * customNoise2D(p); p = p * 2.02;
    f += 0.2500 * customNoise2D(p); p = p * 2.03;
    f += 0.1250 * customNoise2D(p);
    return f;
}

// --- FUNKCJE BŁYSKAWIC ---

float getLightningFlash(float time, float stormStrength) {
    if (stormStrength < 0.01) return 0.0;
    
    float noiseTime = time * LIGHTNING_FREQUENCY;
    float flashNoise = noise1D(noiseTime * 2.0) * noise1D(noiseTime * 1.0);
    float flash = step(0.85, flashNoise);
    
    float afterglow = smoothstep(0.4, 0.85, flashNoise) * 0.8;
    return max(flash, afterglow) * stormStrength;
}

float drawLightningBolt(vec3 viewDir, float time, float stormStrength, float boltYaw) {
    if (stormStrength < 0.01) return 0.0;
    
    float timeSeed = floor(time * 2.0 * LIGHTNING_FREQUENCY); 
    
    float currentYaw = atan(viewDir.x, viewDir.z);
    float diffYaw = currentYaw - boltYaw;
    if (diffYaw > 3.14159) diffYaw -= 6.28318;
    if (diffYaw < -3.14159) diffYaw += 6.28318;
    
    float steppedY = floor(viewDir.y * LIGHTNING_PIXELATION) / LIGHTNING_PIXELATION;
    
    float path = fbm2(vec2(steppedY * 10.0, timeSeed)) * 0.1;
    path += sin(steppedY * 15.0) * 0.02;
    
    float dist = abs(diffYaw - path);
    float bolt = step(dist, 0.005); 
    bolt *= smoothstep(0.05, 0.2, viewDir.y); 
    
    return bolt;
}

// --- WARSTWY CHMUR ---

void applyLayer(float t, float blockSize, vec2 scale, float density, float speedMult, vec3 baseColor, float maxAlpha, inout vec3 currentColor, vec3 viewDir, float terrainDist, float depth, float globalTime) {
    if (t <= 0.0 || (depth < 0.99999 && t > terrainDist - Z_FIGHTING_BIAS)) return;
    vec3 hitPos = cameraPosition + viewDir * t;
    vec2 calcPos = floor(hitPos.xz / blockSize) * blockSize;
    calcPos.x += globalTime * speedMult;
    float val = fbm2(calcPos * scale);
    if (val > density) {
        vec3 cColor = baseColor;
        float edgeCheck = fbm2((calcPos + vec2(blockSize)) * scale);
        if (edgeCheck < density + 0.02) {
            cColor *= 0.85; 
        }
        float fogFactor = exp(-t * 0.0006); 
        float finalAlpha = clamp(fogFactor, 0.0, 1.0) * maxAlpha;
        currentColor = mix(currentColor, cColor, finalAlpha);
    }
}

void main() {
    float safeTime = mod(frameTimeCounter, 3600.0);

    vec2 uv = texcoord;
    if (isEyeInWater == 1) {
        uv.x += sin(uv.y * 15.0 + safeTime * 3.0) * 0.005;
        uv.y += cos(uv.x * 15.0 + safeTime * 2.5) * 0.005;
    }

    // --- SYSTEM PIKSELIZACJI ODLEGŁOŚCI / GLOBALNEJ ---
    vec2 finalUV = uv;
    
    #if GLOBAL_PIXELATION_MODE == 1
        // Opcja 1: Cały ekran jest twardo spikselowany
        vec2 res = vec2(viewWidth, viewHeight);
        finalUV = floor(uv * res / GLOBAL_PIXEL_SIZE) * GLOBAL_PIXEL_SIZE / res;
        finalUV += (GLOBAL_PIXEL_SIZE * 0.5) / res; 
    #else
        // Opcja 2: Pikselizacja oparta na odległości (wsparcie DH / VOXY)
        #ifdef ENABLE_DISTANCE_PIXELATION
            float initialDepth = texture2D(depthtex0, uv).r;
            float distForPix = -1.0;
            
            if (initialDepth < 0.99999) { 
                vec4 initialPos = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, initialDepth * 2.0 - 1.0, 1.0);
                initialPos /= initialPos.w;
                distForPix = length(initialPos.xyz);
            } 
            #ifdef DISTANT_HORIZONS
            else {
                float dhDepth = texture2D(dhDepthTex, uv).r;
                if (dhDepth < 0.99999) {
                    vec4 initialPos = dhProjectionInverse * vec4(uv * 2.0 - 1.0, dhDepth * 2.0 - 1.0, 1.0);
                    initialPos /= initialPos.w;
                    distForPix = length(initialPos.xyz);
                    initialDepth = dhDepth; 
                }
            }
            #endif

            if (distForPix < 0.0) {
                distForPix = DISTANCE_PIXEL_MAX_DIST;
            }

            if (distForPix >= 0.0) {
                if (distForPix > DISTANCE_PIXEL_START) {
                    float factor = (distForPix - DISTANCE_PIXEL_START) / (DISTANCE_PIXEL_MAX_DIST - DISTANCE_PIXEL_START);
                    factor = clamp(factor, 0.0, 1.0);
                    
                    float pixelSize = mix(1.0, DISTANCE_PIXEL_MAX_SIZE, factor * factor); 
                    
                    if (pixelSize > 1.0) {
                    vec2 res = vec2(viewWidth, viewHeight);
                    finalUV = floor(uv * res / pixelSize) * pixelSize / res;
                    finalUV += (pixelSize * 0.5) / res; 
                }
            }
        }
        #endif
    #endif

    // Wczytujemy finalny, "rozmazany/spikselowany" kolor oraz głębię
    vec3 color = texture2D(colortex0, finalUV).rgb;
    float depth = texture2D(depthtex0, finalUV).r;

    #if GLOBAL_PIXELATION_MODE == 0
        #ifdef ENABLE_DISTANCE_PIXELATION
            // Ochrona Edge-Bleed aktywowana tylko dla trybu odległości.
            // (Dla trybu globalnego niepotrzebna, tam twarde krawędzie są oczekiwane)
            if (distForPix >= 0.0 && depth >= 0.99999) {
                depth = initialDepth; 
            }
        #endif
    #endif

    if (worldId != 0) {
        gl_FragColor = vec4(color, 1.0);
        return; 
    }
       
    vec3 sunDirView = normalize(sunPosition);
    vec3 sunDirWorld = normalize((gbufferModelViewInverse * vec4(sunDirView, 0.0)).xyz);
    
    vec4 fragPosView = gbufferProjectionInverse * vec4(finalUV * 2.0 - 1.0, 1.0, 1.0);
    fragPosView /= fragPosView.w;
    vec3 viewSpaceDir = normalize(fragPosView.xyz); 
    vec3 viewDir = normalize((gbufferModelViewInverse * fragPosView).xyz); 
    
    vec4 terrainPos = gbufferProjectionInverse * vec4(finalUV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    terrainPos /= terrainPos.w;
    float terrainDist = length(terrainPos.xyz);

    float weatherFactor = 1.0;
    float totalStorm = clamp(rainStrength + thunderStrength, 0.0, 1.0);
    
    float stormFactorForLightning = clamp(thunderStrength, 0.0, 1.0);

    float flashIntensity = getLightningFlash(safeTime, stormFactorForLightning);
    vec3 flashColor = vec3(0.65, 0.8, 1.0) * 8.0; 

    float timeSeed = floor(safeTime * 2.0 * LIGHTNING_FREQUENCY);
    float boltYaw = mix(-3.14159, 3.14159, hash1(timeSeed * 1.23)); 
    
    vec3 flashDir = normalize(vec3(sin(boltYaw), 0.4, cos(boltYaw)));

    float weatherVisibility = mix(1.0, FOG_DENSITY_RAIN, rainStrength);
    weatherVisibility = mix(weatherVisibility, FOG_DENSITY_THUNDER, thunderStrength);

    if (depth < 0.99999) {
        bool disableFog = false;
        #ifdef FORCE_DISABLE_FOG
            disableFog = true;
        #endif
        #ifdef AUTO_LOD_DETECTION
            #ifdef DISTANT_HORIZONS
                disableFog = true;
            #endif
            #ifdef VOXY
                disableFog = true;
            #endif
        #endif

        if (!disableFog) {
            float customFogStart = far * 0.4 * weatherVisibility; 
            float customFogEnd = far * weatherVisibility;
            
            float fogFactor = (customFogEnd - terrainDist) / (customFogEnd - customFogStart);
            fogFactor = clamp(fogFactor, 0.0, 1.0);
            
            if (rainStrength > 0.1) {
                float expFog = 1.0 - exp(-terrainDist * (0.005 + rainStrength * 0.01 + thunderStrength * 0.02));
                fogFactor = min(fogFactor, 1.0 - expFog);
            }
            color = mix(fogColor, color, fogFactor); 
        }
    }

    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(color, vec3(gray), totalStorm * WEATHER_DESATURATION);

    float distToCenter = distance(finalUV, vec2(0.5));
    float vignette = smoothstep(0.8, 0.2 - (totalStorm * 0.1), distToCenter);
    color *= mix(1.0, vignette, totalStorm * WEATHER_VIGNETTE);

    float globalTime = mod(safeTime * 10.0, 1000.0) * 0.5 * GLOBAL_SPEED;

    if (depth >= 0.99999) {
        vec3 sunUp = vec3(0.0, 1.0, 0.0);
        if (abs(sunDirView.y) > 0.99) sunUp = vec3(1.0, 0.0, 0.0); 
        vec3 sunRight = normalize(cross(sunDirView, sunUp));
        sunUp = normalize(cross(sunRight, sunDirView));
        
        float dx = dot(viewSpaceDir, sunRight);
        float dy = dot(viewSpaceDir, sunUp);
        float maxDist = max(abs(dx), abs(dy));
        float squareDot = max(0.0, 1.0 - maxDist * 1.2); 
        
        float dayFactor = smoothstep(-0.1, 0.2, sunDirWorld.y);
        float sunWeatherFactor = 1.0 - rainStrength * 0.95; 
        
        vec3 sunScatter = vec3(0.8, 0.85, 0.9) * pow(squareDot, 10.0) * 0.4;
        vec3 sunGlow = vec3(1.0, 0.9, 0.7) * pow(squareDot, 45.0) * 0.8;
        
        color += (sunGlow + sunScatter) * dayFactor * sunWeatherFactor * SUN_HALO_INTENSITY;

        if (sunDirWorld.y < -0.05) {
            float nightFactor = smoothstep(-0.05, -0.2, sunDirWorld.y);
            float clearWeather = 1.0 - rainStrength;
            if (clearWeather > 0.0) {
                #ifdef ENABLE_AURORA
                if (viewDir.y > 0.05) {
                    vec2 p = viewDir.xz / max(viewDir.y, 0.001);
                    p *= (1.0 / AURORA_SIZE);
                    
                    vec2 calcPos = p;
                    calcPos.x += globalTime * 0.02; 
                    calcPos = floor(calcPos * AURORA_PIXELATION) / AURORA_PIXELATION;
                    
                    float wave = sin(calcPos.x * 1.5 + globalTime * 0.1) * 0.2;
                    calcPos.y += wave;
                    
                    float n1_aur = fbm2(calcPos * 1.2);
                    float n2_aur = fbm2(calcPos * vec2(2.5, 1.0) + vec2(globalTime * 0.08, globalTime * 0.03));
                    
                    #if PIXELATE_AURORA_COLORS == 1
                        float auroraVal = step(0.48, n1_aur * n2_aur);
                        vec3 col1_aur = vec3(0.1, 0.9, 0.5); 
                        vec3 col2_aur = vec3(0.5, 0.2, 0.9); 
                        vec3 auroraCol = mix(col1_aur, col2_aur, step(0.5, n2_aur));
                    #else
                        float auroraVal = smoothstep(0.4, 0.7, n1_aur * n2_aur);
                        vec3 col1_aur = vec3(0.1, 0.9, 0.5); 
                        vec3 col2_aur = vec3(0.5, 0.2, 0.9); 
                        vec3 auroraCol = mix(col1_aur, col2_aur, n2_aur);
                    #endif
                    
                    float auroraFade = smoothstep(0.05, 0.2, viewDir.y) * smoothstep(0.9, 0.4, viewDir.y);
                    color += auroraCol * auroraVal * auroraFade * nightFactor * clearWeather * 1.5 * AURORA_INTENSITY;
                }
                #endif
            }
        }
        
        if (flashIntensity > 0.01) {
            float boltAlpha = drawLightningBolt(viewDir, safeTime, stormFactorForLightning, boltYaw);
            color += flashColor * boltAlpha * 2.0; 
            
            float currentYaw = atan(viewDir.x, viewDir.z);
            float diffYaw = currentYaw - boltYaw;
            if (diffYaw > 3.14159) diffYaw -= 6.28318;
            if (diffYaw < -3.14159) diffYaw += 6.28318;
            
            float boltHalo = smoothstep(0.4, 0.0, abs(diffYaw)) * smoothstep(0.0, 0.5, viewDir.y);
            color += flashColor * boltHalo * flashIntensity * 0.3;
        }
    }

    if (abs(viewDir.y) > 0.001) {
        float safeViewY = sign(viewDir.y) * max(abs(viewDir.y), 0.001);
        float tHigh = (HEIGHT_HIGH - cameraPosition.y) / safeViewY;
        float tMid = (HEIGHT_MID - cameraPosition.y) / safeViewY;
        float tLow = (HEIGHT_LOW - cameraPosition.y) / safeViewY;

        float lowDensity = mix(0.55, 0.25, rainStrength); 
        vec3 lowColor = mix(vec3(1.0, 1.0, 1.0), vec3(0.15, 0.18, 0.22), rainStrength); 
        float lowSpeed = 1.5 + rainStrength * 3.0;
        float lowAlpha = mix(0.95, 1.0, rainStrength);

        float midDensity = mix(0.53, 0.35, rainStrength);
        vec3 midColor = mix(vec3(0.95, 0.95, 0.98), vec3(0.25, 0.28, 0.32), rainStrength);
        float midSpeed = 1.0 + rainStrength * 2.0;
        float midAlpha = 0.85;

        float highDensity = mix(0.50, 0.40, rainStrength);
        vec3 highColor = vec3(1.0, 1.0, 1.0);
        float highSpeed = 0.5 + rainStrength * 1.5;
        float highAlpha = 0.60;

        float sunDot = max(0.0, dot(viewDir, sunDirWorld));
        vec3 directionalGlow = mix(vec3(1.0), fogColor * 1.8, pow(sunDot, 3.0) * 0.9);
        float ambientLight = clamp(length(fogColor), 0.08, 1.0); 
        vec3 globalLighting = directionalGlow * ambientLight;

        if (flashIntensity > 0.01) {
            float cloudFlashDot = max(0.0, dot(viewDir, flashDir));
            float localFlashGlow = pow(cloudFlashDot, 2.0) * 2.0 + 0.3; 
            globalLighting += flashColor * flashIntensity * localFlashGlow;
        }

        lowColor *= globalLighting;
        midColor *= globalLighting;
        highColor *= globalLighting;

        if (viewDir.y > 0.0) {
            #ifdef ENABLE_HIGH_CLOUDS
            applyLayer(tHigh, BLOCK_SIZE_HIGH, vec2(0.0005, 0.002), highDensity, highSpeed, highColor, highAlpha, color, viewDir, terrainDist, depth, globalTime);
            #endif
            #ifdef ENABLE_MID_CLOUDS
            applyLayer(tMid, BLOCK_SIZE_MID, vec2(0.003, 0.003), midDensity, midSpeed, midColor, midAlpha, color, viewDir, terrainDist, depth, globalTime);
            #endif
            #ifdef ENABLE_LOW_CLOUDS
            applyLayer(tLow, BLOCK_SIZE_LOW, vec2(0.004, 0.004), lowDensity, lowSpeed, lowColor, lowAlpha, color, viewDir, terrainDist, depth, globalTime);
            #endif
        } else {
            #ifdef ENABLE_LOW_CLOUDS
            applyLayer(tLow, BLOCK_SIZE_LOW, vec2(0.004, 0.004), lowDensity, lowSpeed, lowColor, lowAlpha, color, viewDir, terrainDist, depth, globalTime);
            #endif
            #ifdef ENABLE_MID_CLOUDS
            applyLayer(tMid, BLOCK_SIZE_MID, vec2(0.003, 0.003), midDensity, midSpeed, midColor, midAlpha, color, viewDir, terrainDist, depth, globalTime);
            #endif
            #ifdef ENABLE_HIGH_CLOUDS
            applyLayer(tHigh, BLOCK_SIZE_HIGH, vec2(0.0005, 0.002), highDensity, highSpeed, highColor, highAlpha, color, viewDir, terrainDist, depth, globalTime);
            #endif
        }
    }
    
    if (isEyeInWater == 1) {
        vec3 underwaterColor = vec3(0.02, 0.2, 0.3);
        color = mix(color, underwaterColor * color * 2.5, 0.7);
        float uwFog = smoothstep(0.0, 20.0, terrainDist);
        color = mix(color, underwaterColor, uwFog);
    }

    gl_FragColor = vec4(color, 1.0);
}