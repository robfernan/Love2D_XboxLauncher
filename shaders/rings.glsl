extern float time;
extern vec2 resolution;
extern float ringRotation;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
    vec2 uv = texture_coords;
    vec2 st = (uv * resolution - resolution * 0.5) / min(resolution.x, resolution.y);
    float dist = length(st);
    float angle = atan(st.y, st.x);


    // base background
    vec3 bg = vec3(0.02, 0.0, 0.04);
    vec3 ringColor = vec3(1.0, 0.2, 1.0);
    vec3 col = bg;

    // radial spokes (subtle)
    float spokes = smoothstep(0.005, 0.0, abs(mod(angle / (3.14159265/8.0), 1.0) - 0.5));
    col += ringColor * (spokes * 0.06);

    // animated elliptical orbital rings
    // rotate coordinates for ring tilt
    float a = ringRotation;
    mat2 rot = mat2(cos(a), -sin(a), sin(a), cos(a));
    vec2 est = rot * st;
    // make ellipse by scaling x
    est.x *= 1.3;
    float ed = length(est);

    // place a few rings at different radii with smooth thickness
    float ring1 = 1.0 - smoothstep(0.16 - 0.006, 0.16 + 0.006, abs(ed - 0.16));
    float ring2 = 1.0 - smoothstep(0.24 - 0.008, 0.24 + 0.008, abs(ed - 0.24));
    float ring3 = 1.0 - smoothstep(0.32 - 0.01, 0.32 + 0.01, abs(ed - 0.32));
    float rings = max(max(ring1, ring2), ring3);

    // add subtle animated shimmer along rings
    float shimmer = 0.6 + 0.6 * sin(time * 2.4 + ed * 30.0);
    col += ringColor * (rings * 1.0 * shimmer);

    // faint outer glow from rings
    float glow = smoothstep(0.16, 0.4, ed);
    col += ringColor * 0.02 * (1.0 - glow);

    // subtle animated glow overlay
    col += ringColor * 0.03 * sin(time * 0.8 + dist * 6.0);

    // planet at center with pulsing light
    float pr = 0.16;
    float planetMask = 1.0 - smoothstep(pr - 0.002, pr + 0.002, dist);
    vec3 planetBase = vec3(0.15, 0.02, 0.12);
    vec3 planetHighlight = vec3(0.8, 0.45, 1.0) * 0.6;
    float band = smoothstep(pr * 0.6, pr * 0.4, dist);
    vec3 planet = mix(planetHighlight, planetBase, band);
    float rim = smoothstep(pr - 0.01, pr + 0.02, dist);
    planet += vec3(0.2, 0.1, 0.25) * (1.0 - rim);

    // pulsing intensity
    float pulse = 1.0 + 0.42 * sin(time * 2.4);
    planet *= pulse;

    // subtle specular spot that orbits
    float spotAngle = time * 0.9;
    vec2 lightPos = vec2(0.25 * cos(spotAngle), 0.18 * sin(spotAngle));
    float lp = length(st - lightPos);
    float spec = 1.0 - smoothstep(0.0, 0.08, lp);
    planet += vec3(1.0,0.6,1.0) * spec * 0.45 * pulse;

    col = mix(col, planet, planetMask);

    return vec4(col, 1.0);
}
