//#OptDef:LAYER_BIT0

#ifdef LAYER_BIT0
  #define STREAK_SHADER
#endif

// particles
#include "extractvalues.shader"
struct appdata {
	float3 position   : POSITION;
	float4 texcoord   : TEXCOORD0;
	float2 data       : TEXCOORD1;
	float4 color      : COLOR0;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
	float4 color      : COLOR0;
//	float4 brightness : COLOR1;
};



pixdata mainVS( appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldMatrix,
    uniform float4   vtx_data_array[4] )
{
	pixdata O;
	
	float4 pos4 = float4(I.position.xyz, 1.0);

	// transform center of particle into view-space
  // we need two separate matrices as streaks are already in world space
	pos4 = mul(pos4, worldMatrix);

	// offset to this vertex to get billboard
	float4 offset = I.texcoord.z * vtx_data_array[I.texcoord.w];

	// rotate this offset to get rotated particles
	float2x2 screenRotation;
	screenRotation[0] = float2(cos(I.data.x), sin(I.data.x));
	screenRotation[1] = float2(-sin(I.data.x), cos(I.data.x));
	offset.xy = mul(offset.xy, screenRotation);

	// offset! vertex
	pos4 += offset;

	// transform into proj-space
	O.hposition = mul(pos4, worldViewProjMatrix);

	// pass texture coords & color & brightness
	O.texcoord0 = I.texcoord.xyyy;
	O.color = (I.color + I.color.a * I.data.yyyy);
#ifdef STREAK_SHADER
	 O.color.rgba *= I.color.a;
#endif

//	O.color = I.color;
//  O.brightness = I.data.yyyy;

	return O;
}

fragout_t mainPS(pixdata I,
    uniform sampler2D texture0)
{
  fragout_t O;
  // greyscale sprite
  float4 tex0 = tex2D(texture0, I.texcoord0.xy);
//  float4 final_col = (I.color + I.color.a * I.brightness) * tex0;
  float4 final_col = I.color * tex0;
  set_out_color( final_col );
  set_out_glow(float4(0.0, 0.0, 0.0, 0.0));
  return O;
} 


