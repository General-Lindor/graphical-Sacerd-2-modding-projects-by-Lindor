// ambient + environment

#define VERT_XVERTEX
#include "extractvalues.shader"

DEFINE_VERTEX_DATA


struct pixdata {
	float4 hposition    : POSITION;
	float4 texcoord0    : TEXCOORD0;
	float4 camDist      : TEXCOORD1;
	float4 tan_to_wrld0 : TEXCOORD2;
	float4 tan_to_wrld1 : TEXCOORD3;
	float4 tan_to_wrld2 : TEXCOORD4;
};

struct fragout {
	float4 col      : COLOR;
};


pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldMatrix,
    uniform float4   camera_pos)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);
	
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// need matrix to convert from tangent-space to obj-space
	float3x3 tangent_to_obj;
	tangent_to_obj[0] = -1.0 * I.tangent;
	tangent_to_obj[1] = -1.0 * I.binormal;
	tangent_to_obj[2] = I.normal;
	
	// need matrix to convert from tangentspace to worldspace
	float3x3 tangent_to_world;
	tangent_to_world = mul(tangent_to_obj, worldMatrix);
	
	// pass to fragment
	O.tan_to_wrld0 = float4(tangent_to_world[0], 0.0);
	O.tan_to_wrld1 = float4(tangent_to_world[1], 0.0);
	O.tan_to_wrld2 = float4(tangent_to_world[2], 0.0);

	// convert camPosition into world-space and make it direction
	O.camDist = camera_pos - mul(pos4, worldMatrix);
	
	// pass texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler2D   texture3,
    uniform sampler2D   texture4,
    uniform samplerCUBE textureCube,
    uniform sampler3D   textureVolume,
	uniform float4      system_data,
	uniform float4      light_col_amb)
{
	fragout O;

	// fetch
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy); // diffuse + opacity
/*	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy); // tenergy data 1
	s2half4 tex2 = tex2D(texture2, I.texcoord0.xy); // tenergy data 2
	s2half4 tex3 = tex2D(texture3, I.texcoord0.xy); // normal
	s2half4 tex4 = tex2D(texture4, I.texcoord0.xy); // specular + glow
	
	// bump normal needed for env lookup
	s2half2 partNrm = 2.0 * (tex3.xy - float2(0.5, 0.5));
	s2half3 nrm_tan = s2half3(partNrm, sqrt(1.0 - partNrm.x * partNrm.x - partNrm.y * partNrm.y));
	
	// build matrix to tranform from tangent to world-space
	float3x3 tangent_to_world;
	tangent_to_world[0] = I.tan_to_wrld0.xyz;
	tangent_to_world[1] = I.tan_to_wrld1.xyz;
	tangent_to_world[2] = I.tan_to_wrld2.xyz;
	
	// transform normal to worldspace
	s2half3 nrm_wrld = mul(nrm_tan, tangent_to_world);
	
	// calc reflection
	float3 camDir = normalize(I.camDist.xyz);*/
//	s2half4 env_color = /*light_col_amb * */texCUBE(textureCube, reflect(-camDir, nrm_wrld));
	
/*	int i, octaves = 3;
	float ampi = 0.652;
	float ampm = 0.408;
	float freqi = 0.94;
	float freqm = 2.88;
	float freq = freqi;
	float amp = ampi;
	float4 sum_col = float4(0.0, 0.0, 0.0, 0.0);
	
	for(i = 0; i < octaves; i++)
	{
		sum_col += amp * tex3D(textureVolume, float3(freq * I.texcoord0.xy, 0.02 * system_data.x));
		freq *= freqm;
		amp *= ampm;	
	}

	// define the border between fluid-metal and t-energy
	const float t_e_border = 0.3;
	
	// look up in color-fade texture
	float4 perlin_col = tex2D(texture2, sum_col.xy);

	// standard or sub for base layer?
	float4 final_color, final_glow;
	if(sum_col.x < t_e_border)
	{
		final_color = perlin_col;
		final_glow = perlin_col.w * perlin_col;
	}
	else
	{
		final_color = env_color;
		final_glow = float4(0.0, 0.0, 0.0, 0.0);
	}

	// compose	
	O.col = final_color + tex4.w * tex0;
	O.col.a = tex0.a;*/
	O.col = tex0;

	return O;
} 

