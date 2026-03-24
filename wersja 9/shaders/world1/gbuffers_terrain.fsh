#version 120

// Pobranie tekstury odziedziczonej z Minecrafta
uniform sampler2D texture;
uniform sampler2D lightmap; // Dodane: uniform dla mapy światła (słońce, pochodnie)

varying vec2 texcoord;
varying vec2 lmcoord;       // Dodane: odbiór koordynatów mapy światła z vsh
varying vec4 glcolor;

void main() {
    // Nałożenie tekstury bloku i jego naturalnego koloru (np. zielony odcień biomu dla trawy)
    vec4 color = texture2D(texture, texcoord) * glcolor;
    
    // Dodane: pobranie poziomu oświetlenia (światło blokowe + niebo) z mapy światła gry
    vec4 light = texture2D(lightmap, lmcoord);
    
    // Jeśli dany piksel jest przezroczysty, całkowicie go ignorujemy
    // Zapobiega to błędom ze z-bufferem i dziwnemu wyświetlaniu przezroczystości
    if (color.a < 0.1) {
        discard;
    }
    
    // Ostateczny kolor piksela na ekranie (wymnożony przez światło)
    gl_FragColor = color * light;
}