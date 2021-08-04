
layout (location = 0) out vec3 col;

vec3[3] points = vec3[](
    vec3(-0.5, -0.5, 0.5),
    vec3(0.5, -0.5, 0.5),
    vec3(0, 0.5, 0.5)
);

vec3[3] colors = vec3[](
    vec3(1, 0, 0),
    vec3(0, 1, 0),
    vec3(0, 0, 1)
);

void main() {
    gl_Position = vec4(points[gl_VertexIndex], 1);
    col = colors[gl_VertexIndex];
}