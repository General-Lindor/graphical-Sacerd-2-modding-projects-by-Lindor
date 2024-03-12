// particles
#include "extractvalues.shader"
struct appdata {
	float3 position   : POSITION;
	float4 texcoord   : TEXCOORD0;
	float4 data       : TEXCOORD1;
	float4 color      : COLOR0;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
};

struct fragout {
	s2half4 col        : COLOR;
#ifdef PS3_IMPL
	s2half4 col1        : COLOR1;
        s2half4 colCopy   : COLOR2;
#endif	
};


pixdata mainVS(appdata I,
	uniform float4x4 worldViewProjMatrix,
	uniform float4x4 worldMatrix,
	uniform float4   param,
	uniform float4   vtx_data_array[4])
{
	pixdata O;

  // give usefull names
  float rotation = param.z;
	
	float4 pos4 = float4(I.position.xyz, 1.0);

	// transform center of particle into view-space
	pos4 = mul(pos4, worldMatrix);

	// offset to this vertex to get billboard
	float4 offset = param.x * vtx_data_array[I.texcoord.w];
	
	// rotate this offset to get rotated lensflares!
	float2x2 screenRotation;
	screenRotation[0] = float2(cos(rotation), sin(rotation));
	screenRotation[1] = float2(-sin(rotation), cos(rotation));
	offset.xy = mul(offset.xy, screenRotation);

  // move a little bit closer to camera to avoid z-cutting
  offset += float4(0.0, 0.0, param.y, 0.0);

	// offset! vertex
  pos4 += offset;

	// transform into proj-space
	O.hposition = mul(pos4, worldViewProjMatrix);

	// pass texture coords & color
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
	uniform sampler2D texture0,
	uniform float4 light_col_amb)
{
	fragout O;

	O.col = light_col_amb * tex2D(texture0, I.texcoord0.xy);
#if defined(SM1_1)
  O.col.a = 1;
#endif	
#ifdef PS3_IMPL
 O.col1=s2half4(0,0,0,0);
 O.colCopy=s2half(O.col);
#endif 
	return O;
} 
