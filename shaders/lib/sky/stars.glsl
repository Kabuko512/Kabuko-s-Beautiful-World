// --- /lib/sky/stars.glsl ---

float getStars(vec3 viewDir, float globalTime) {
    // Gwiazdy rysujemy tylko powyżej linii horyzontu
    if (viewDir.y < 0.01) return 0.0;

    // Projekcja sferyczna na płaszczyznę
    vec2 planeCoord = viewDir.xz / (viewDir.y + 0.02);
    
    // Rotacja siatki o ok. 35 stopni, aby uniknąć prostych linii na osiach X/Z
    float angle = 0.6;
    mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
    vec2 p = (rot * planeCoord) * 75.0;
    
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Unikalna wartość dla każdej komórki siatki
    float n = hash2(i);
    
    // Twardy warunek renderowania - albo gwiazda jest, albo jej nie ma (0 lub 1)
    // To jest najbardziej wydajne rozwiązanie (brak interpolacji/smoothstep)
    if (n > 1) {
        // Bardzo proste migotanie oparte na czasie
        // Jeśli sinus jest dodatni, gwiazda świeci pełną mocą, jeśli ujemny - jest lekko przygaszona
        float twinkle = sin(globalTime * 1.2 + n * 50.0) > 0.0 ? 1.0 : 0.6;
        
        // Definiujemy kształt kwadratu (ostre krawędzie)
        // Jeśli jesteśmy wewnątrz środkowej części komórki (0.2 - 0.8), rysujemy piksel
        if (f.x > 0.25 && f.x < 0.75 && f.y > 0.25 && f.y < 0.75) {
            return twinkle;
        }
    }
    
    return 0.0;
}