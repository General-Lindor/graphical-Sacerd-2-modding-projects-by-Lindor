// glass
#include "extractvalues.shader"

struct appdata {
	float3 position     : POSITION;
	float3 normal       : NORMAL;
	float3 tangent      : TANGENT;
	float3 binormal     : BINORMAL;
	float2 texcoord     : TEXCOORD0;
	float2 data         : TEXCOORD1;
};

struct pixdata {
	float4 hposition    : POSITION;
	float4 texcoord     : TEXCOORD0;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4   camera_pos,
  uniform float4   param)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float extruSize = param.x;

  // extrude
  pos4.xyz += extruSize * I.normal;
	
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// convert camera direction vector from worldspace to objectspace
	float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	// calc direction vector from vertex position to camera-position
	c_dir_obj -= pos4;

  // calc "horizon" per-vertex
  float horizon_strength = 1.0 - abs(dot(normalize(c_dir_obj.xyz), I.normal));
	
	// pass texture coords (pre multi here!)
	O.texcoord = float4(I.texcoord.xy, horizon_strength, 0.0);

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform float4      target_data,
  uniform float4      system_data)
{
	fragout O;

  // give usefull names
  float plasma_size = 0.01;
  float plasma_speed = 0.001;
  float plasma_sharpness = 0.8;

	// get noise from texture
	// determine lookup points
	float2 lup = plasma_size * I.texcoord.xy;
	float2 lup1 = lup + plasma_speed * system_data.xx;
	float2 lup2 = lup - plasma_speed * system_data.xx;
	float4 noi1 = tex2D(texture0, lup1);
	float4 noi2 = tex2D(texture0, lup2);
	// halfspace
	float noi = abs(2 * (noi1.x + noi2.x) / 2 - 1);
	// make slimmer
	float pl = saturate(pow((1.0 - noi), plasma_sharpness));
	
	// horizon
	float horizon_strength = I.texcoord.z;
	
	// turn into cool gradient via texture
	s2half4 grad_col1 = tex2D(texture1, float2(horizon_strength, 0.0));
	s2half4 grad_col2 = tex2D(texture1, float2(0.85 * pl, 0.0));
	
	O.col[0] = float4(0.35 * grad_col1.xyz + 0.2 * grad_col2.xyz, 1.0);
	O.col[1] = float4(0,0,0,0);
	return O;
} 

