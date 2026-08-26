shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// =================================---------------------------------
// CONFIGURATION (Constants are compiled directly into GPU assembly)
// =================================---------------------------------
const float VOXEL_SIZE    = 0.1; // Set to 0.0 to disable voxels
const bool  USE_OBJ_SPACE = false;

// Palette
const vec3 COL_DEEP = vec3(0.055, 0.028, 0.018);
const vec3 COL_LOW  = vec3(0.335, 0.155, 0.068);
const vec3 COL_MID  = vec3(0.760, 0.470, 0.215);
const vec3 COL_HIGH = vec3(0.976, 0.845, 0.600);

// Frequencies & Strengths
const float STRATA_FREQ   = 0.35;
const float DUNE_FREQ     = 0.60;
const float GRIT_STRENGTH = 1.00;
const float BAND_STRENGTH = 0.50;

varying vec3 v_pos;

// =================================---------------------------------
// FAST HASH & NOISE (No diagonal artifacts)
// =================================---------------------------------
float hash13(vec3 p3) {
	p3  = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    // Cubic interpolation
    f = f * f * (3.0 - 2.0 * f);
    
    return mix(mix(mix(hash13(i + vec3(0,0,0)), hash13(i + vec3(1,0,0)), f.x),
                   mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), f.x),
                   mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), f.x), f.y), f.z);
}

// =================================---------------------------------
// VERTEX / FRAGMENT
// =================================---------------------------------
void vertex() {
    v_pos = USE_OBJ_SPACE ? VERTEX : (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // 1. Calculate distance-fade factor BEFORE voxelization to prevent wireframe artifacts
    float dist_fade = clamp(1.0 - length(fwidth(v_pos)) * 4.0, 0.0, 1.0);
    
    // 2. Apply Voxelization
    vec3 p = (VOXEL_SIZE > 0.0) ? (floor(v_pos / VOXEL_SIZE + 0.5) * VOXEL_SIZE) : v_pos;

    // 3. OPTIMIZED NOISE PASS (Only 2 low-freq lookups for all macro shapes)
    float n_low = vnoise(p * 0.25);
    float n_mid = vnoise(p * 0.60);
    float warp  = (n_low * 0.7 + n_mid * 0.3) * 1.6;

    // Analytical shapes (Sines are virtually free on modern GPUs)
    float strata = sin(p.y * STRATA_FREQ + warp * 2.4) * 0.30;
    float dune   = sin((p.x * 0.9 + p.z * 1.3) * DUNE_FREQ + warp * 3.0) * 0.12;
    float band   = 0.5 + 0.5 * sin(p.y * 1.7 + warp * 2.0);

    // 4. HIGH FREQUENCY GRIT (Only 1 lookup, fades out at distance to stop aliasing/shimmering)
    // If pixel is far away, skip noise calculation entirely (branch optimization)
    float grit = 0.5;
    //if (dist_fade > 0.5) {
        grit = mix(0.5, vnoise(p * 18.0), dist_fade);
    //}

    // 5. COMBINE HEIGHT & COLOR
    float h = strata + (n_low * 0.55) + dune + ((grit - 0.5) * 0.25 * GRIT_STRENGTH);
    float t = clamp(h * 0.55 + 0.5, 0.0, 1.0);

    // Fast Color Ramp
    vec3 albedo = mix(COL_DEEP, COL_LOW,  smoothstep(0.00, 0.45, t));
    albedo      = mix(albedo,   COL_MID,  smoothstep(0.35, 0.75, t));
    albedo      = mix(albedo,   COL_HIGH, smoothstep(0.70, 1.00, t) * 0.6);

    // Modulate detail
    albedo *= mix(1.0, 0.86 + 0.20 * band, BAND_STRENGTH);
    albedo *= 0.85 + 0.30 * grit;

    ALBEDO    = albedo;
    ROUGHNESS = clamp(0.95 - 0.22 * grit, 0.55, 1.0);
    SPECULAR  = 0.25;
}
