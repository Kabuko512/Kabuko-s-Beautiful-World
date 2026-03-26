// --- /lib/sky/lightning.glsl ---
// Wymaga: /lib/math/noise.glsl

#define LIGHTNING_PIXELATION 40.0 
#define LIGHTNING_FREQUENCY 1.0

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