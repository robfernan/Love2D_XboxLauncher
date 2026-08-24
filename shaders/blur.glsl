extern vec2 direction; // direction to blur: (1,0) or (0,1)
extern vec2 resolution;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
    vec2 uv = texture_coords;
    vec2 off = direction / resolution;
    vec4 sum = vec4(0.0);
    // simple 9-tap box blur
    for (int i = -4; i <= 4; ++i) {
        sum += Texel(texture, uv + off * float(i));
    }
    sum /= 9.0;
    return sum * color;
}
