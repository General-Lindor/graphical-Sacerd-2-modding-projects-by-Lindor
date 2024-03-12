// particles
#include "extractvalues.shader"
struct appdata {
	float3 position    : POSITION;
	float4 texcoord    : TEXCOORD0;
	float4 data        : TEXCOORD1;
	float4 color       : COLOR0;
};

struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
  float4 screenCoord : TEXCOORD1;
};

struct fragout {
	float4 col        : COLOR;
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

  O.screenCoord = calcScreenToTexCoord(O.hposition);

	return O;
}

fragout mainPS(pixdata I,
	uniform sampler2D texture0,
	uniform sampler2D texture1,
	uniform sampler2D texture2,
  uniform float4    param)
{
	fragout O;
	
	// give usefull names
	float intensity = param.x;
	
	// sample lensflare texture
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	
//	float2 scr_offset = (I.screenCoord.z / I.screenCoord.w) * target_data.zw * normalize(I.circ_pos.xy) * tex0.x * intensity * cau.x;
	float2 scr_offset = intensity * (I.screenCoord.z / I.screenCoord.w) * target_data.zw * (tex0.xy - s2half2(0.5, 0.5));
	// screenpos of this pixel
	float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;
	// offset due to refraction and distance!
	float2 offs_scr_pos = scr_pos + scr_offset;
	
	// transparency <-> opaque mask
	s2half4 t_mask = tex2D(texture2, offs_scr_pos);
	
	// offset'ed background
	s2half4 offs_bgr = tex2D(texture1, offs_scr_pos);
	// non-offset'ed background
	s2half4 nonoffs_bgr = tex2D(texture1, scr_pos);
	
	// lerp with mask
	s2half4 bgr = lerp(nonoffs_bgr, offs_bgr, t_mask.x);

	O.col = float4(bgr.xyz, 1.0);
#if defined(SM1_1)
  O.col.a = 1;
#endif	
	return O;
} 
