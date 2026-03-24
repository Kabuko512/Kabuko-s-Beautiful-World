#version 120

varying vec4 glcolor;
varying vec3 starPos;

void main() {
    // Standardowa transformacja wierzchołków nieba i gwiazd na ekran
    gl_Position = ftransform();
    
    // Pobieramy oryginalny kolor nieba/gwiazd z gry
    glcolor = gl_Color;
    
    // Zapisujemy pozycję wierzchołka. 
    // Dla gwiazd będą to ich współrzędne w przestrzeni 3D nieba.
    starPos = gl_Vertex.xyz;
}