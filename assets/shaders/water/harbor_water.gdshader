shader_type spatial;
render_mode world_vertex_coords, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, shadows_disabled;

// ---------------------------------------------------------------- palette ----
// Hues follow the Iron Harbor UI tokens + main-menu banner:
// petrol/teal body, brass sunset glints, paper-white foam.
uniform vec3 deep_color : source_color = vec3(0.090, 0.260, 0.280);
uniform vec3 shallow_color : source_color = vec3(0.150, 0.380, 0.380);
uniform vec3 crest_color : source_color = vec3(0.400, 0.600, 0.570);
uniform vec3 sky_horizon_color : source_color = vec3(0.200, 0.260, 0.290);
uniform vec3 sky_zenith_color : source_color = vec3(0.050, 0.080, 0.110);
uniform vec3 sun_color : source_color = vec3(1.000, 0.740, 0.420);
uniform vec3 foam_color : source_color = vec3(0.800, 0.840, 0.820);
uniform vec3 horizon_color : source_color = vec3(0.620, 0.400, 0.250);

// ------------------------------------------------------------------ waves ----
// Keep the swell parameters in sync with dev_scenes/harbor/bobbing_boat.gd.
uniform float swell_height = 0.14;
uniform float wave_speed = 0.65;
uniform float detail_strength = 1.10;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : hint_default_black, filter_linear_mipmap, repeat_enable;

// ------------------------------------------------------------- reflection ----
uniform vec3 sun_direction = vec3(-0.33, 0.14, -0.93);
uniform float sun_energy = 0.9;
uniform float reflection_strength = 0.52;
uniform float fresnel_power = 7.0;

// --------------------------------------------------------------- shoreline ----
// Quay waterline runs along X at shore_z; the hull foam ring follows the boat.
uniform float shore_z = -14.4;
uniform float shore_span = 18.0;
uniform float shore_foam_width = 2.8;
uniform float foam_strength = 0.75;
uniform vec2 boat_center = vec2(2.0, -5.5);
uniform vec2 boat_half_size = vec2(8.9, 4.0);
uniform float boat_yaw = -0.21;
uniform float boat_foam_width = 0.70;

// ---------------------------------------------------------------- distance ----
uniform float horizon_fade_start = 110.0;
uniform float horizon_fade_end = 230.0;

varying vec3 v_world;

// Shared wave model (unit amplitude, ~[-1, 1]).
float swell(vec2 p, float t) {
	float h = sin(dot(p, vec2(0.85, 0.53)) * 0.42 + t * 0.85) * 0.55;
	h += sin(dot(p, vec2(-0.42, 0.91)) * 0.85 + t * 1.25) * 0.30;
	h += sin(dot(p, vec2(0.62, -0.78)) * 1.75 - t * 1.90) * 0.15;
	return h;
}

vec2 swell_gradient(vec2 p, float t) {
	float e = 0.8;
	return vec2(
		swell(p + vec2(e, 0.0), t) - swell(p - vec2(e, 0.0), t),
		swell(p + vec2(0.0, e), t) - swell(p - vec2(0.0, e), t)
	) / (2.0 * e);
}

// Tangent-space XY of the baked noise normal map used as a slope field.
vec2 noise_slope(vec2 p, float t) {
	vec3 n1 = texture(detail_normal, p * 0.045 + vec2(t * 0.020, t * 0.011)).xyz * 2.0 - 1.0;
	vec3 n2 = texture(detail_normal, p * 0.130 + vec2(-t * 0.032, t * 0.024)).xyz * 2.0 - 1.0;
	return vec2(n1.x + n2.y, n1.y - n2.x);
}

void vertex() {
	v_world = VERTEX;
	float t = TIME * wave_speed;
	VERTEX.y += swell(v_world.xz, t) * swell_height;
}

void fragment() {
	vec2 p = v_world.xz;
	float t = TIME * wave_speed;

	// --- surface slope: long swell + scrolling noise ripples ----------------
	vec2 grad = swell_gradient(p, t) * swell_height;
	float cam_dist = distance(v_world, CAMERA_POSITION_WORLD);
	float atten = 1.0 / (1.0 + cam_dist * 0.035);
	grad += noise_slope(p, t) * detail_strength * atten * 0.70;

	vec3 n_world = normalize(vec3(-grad.x, 1.0, -grad.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// --- Fresnel-weighted sky reflection ------------------------------------
	vec3 view = normalize(CAMERA_POSITION_WORLD - v_world);
	float ndv = clamp(dot(view, n_world), 0.0, 1.0);
	float fres = pow(1.0 - ndv, fresnel_power);
	float reflection = mix(0.06, 1.0, fres) * reflection_strength;

	vec3 refl = reflect(-view, n_world);
	vec3 sky = mix(sky_horizon_color, sky_zenith_color, clamp(refl.y * 1.8 + 0.10, 0.0, 1.0));
	float sun_glow = pow(clamp(dot(refl, normalize(sun_direction)), 0.0, 1.0), 32.0);
	sky += sun_color * sun_glow * 0.25;
	// Wide warm smear along the sun azimuth keeps the glitter path readable.
	vec2 refl_flat = normalize(vec2(refl.x, refl.z) + vec2(0.0001));
	vec2 sun_flat = normalize(vec2(sun_direction.x, sun_direction.z) + vec2(0.0001));
	float sun_path = pow(clamp(dot(refl_flat, sun_flat), 0.0, 1.0), 30.0);
	sky += sun_color * sun_path * 0.15;

	// --- body colour: troughs deep, crests lighter --------------------------
	float crest = clamp(swell(p, t) * 0.5 + 0.5, 0.0, 1.0);
	vec3 body = mix(deep_color, shallow_color, crest * 0.65);
	body = mix(body, crest_color, pow(crest, 7.0) * 0.30);
	// Water gets lighter where it meets the quay, which sells the basin depth.
	float shallowness = 1.0 - smoothstep(0.0, 12.0, max(p.y - shore_z, 0.0));
	body = mix(body, shallow_color * 1.15, shallowness * 0.35);

	// --- foam: quay waterline band + hull ring (one-sided, textured) ---------
	float shore_dist = p.y - shore_z;
	float shore_mask = step(0.0, shore_dist) * (1.0 - smoothstep(0.0, shore_foam_width, shore_dist));
	shore_mask *= 1.0 - smoothstep(shore_span - 4.0, shore_span, abs(p.x));
	float shore_noise = texture(foam_noise, p * 0.090 + vec2(t * 0.020, -t * 0.013)).r;
	float foam = shore_mask * smoothstep(0.52, 0.70, shore_noise) * foam_strength;

	vec2 local = p - boat_center;
	float cs = cos(boat_yaw);
	float sn = sin(boat_yaw);
	vec2 hull_p = vec2(local.x * cs - local.y * sn, local.x * sn + local.y * cs);
	float ellipse = length(hull_p / max(boat_half_size, vec2(0.01)));
	float hull_ring = smoothstep(0.93, 1.0, ellipse) * (1.0 - smoothstep(1.0, 1.0 + boat_foam_width, ellipse));
	float hull_noise = texture(foam_noise, p * 0.160 + vec2(-t * 0.030, t * 0.020)).r;
	foam += hull_ring * smoothstep(0.45, 0.75, hull_noise) * foam_strength;

	// --- compose -------------------------------------------------------------
	ALBEDO = body * 0.35;
	EMISSION = body * 0.85 + sky * reflection * 0.95 + foam_color * foam * 0.45;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.35;

	// Fade the plane edge into the horizon colour so the plane edge is invisible.
	float hfade = smoothstep(horizon_fade_start, horizon_fade_end, cam_dist);
	ALBEDO = mix(ALBEDO, horizon_color * 0.30, hfade);
	EMISSION = mix(EMISSION, horizon_color * 0.85, hfade);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ALBEDO * LIGHT_COLOR * ATTENUATION * 0.35;

	vec3 h = normalize(LIGHT + VIEW);
	float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
	// Tight sun glitter plus a soft brass sheen.
	float glint = pow(ndh, 600.0);
	float sheen = pow(ndh, 18.0) * 0.03;
	SPECULAR_LIGHT += (glint + sheen) * LIGHT_COLOR * ATTENUATION * sun_energy;
}
