shader_type canvas_item;

varying vec4 instance_c;

// Default cell flags:
const int CFL_ACCESSIBLE = 1 << 0;
const int CFL_REACHABLE = 1 << 1;
const int CFL_IN_VOID = 1 << 2;
const int CFL_HOVERED = 1 << 3;
const int CFL_SELECTED  = 1 << 4;
const int CFL_PATH = 1 << 5;
const int CFL_VISIBLE = 1 << 6;

void vertex() {
	instance_c = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = tex * instance_c;
}