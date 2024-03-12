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
	float4 screenCoord  : TEXCOORD1;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4   light_pos,
  uniform float4   camera_pos,
  uniform float4   param)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * I.tangent;
	objToTangentSpace[1] = -1.0 * I.binormal;
	objToTangentSpace[2] = I.normal;
	
	// vertex-position in screen space
  O.screenCoord = calcScreenToTexCoord(O.hposition);

	// convert camera direction vector from worldspace to objectspace
	float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	// calc direction vector from vertex position to camera-position
	c_dir_obj -= pos4;

  // calc "horizon" per-vertex
  float horizon_strength = 1.0 - abs(dot(normalize(c_dir_obj.xyz), I.normal));
	
	// pass texture coords (pre multi here!)
	O.texcoord = float4(I.texcoord.xy, horizon_strength, param.y);

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform sampler2D   texture4,
  uniform sampler2D   texture6,
  uniform float4      light_col_amb,
  uniform float4      light_col_diff,
  uniform float4      param)
{
	fragout O;

  // screenpos of this pixel
	float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;

  // names
  float intensity = I.texcoord.w;
	
	// diffuse color & opacity from texture0
	s2half4 tex0 = tex2D( texture0, I.texcoord.xy );
	
	// background
	s2half4 bgr = tex2D( texture4, scr_pos );
	
  // transform color into grey...
  s2half grey = dot( bgr.xyz, float3( 0.222, 0.707, 0.071 ) );
  // ...and then colorize it via parameter
  bgr = lerp( grey * param, bgr, 0.4 );

  // lerp with opacity
  float3 amb = lerp( bgr.xyz, tex0.xyz, saturate( tex0.a + pow( I.texcoord.z, 2.0 ) ) * intensity );

  // final calc for "build-up"/"build-down" (is via alpha!)
  float alpha = saturate( I.texcoord.y );

  // screen projected texture onto blade to fake some shininess
  float4 looky = I.screenCoord;
  looky.xy *= looky.z / 10.0;
  s2half4 tex6 = tex2Dproj( texture6, looky );

  // out
  O.col[0] = float4( amb.rgb, alpha );
  O.col[1] = tex6 * 0.8 * intensity;
	
	return O;
} 

