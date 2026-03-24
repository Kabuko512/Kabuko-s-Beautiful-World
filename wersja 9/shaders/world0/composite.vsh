#version 120

varying vec2 texcoord;

// Podstawowy vertex shader dla efektów post-processingowych.
// Przekazuje pozycję na ekranie i koordynaty tekstury.
void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.st;
}