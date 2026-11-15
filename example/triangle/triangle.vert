#version 450
// The classic spinning triangle: red top, green left, blue right, turning
// about the vertical axis in a 45-degree perspective view.
layout(push_constant) uniform Push { float angle; float aspect; } pc;
layout(location = 0) out vec3 colour;

const vec3 corner[3] = vec3[](vec3(0.0, 1.0, 0.0), vec3(-1.0, -1.0, 0.0), vec3(1.0, -1.0, 0.0));
const vec3 tint[3] = vec3[](vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));

void main() {
    vec3 p = corner[gl_VertexIndex];
    float c = cos(pc.angle), s = sin(pc.angle);
    vec3 q = vec3(c * p.x, p.y, -s * p.x - 4.0);
    float f = 1.0 / tan(radians(22.5));
    // Vulkan's clip space has y pointing down.
    gl_Position = vec4(f / pc.aspect * q.x, -f * q.y, 0.5 * -q.z, -q.z);
    colour = tint[gl_VertexIndex];
}
