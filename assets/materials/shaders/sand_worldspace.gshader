shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// ===========================================================================
//  UNDERGROUND DESERT - world-space sandstone          (Godot 4, gdshader)
// ---------------------------------------------------------------------------
//  * Every texel is a pure function of WORLD position: no UVs are needed, so
//    terrain chunks, GridMap tiles, CSG cave tunnels and props all blend into
//    one continuous desert with zero seams.
//  * Rotate the mesh around X (see spin_field.gd) and the sand stays locked to
//    the world. Set sample_object_space = true to bake it to the polygon.
//  * For true 16x16 pixel blocks use the SubViewportContainer setup (see the
//    setup tab); colour_levels + dither add the palette quantisation here.
// ===========================================================================

group_uniforms palette;
uniform vec3 col_deep  : source_color = vec3(0.055, 0.028, 0.018);
uniform vec3 col_low   : source_color = vec3(0.335, 0.155, 0.068);
uniform vec3 col_mid   : source_color = vec3(0.760, 0.470, 0.215);
uniform vec3 col_high  : source_color = vec3(0.976, 0.845, 0.600);
uniform vec3 col_vein  : source_color = vec3(1.000, 0.610, 0.240);

group_uniforms projection;
uniform bool sample_object_space    = false; // true = texture glued to the mesh
uniform float world_grid            : hint_range(0.0, 1.0) = 0.0;
uniform float grid_size             : hint_range(0.25, 8.0) = 1.0;

group_uniforms sandstone;
uniform float strata_freq           : hint_range(0.2, 8.0) = 2.35;
uniform float dune_freq             : hint_range(0.2, 8.0) = 1.6;
uniform float grit_strength         : hint_range(0.0, 2.0) = 1.0;
uniform float band_strength         : hint_range(0.0, 1.0) = 0.5;
uniform float relief                : hint_range(0.0, 0.20) = 0.05;

group_uniforms veins;
uniform float vein_amount           : hint_range(0.0, 1.5) = 0.9;
uniform float vein_scale            : hint_range(0.05, 3.0) = 0.55;
uniform float vein_pulse_speed      : hint_range(0.0, 6.0) = 1.7;

group_uniforms cave_depth;
uniform float underground_darkness  : hint_range(0.0, 1.0) = 1.0;
uniform float dark_height           = -9.0;
uniform float lit_height            = 3.5;

group_uniforms pixel_art;
uniform float colour_levels         : hint_range(2.0, 48.0) = 22.0;
uniform float dither                : hint_range(0.0, 1.0) = 1.0;

varying vec3 w_pos;   // world space
varying vec3 o_pos;   // object / polygon space
varying vec3 w_nrm;   // world space normal

// ------------------------------ noise -------------------------------------
float hash13(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash13(i);
    float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
    return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
               mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm3(vec3 p) {
    float a = 0.5, s = 0.0;
    for (int i = 0; i < 3; i++) { s += a * vnoise(p); p *= 2.03; a *= 0.5; }
    return s / 0.875;
}

float fbm5(vec3 p) {
    float a = 0.5, s = 0.0;
    for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + vec3(1.7); a *= 0.5; }
    return s / 0.968;
}

// strata + dune ripples + grit, sampled at p (world or object space)
float sand_height(vec3 p) {
    float warp   = fbm3(p * 0.21) * 1.6;
    float strata = sin(p.y * strata_freq + warp * 2.4) * 0.30;
    float large  = fbm3(p * 0.42) * 0.55;
    float dune   = sin((p.x * 0.9 + p.z * 1.3) * dune_freq + fbm3(p * 0.7) * 3.0) * 0.12;
    float grit   = (vnoise(p * 13.0) * 0.16 + vnoise(p * 31.0) * 0.09
                 +  vnoise(p * 71.0) * 0.05) * grit_strength;
    return strata + large + dune + grit;
}

vec3 bump_normal(vec3 p, vec3 n, float strength) {
    vec3 up = abs(n.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    vec3 t = normalize(cross(up, n));
    vec3 b = cross(n, t);
    float e = 0.075;
    float h0 = sand_height(p);
    float hx = sand_height(p + t * e);
    float hy = sand_height(p + b * e);
    return normalize(n - strength * ((hx - h0) * t + (hy - h0) * b));
}

// ordered 4x4 threshold in [0,1), evaluated on real screen pixels
float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x * 0.5 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }

void vertex() {
    w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    o_pos = VERTEX;
    w_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL); // fine for uniform scale
}

void fragment() {
    // ---- THE WHOLE POINT: which space does the material live in? ----------
    vec3 p = mix(w_pos, o_pos, sample_object_space ? 1.0 : 0.0);
    vec3 nrm_ws = normalize(w_nrm);

    float h   = sand_height(p);
    vec3  nw  = bump_normal(p, nrm_ws, relief);

    // ---- albedo: strata bands, mottling, sand speckle --------------------
    float band = 0.5 + 0.5 * sin(p.y * 1.7 + fbm3(p * 0.35) * 3.4 + h * 1.2);
    float grit = vnoise(p * 47.0);
    float mote = fbm5(p * 2.3);

    float t = clamp(h * 0.55 + 0.5, 0.0, 1.0);
    vec3 albedo = mix(col_deep, col_low, smoothstep(0.0, 0.55, t));
    albedo = mix(albedo, col_mid,  smoothstep(0.35, 0.80, t));
    albedo = mix(albedo, col_high, smoothstep(0.78, 1.00, t) * 0.55);

    albedo *= mix(1.0, 0.86 + 0.20 * band, band_strength);   // strata banding
    albedo *= 0.92 + 0.16 * mote;
    albedo *= 0.90 + 0.20 * grit;
    albedo = mix(albedo, albedo * (0.7 + 0.6 * grit), 0.35);

    // ---- cave occlusion + depth falloff ---------------------------------
    float cav = clamp(0.5 - h * 0.85, 0.0, 1.0);
    float ao  = mix(1.0, 0.42, smoothstep(0.15, 0.95, cav));
    float grnd = clamp(0.5 - nrm_ws.y * 0.5, 0.0, 1.0);
    ao *= mix(1.0, 0.55, grnd);

    float dnorm = clamp((w_pos.y - dark_height) / max(lit_height - dark_height, 0.001), 0.0, 1.0);
    float dark = mix(1.0 - underground_darkness * 0.82, 1.0, smoothstep(0.0, 1.0, dnorm));

    ALBEDO    = albedo * ao * dark;
    ROUGHNESS = clamp(0.95 - 0.22 * grit, 0.55, 1.0);
    SPECULAR  = 0.25;

    // feed the bump map to Godot's own lighting (view space expected)
    NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

    // ---- emissive ore seams --------------------------------------------
    float r = 1.0 - abs(2.0 * fbm5(p * vein_scale + vec3(13.1, 4.7, 9.2)) - 1.0);
    float vein = pow(smoothstep(0.955, 0.998, r), 1.6);
    float pulse = 0.65 + 0.35 * sin(TIME * vein_pulse_speed + p.x * 0.5 + p.y * 0.35);
    EMISSION = col_vein * vein * vein_amount * (0.6 + 1.4 * pulse) * dark;

    // ---- optional world lattice: proof the material is world locked -----
//    if (world_grid > 0.001) {
//        vec3 g = abs(fract(p / grid_size + 0.5) - 0.5);
//        vec3 e = smoothstep(vec3(0.42), vec3(0.5), g);
//        float line = max(e.x, max(e.y, e.z));
//        vec3 v = normalize(CAMERA_POSITION_WORLD - w_pos);
//        line *= 0.4 + 0.6 * pow(clamp(dot(nrm_ws, v), 0.0, 1.0), 0.5);
//        ALBEDO = mix(ALBEDO, col_high * 1.15 + col_vein * 0.25,
//                     clamp(line * world_grid, 0.0, 1.0) * 0.75);
//    }

    // ---- palette quantisation (block size comes from the viewport) ------
    ALBEDO = floor(ALBEDO * colour_levels + bayer4(FRAGCOORD.xy) * dither) / colour_levels;
}

