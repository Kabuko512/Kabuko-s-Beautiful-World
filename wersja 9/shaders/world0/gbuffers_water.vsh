#version 120

varying vec2 texcoord;
varying vec2 lmcoord;     // <-- DODANE: Przekazanie koordynatów lightmapy (światła Minecrafta)
varying vec4 glColor;
varying vec3 absWorldPos; // Przekazujemy absolutną pozycję świata!

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

void main() {
    gl_Position = ftransform();
    
    // Koordynaty tekstury bloków
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    
    // Koordynaty oświetlenia (dzień/noc i bloki świetlne)
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st; 
    
    glColor = gl_Color;
    
    // Obliczamy pozycję w świecie wokół kamery
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec3 worldPos = (gbufferModelViewInverse * viewPos).xyz;
    
    // BARDZO WAŻNE: Dodajemy cameraPosition, by woda była "przyklejona" do świata i nie poruszała się z naszą głową!
    absWorldPos = worldPos + cameraPosition; 
}