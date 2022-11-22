#version 300 es

precision highp float;

in vec2 pos;

uniform sampler2D u_texture;

out vec4 outColor;

void main() {
    vec4 col = texture(u_texture, (pos+1.0)/2.0);

    col = pow(col, vec4(1.0 / 2.2));
    outColor = col;
}