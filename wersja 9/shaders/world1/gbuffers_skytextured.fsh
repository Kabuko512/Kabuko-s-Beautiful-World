/*
    XorDev's "Default Shaderpack" - Zmodyfikowane dla Kosmosu w Endzie

    This was put together by @XorDev to make it easier for anyone to make their own shaderpacks in Minecraft (Optifine).
    You can do whatever you want with this code! Credit is not necessary, but always appreciated!

*/
//Declare GL version.
#version 120

//Diffuse (color) texture.
uniform sampler2D texture;

//0-1 amount of blindness.
uniform float blindness;
//0 = default, 1 = water, 2 = lava.
uniform int isEyeInWater;

// Identyfikator wymiaru: 0 = Overworld, -1 = Nether, 1 = End
uniform int world;

// Licznik czasu do animacji (płynnego poruszania się mgławic i migotania gwiazd)
uniform float frameTimeCounter;

//Vertex color.
varying vec4 color;
//Diffuse texture coordinates.
varying vec2 coord0;
//Kierunek patrzenia przekazany z vertex shadera
varying vec3 viewPos;

// --- FUNKCJE POMOCNICZE DO GENEROWANIA KOSMOSU ---

// Funkcja pseudolosowa (Hash)
float hash(vec3 p) {
    p  = fract( p*0.3183099+.1 );
    p *= 17.0;
    return fract( p.x*p.y*p.z*(p.x+p.y+p.z) );
}

// Funkcja szumu 3D (Value Noise)
float noise( in vec3 x ) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f*f*(3.0-2.0*f);
    return mix(mix(mix( hash(i+vec3(0,0,0)), hash(i+vec3(1,0,0)),f.x),
                   mix( hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)),f.x),f.y),
               mix(mix( hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)),f.x),
                   mix( hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}

// Fractal Brownian Motion (FBM) - służy do tworzenia fraktalnych kształtów (mgławic i pyłu)
float fbm(vec3 p) {
    float f = 0.0;
    float amp = 0.5;
    for(int i = 0; i < 5; i++) {
        f += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return f;
}

void main()
{
    // Widoczność na podstawie efektu ślepoty.
    vec3 light = vec3(1.-blindness);
    
    // Normalizujemy pozycję, by uzyskać wektor kierunkowy na sferze niebieskiej.
    vec3 dir = normalize(viewPos);
    
    // Pobieramy standardową teksturę.
    vec4 texColor = texture2D(texture, coord0);
    vec3 finalColor = color.rgb * texColor.rgb;

    // Sprawdzamy, czy gracz znajduje się w Endzie (world == 1)
    if (world == 1) {
        float time = frameTimeCounter * 0.03; // Zmienna czasu do animacji
        
        // 1. GŁĘBIA KOSMOSU (Ciemne tło)
        vec3 space = vec3(0.01, 0.01, 0.03); 
        
        // 2. GWIAZDY
        // Dwie warstwy gwiazd o różnej wielkości i częstotliwości
        float s1 = noise(dir * 300.0);
        float star1 = pow(s1, 35.0) * 15.0; // Małe, ostre gwiazdki
        
        float s2 = noise(dir * 150.0 + vec3(20.0));
        float star2 = pow(s2, 20.0) * 4.0;  // Większe, lekko rozmyte
        
        // Efekt migotania
        float twinkle = 0.5 + 0.5 * sin(time * 5.0 + dir.x * 100.0 + dir.y * 100.0);
        
        vec3 starColor = vec3(1.0, 0.95, 0.9) * star1 * twinkle + vec3(0.6, 0.8, 1.0) * star2;
        space += starColor;

        // 3. MGŁAWICE
        // Zaburzony wektor kierunku, by uzyskać efekt "zawirowań"
        vec3 warp = dir + 0.2 * vec3(fbm(dir * 2.0 + time * 0.1), fbm(dir * 2.0 - time * 0.1), 0.0);
        
        // Dwie warstwy szumu mgławicowego
        float n1 = fbm(warp * 2.5);
        float n2 = fbm(warp * 4.0 + vec3(10.0));
        
        // Fioletowo-różowe kolory
        vec3 nebColor1 = vec3(0.5, 0.1, 0.7) * pow(n1, 2.5) * 2.0;
        // Jasnoniebieskie i cyjanowe akcenty
        vec3 nebColor2 = vec3(0.1, 0.4, 0.9) * pow(n2, 2.5) * 1.5;
        
        space += nebColor1 + nebColor2;

        // 4. DROGA MLECZNA (Główny pas galaktyczny)
        // Obliczamy pas galaktyki przy użyciu iloczynu skalarnego (dot product)
        float bandMask = abs(dot(dir, normalize(vec3(1.0, 0.7, -0.4))));
        float mw = smoothstep(0.4, 0.0, bandMask); // Zmiękczamy krawędzie pasa
        
        // Dodajemy detale i poszarpanie do pasa
        float mwDetail = fbm(dir * 6.0 + time * 0.05);
        mw *= mwDetail;
        
        // Ciemne pasma pyłu (odejmowanie szumu)
        float dust = fbm(dir * 12.0 + vec3(5.0));
        mw = max(0.0, mw - dust * 0.5);
        
        // Nakładamy kolor na pas galaktyki
        vec3 milkyWayColor = vec3(0.8, 0.6, 1.0) * mw * 2.5;
        space += milkyWayColor;

        // Nadpisujemy ostateczny kolor nieba
        finalColor = space;
    }

    //Output the result.
    gl_FragData[0] = vec4(finalColor * light, 1.0);
}