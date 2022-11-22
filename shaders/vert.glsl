#version 300 es
in vec2 a_position;

uniform vec2 u_resolution;

out vec2 pos;

void main() {
    vec2 clip_space = a_position / u_resolution * 2.0 - 1.0;
    gl_Position = vec4(a_position, 0.0, 1.0);
    pos = a_position;
}