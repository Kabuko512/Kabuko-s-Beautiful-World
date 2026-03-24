/*
    Domyślny plik composite.vsh
    Służy do przygotowania pełnoekranowego obszaru do post-processingu.
*/
#version 120

varying vec4 color;
varying vec2 coord0;

void main()
{
    // Ustawienie pozycji werteksów dla pełnoekranowego quada (ekranu)
    gl_Position = ftransform();

    // Przekazanie bazowego koloru i koordynatów tekstury (UV) do fragment shadera
    color = gl_Color;
    coord0 = (gl_MultiTexCoord0).xy;
}