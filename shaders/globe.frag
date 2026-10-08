#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// Orthographic globe: wraps an equirectangular Earth texture (NASA Blue
// Marble) on a sphere seen from space, centred on (uLat0, uLon0).
uniform vec2 uCenter;   // globe centre on screen, logical px
uniform float uRadius;  // globe radius, logical px
uniform float uLat0;    // view centre latitude, radians
uniform float uLon0;    // view centre longitude, radians
uniform sampler2D uTexture;

out vec4 fragColor;

const float PI = 3.14159265359;

void main() {
  vec2 p = (FlutterFragCoord().xy - uCenter) / uRadius;
  p.y = -p.y;
  float r2 = dot(p, p);

  if (r2 > 1.0) {
    // Thin atmosphere halo just outside the limb.
    float d = sqrt(r2) - 1.0;
    float glow = exp(-d * 22.0) * 0.6;
    fragColor = vec4(vec3(0.33, 0.58, 1.0) * glow, glow);
    return;
  }

  float z = sqrt(1.0 - r2);
  // Inverse orthographic projection (sin c = rho, cos c = z).
  float lat = asin(clamp(z * sin(uLat0) + p.y * cos(uLat0), -1.0, 1.0));
  float lon = uLon0 + atan(p.x, z * cos(uLat0) - p.y * sin(uLat0));

  vec2 uv = vec2(fract((lon + PI) / (2.0 * PI)), (PI * 0.5 - lat) / PI);
  vec3 col = texture(uTexture, uv).rgb;

  // Soft daylight from the upper left, plus a blue rim of atmosphere.
  vec3 n = vec3(p.x, p.y, z);
  float diff = clamp(dot(n, normalize(vec3(-0.45, 0.5, 0.85))), 0.0, 1.0);
  col *= 0.30 + 0.90 * diff;
  float rim = pow(1.0 - z, 2.5);
  col = mix(col, vec3(0.45, 0.70, 1.0), rim * 0.55);

  fragColor = vec4(col, 1.0);
}
