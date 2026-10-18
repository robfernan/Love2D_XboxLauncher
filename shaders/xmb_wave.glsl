// ============================================================================
// PSP / PS3 DYNAMIC XMB WAVE SHADER
// Authentic implementation of the classic PlayStation XMB dynamic wave.
// Uses layered harmonic sinusoids with smooth vertical gradients,
// thickness modulation, and additive Gaussian glow.
// ============================================================================

extern vec2 resolution;
extern float time;
extern vec3 waveColor;
extern vec3 bgColor;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = screen_coords.xy / resolution.xy;

    // 1) Vertical Atmospheric Background Gradient (Dark top, subtle glow bottom)
    float bgGradient = mix(0.18, 0.45, uv.y);
    vec3 col = bgColor * bgGradient;

    // 2) Wave Parameters
    float t = time * 0.45;
    float waveAccum = 0.0;

    // Layer 1: Primary Broad Silk Wave
    float y1 = 0.58 + 0.12 * sin(uv.x * 2.8 + t * 1.1) 
                    + 0.06 * cos(uv.x * 5.2 - t * 0.7);
    float dist1 = abs(uv.y - y1);
    float glow1 = 0.015 / (dist1 + 0.025);
    waveAccum += glow1 * 0.55;

    // Layer 2: Faster Secondary Harmonic Wave
    float y2 = 0.54 + 0.14 * sin(uv.x * 3.4 - t * 1.4 + 1.2) 
                    + 0.05 * sin(uv.x * 6.5 + t * 0.9);
    float dist2 = abs(uv.y - y2);
    float glow2 = 0.012 / (dist2 + 0.022);
    waveAccum += glow2 * 0.45;

    // Layer 3: Thin Crisp Ribbon Wave
    float y3 = 0.60 + 0.10 * sin(uv.x * 4.2 + t * 0.8 + 2.5) 
                    + 0.07 * cos(uv.x * 2.1 - t * 1.2);
    float dist3 = abs(uv.y - y3);
    float glow3 = 0.008 / (dist3 + 0.015);
    waveAccum += glow3 * 0.40;

    // Layer 4: Deep Ambient Undulation
    float y4 = 0.50 + 0.16 * sin(uv.x * 1.8 + t * 0.6 + 4.0);
    float dist4 = abs(uv.y - y4);
    float glow4 = 0.025 / (dist4 + 0.05);
    waveAccum += glow4 * 0.25;

    // 3) Horizon Line Light Sheen
    float horizon = 0.006 / (abs(uv.y - 0.56) + 0.035);
    waveAccum += horizon * 0.15;

    // 4) Combine Wave Color & Bloom onto Base
    col += waveColor * waveAccum;

    // Soft vignette on edges
    float vignette = uv.x * (1.0 - uv.x) * uv.y * (1.0 - uv.y);
    vignette = clamp(pow(16.0 * vignette, 0.25), 0.0, 1.0);
    col *= (0.7 + 0.3 * vignette);

    return vec4(col, 1.0);
}
