// effect on sera wings

#define VERT_XVERTEX
#include "extractvalues.shader"

DEFINE_VERTEX_DATA


struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
	float4 texcoord1   : TEXCOORD1;
	float4 screenCoord : TEXCOORD2;
};

struct fragout {
	float4 col      : COLOR;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// vertex-position in screen space
	O.screenCoord.x = O.hposition.w + O.hposition.x;
	O.screenCoord.y = O.hposition.w - O.hposition.y;
	O.screenCoord.z = O.hposition.z;
	O.screenCoord.w = 2.0 * O.hposition.w;
	O.screenCoord.xy *= target_data.xy;
	
	// pass texture coords
	O.texcoord0 = I.texcoord.xyyy;
	O.texcoord1 = I.data.xyyy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform float4      system_data)
{
	fragout O;

	// color
	s2half4 tex0 = tex2D(texture0, I.texcoord1.xy);
/*
  // move noise entry coords
  float2 noise_coords = I.texcoord0.xy;

  // calc noise
  float2 lup = float2(0.13, 0.13) * noise_coords;
	float2 lup1 = lup + 0.005 * system_data.xx;
	float2 lup2 = lup - 0.005 * system_data.xx;
	float4 noi1 = tex2D(texture1, lup1);
	float4 noi2 = tex2D(texture1, lup2);
	// halfspace
	float noi = abs((noi1.x + noi2.x) - 1);
	// make slimmer
	float pl = pow((1.0 - noi), 10.0 * (1.0 - I.texcoord1.y));

  // pulse factor pulsing between 0.6 and 1.0
  float pulse_factor = 0.8 + 0.2 * sin(6.283185 * frac(0.35 * system_data.x));

  // get plasma color from tex0
  float3 plasma_col_a = pow(I.texcoord1.y, 0.8) * pl * tex0.xyz + 2.0 * pow(I.texcoord1.y, pulse_factor * 5.0) * tex0.xyz;
  float3 plasma_col_g = 0.5 * pow(I.texcoord1.y, pulse_factor * 5.0) * tex0.xyz;
	
	O.col = float4(plasma_col_a, 1.0);*/
	O.col = tex0;

	return O;
} 
