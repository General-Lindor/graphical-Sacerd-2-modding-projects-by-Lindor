#include "extractvalues.shader"
// discettes

struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float2 texcoord   : TEXCOORD0;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord   : TEXCOORD0;
};

#define PI 3.1415926535897932384626433832795

pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4   vtx_data_array[3])
{
	pixdata O;
	
	// give usefull names
	float alpha = I.position.x;
	float in_out = I.position.z;
	float i_radius1 = vtx_data_array[0].x;
	float i_radius2 = vtx_data_array[0].y;
	float o_radius1 = vtx_data_array[0].z;
	float o_radius2 = vtx_data_array[0].w;
	float uOffset = vtx_data_array[1].x;
	float uStretch = vtx_data_array[1].y;
	float intensity = vtx_data_array[1].z;
	float full_circle = vtx_data_array[1].w;
	float glow_intensity = vtx_data_array[2].x;
	
	// pre-calc trigonometric
	float sin_a = sin(full_circle * alpha);
	float cos_a = cos(full_circle * alpha);
	
	// calc ellipse radiuses (inner and outer!)
	float2 i_pos = float2(i_radius1 * cos_a, i_radius2 * sin_a);
	float2 o_pos = float2(o_radius1 * cos_a, o_radius2 * sin_a);
	
	// inner or outer
	float2 pos2 = lerp(i_pos, o_pos, in_out);
	
	// calc position
	float4 pos4 = float4(pos2, 0.0, 1.0);

	// transform from fx-space into proj-space
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// texcoords just circular mapping
	O.texcoord = float4(uStretch * (alpha / (2.0 * PI) - uOffset), in_out, intensity, glow_intensity);

	return O;
}

fragout_t mainPS(pixdata I,
		uniform sampler2D texture0)
{
	fragout_t O;
	
	// sample
	s2half4 tex0 = tex2D(texture0, I.texcoord.xy);
	
	// color is with intensity!
	s2half4 col = I.texcoord.z * tex0;
	
	set_out_color(col);
	set_out_glow(I.texcoord.w * tex0.a * col);
	
	return O;
} 
