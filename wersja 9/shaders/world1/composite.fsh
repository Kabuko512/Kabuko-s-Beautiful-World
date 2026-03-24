/*
    Plik composite.fsh - Symulacja Galaktyki wg. Teorii Fal Gęstości
    (Wersja ABSOLUTNE ZERO - Potato PC / Max FPS Demoscene Edition)
    + SKALOWANIE DO GIGANTYCZNYCH ROZMIARÓW
    + MINECRAFTOWE (KWADRATOWE) CZĄSTECZKI (Wersja drobna)
    + FIX Winding Dilemma (Brak psującej się siatki)
    + CZARNA DZIURA (Horyzont zdarzeń, ssanie spiralne i złoty dysk)
    + SFERYCZNY SKYBOX (Rzadkie, wyizolowane gwiazdy w kolorach Endu)
    + ULTIMATE FAIL-SAFE (Wir biegunowy - 100% odporność na utratę precyzji czasu)
    + PRAWDZIWE FALOWANIE 3D (Fizyczne unoszenie i opadanie w osi Y)
    + EFEKT 1: SOCZEWKOWANIE GRAWITACYJNE (Gravitational Lensing) wokół czarnej dziury
    + EFEKT 6: SZUM PROMIENIOWANIA TŁA (Lo-Fi Sensor Noise w pustce)
*/
#version 120

// --- USTAWIENIE ROZMIARU ---
// 1.0 = Standardowy rozmiar (promień ok. 1250 bloków)
// 10.0 = 10x większa (promień ok. 12 500 bloków)
#define GALAXY_SCALE 15.0 

// --- GĘSTOŚĆ CZĄSTECZEK ---
// Mniejsza liczba (np. 20.0) = Gigantyczne, rzadkie piksele/klocki
// Większa liczba (np. 150.0) = Drobny, gęsty gwiezdny pył
#define PARTICLE_DENSITY 150.0

uniform sampler2D colortex0; 
uniform sampler2D depthtex0; 

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform vec3 skyColor;
uniform float frameTimeCounter;

varying vec4 color;
varying vec2 coord0;

// Najtańszy możliwy generator chaosu 2D
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

void main()
{
    vec4 col = texture2D(colortex0, coord0);
    float depth = texture2D(depthtex0, coord0).r;

    if (length(skyColor) < 0.001 && depth == 1.0) {
        
        vec4 screenPos = vec4(coord0.x * 2.0 - 1.0, coord0.y * 2.0 - 1.0, 1.0, 1.0);
        vec4 viewPos = gbufferProjectionInverse * screenPos;
        viewPos /= viewPos.w;
        vec3 dir = normalize((gbufferModelViewInverse * vec4(viewPos.xyz, 0.0)).xyz);
        
        float time = frameTimeCounter * 0.15;
        vec3 ro = cameraPosition; 
        
        // ==========================================
        // EFEKT 1: SOCZEWKOWANIE GRAWITACYJNE (ZAGINANIE PROMIENI)
        // ==========================================
        float distToBH = length(ro); // Czarna dziura jest w (0,0,0)
        
        if (distToBH > 0.1) {
            vec3 bhDir = -ro / distToBH; // Wektor patrzenia centralnie w stronę czarnej dziury
            float dotDir = dot(dir, bhDir);
            
            // PŁYNNE PRZEJŚCIE (FIX dla uciętej linii ze screena):
            // Zamiast twardego if(dotDir > 0), łagodnie zjeżdżamy z siłą ugięcia 
            // do zera, gdy obracasz kamerę w inną stronę.
            float lookMask = smoothstep(-0.2, 0.2, dotDir);
            
            // Najbliższy punkt promienia względem czarnej dziury
            vec3 closestP = ro + dir * (distToBH * max(0.0, dotDir)); 
            float impact = length(closestP);
            
            float eventHorizon = 93.75; 
            
            // TWOJA ULUBIONA SIŁA Z PIERWSZEJ WERSJI:
            float lensForce = eventHorizon / max(impact, eventHorizon * 0.8);
            lensForce = pow(lensForce, 4.0) * 0.35; 
            
            // Wygładzamy krawędzie używając maski (by usunąć prostą, brzydką krawędź)
            lensForce *= lookMask;
            
            // Pociągamy promień wzroku w kierunku centrum (bezpieczne dla samego środka by uniknąć glitchy)
            vec3 pullDir = -closestP / max(impact, 0.0001);
            dir = normalize(dir + pullDir * lensForce);
        }
        
        // Przepisujemy zakrzywiony wektor do naszego raymarchingu!
        vec3 rd = dir;            
        vec3 galaxyCol = vec3(0.0);
        
        float t = -1.0;
        if (abs(rd.y) > 0.0001) {
            t = -ro.y / rd.y; 
        }
        
        float maxDist = 2000.0 * GALAXY_SCALE;
        
        // ==========================================
        // 1. RENDEROWANIE GŁÓWNEGO DYSKU GALAKTYKI
        // ==========================================
        if (t > 0.0 && t < maxDist) {
            // Najpierw sprawdzamy pozycję na "płaskim" dysku by wyliczyć fale
            vec3 pFlat = ro + rd * t; 
            
            float rWorldBase = length(pFlat.xz);
            float rBase = rWorldBase * (0.004 / GALAXY_SCALE); 
            float thetaBase = atan(pFlat.z, pFlat.x);
            
            // --- EFEKT PRAWDZIWEGO FALOWANIA (GÓRA / DÓŁ w osi Y) ---
            float ripple1 = sin(rBase * 40.0 - time * 6.0);
            float ripple2 = sin(rBase * 25.0 + thetaBase * 6.0 - time * 4.0);
            float waveRipple = (ripple1 + ripple2) * 0.5;
            
            // Wygładzanie w centrum (0.1 do 1.2 wygasa by środek był idealnie płaski)
            float flattenMask = smoothstep(0.1, 1.2, rBase); 
            
            // Redukujemy fale blisko horyzontu (by uniknąć zrywania geometrii pod kątem płaskim)
            float perspectiveDamp = smoothstep(0.001, 0.05, abs(rd.y));
            
            // WYSOKOŚĆ FAL W BLOKACH (40.0 = potężne fale idące góra dół!)
            float waveHeight = waveRipple * flattenMask * 40.0 * perspectiveDamp;
            
            // MAGIA: Przeliczamy uderzenie promienia wzroku celując w NOWĄ WYSOKOŚĆ zamiast w Y=0
            t = (waveHeight - ro.y) / rd.y;
            
            // Upewniamy się, że po wzniesieniu się fali nie wyszła nam za plecy
            if (t > 0.0 && t < maxDist) {
                // Nowa, perfekcyjnie trójwymiarowa współrzędna fizyczna uderzenia wzroku!
                vec3 p = ro + rd * t;
                
                // Refleksy świetlne pojawiające się tylko na wierzchołkach fal
                float waterCrest = smoothstep(0.5, 1.0, waveRipple) * flattenMask;
                
                // Przeliczamy finalne dane układu po odkształceniu przestrzennym 
                float rWorld = length(p.xz);
                float r = rWorld * (0.004 / GALAXY_SCALE); 
                
                if (r < 5.0) { 
                    float r2 = r * r; 
                    
                    float disk = 0.8 / (1.0 + r2 * 2.0);
                    float bulge = 2.0 / (1.0 + r2 * 30.0);
                    
                    if (bulge + disk > 0.01) {
                        float theta = atan(p.z, p.x);
                        
                        float innerCore = 3.0 / (1.0 + r2 * 200.0); 
                        float TWO_PI = 6.28318530718;
                        
                        float thetaWave = theta - mod(0.3 * time, TWO_PI);
                        float thetaMatter = theta - mod(1.2 * time, TWO_PI); 
                        
                        vec2 dUv = vec2(cos(thetaMatter), sin(thetaMatter)) * r * 15.0;
                        float pseudoNoise = sin(dUv.x + 1.2 * sin(dUv.y)) * sin(dUv.y + 1.5 * cos(dUv.x));
                        pseudoNoise = pseudoNoise * 0.5 + 0.5; 
                        
                        float dustMask = smoothstep(0.4, 0.8, pseudoNoise);
                        float wave = sin(2.0 * thetaWave - 12.0 * r + pseudoNoise * 1.5);
                        float spiralMask = smoothstep(0.1, 0.9, wave);

                        float rings = PARTICLE_DENSITY;
                        float segments = floor(PARTICLE_DENSITY * 6.0); 
                        float Y_PERIOD = 50.0; 
                        
                        float inwardSpeed = 3.0 / GALAXY_SCALE;
                        float flowY = mod(time * inwardSpeed * rings, Y_PERIOD); 
                        
                        vec2 polarUV = vec2(thetaMatter * (segments / TWO_PI), r * rings + flowY);
                        
                        vec2 cell = floor(polarUV);
                        vec2 local = fract(polarUV); 
                        
                        vec2 pCell = cell;
                        pCell.x = mod(pCell.x, segments);
                        pCell.y = mod(pCell.y, Y_PERIOD);
                        
                        float rando = hash(pCell);
                        
                        float pixelShape = step(0.4, local.x) * step(local.x, 0.6) * step(0.4, local.y) * step(local.y, 0.6);
                        
                        float starMask = step(0.96, rando) * pixelShape * (disk + bulge * 0.5);
                        float h2Mask = step(0.99, rando) * pixelShape * spiralMask * disk; 
                        
                        vec3 cCore   = vec3(1.0, 0.95, 1.0);  
                        vec3 cBulge  = vec3(0.6, 0.3, 0.9);   
                        vec3 cDisk   = vec3(0.08, 0.02, 0.15);
                        vec3 cArm    = vec3(0.5, 0.1, 0.8);   
                        vec3 cH2     = vec3(1.0, 0.3, 0.9);   
                        
                        vec3 localCol = cCore * innerCore + cBulge * bulge + cDisk * disk;
                        localCol += cArm * spiralMask * disk * 2.5;
                        localCol *= (1.0 - dustMask * disk * 0.9); 
                        localCol += cH2 * h2Mask * 8.0;
                        localCol += vec3(1.0) * starMask * 4.0;
                        
                        // Delikatny, magiczny refleks na grzbietach fal wpadających do centrum
                        localCol += vec3(0.6, 0.4, 1.0) * waterCrest * disk * 8.0;
                        
                        float bhRadius = 0.025; 
                        float blackHoleMask = smoothstep(bhRadius, bhRadius + 0.005, r);
                        float accretionDisk = smoothstep(bhRadius, bhRadius + 0.005, r) * (1.0 - smoothstep(bhRadius + 0.005, bhRadius + 0.035, r));
                        
                        localCol += vec3(1.0, 0.85, 0.2) * accretionDisk * 50.0;
                        localCol *= blackHoleMask;
                        
                        float opticalDepth = clamp(0.1 / (abs(rd.y) + 0.01), 0.2, 4.0);
                        float density = (disk + bulge + starMask) * opticalDepth * 0.4;
                        
                        galaxyCol += localCol * density * (1.0 / (1.0 + t * (0.001 / GALAXY_SCALE))); 
                    }
                }
            }
        }

        // ==========================================
        // 2. SFERYCZNE TŁO W KOLORACH ENDU (SKYBOX)
        // (Również ulega soczewkowaniu grawitacyjnemu!)
        // ==========================================
        float yaw = atan(dir.z, dir.x);
        float pitch = asin(dir.y);
        vec2 sphereUV = vec2(yaw * 1.5, pitch);
        vec2 skyGridUV = sphereUV * 120.0; 
        
        vec2 bgGrid = floor(skyGridUV); 
        vec2 bgLocal = fract(skyGridUV);
        
        float bgHash = hash(bgGrid);
        float bgColHash = hash(bgGrid + vec2(45.1, 12.8));
        
        vec3 bgPixels = vec3(0.0);
        float skyStarShape = step(0.3, bgLocal.x) * step(bgLocal.x, 0.7) * step(0.3, bgLocal.y) * step(bgLocal.y, 0.7);
        
        if (bgHash > 0.985) {
            vec3 endColorA = vec3(0.15, 0.0, 0.3);
            vec3 endColorB = vec3(0.5, 0.1, 0.8);
            bgPixels = mix(endColorA, endColorB, bgColHash);
            
            if (bgHash > 0.995) {
                bgPixels = mix(vec3(0.8, 0.6, 1.0), vec3(0.3, 0.8, 0.7), bgColHash);
            }
            bgPixels *= skyStarShape;
        }
        
        float galBrightness = dot(galaxyCol, vec3(0.333)); 
        vec3 space = galaxyCol + bgPixels * (1.0 / (1.0 + galBrightness * 15.0));

        // ==========================================
        // 3. WYKOŃCZENIE OBRAZU I TONEMAPPING
        // ==========================================
        space = space / (space + vec3(0.5)); 
        
        // ==========================================
        // 4. EFEKT 6: SZUM PROMIENIOWANIA TŁA (CMB / LO-FI)
        // ==========================================
        // Obliczamy jasność piksela. Nakładamy szum tylko tam, gdzie jest ciemno
        float lum = dot(space, vec3(0.299, 0.587, 0.114));
        float cmbMask = 1.0 - smoothstep(0.0, 0.05, lum); 
        
        // Szybki szum RGB "śnieżącej matrycy" zależny od współrzędnych ekranu i czasu
        float pxTime = mod(time, 1000.0);
        vec2 seed = coord0 * 3000.0; 
        
        vec3 cmbNoise = vec3(
            hash(seed + vec2(pxTime * 1.1, 0.0)),
            hash(seed + vec2(0.0, pxTime * 1.2)),
            hash(seed + vec2(pxTime * 1.3, pxTime * 1.3))
        );
        
        // Ściszenie amplitudy z (0.0 do 1.0) do szumu od (-0.02 do +0.02)
        cmbNoise = (cmbNoise - 0.5) * 0.04; 
        
        // Dodanie bardzo delikatnego, ciepłego zabarwienia "promieniowania kosmicznego"
        cmbNoise += vec3(0.01, 0.002, 0.006); 
        
        // Nakładamy szum tła tam, gdzie pozwala na to maska
        space += cmbNoise * cmbMask;

        col.rgb = space;
    }

    gl_FragData[0] = color * col;
}