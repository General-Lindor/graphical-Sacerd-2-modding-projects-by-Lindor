// render shadows into shadowtexture

struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float2 texcoord   : TEXCOORD0;
	float2 data       : TEXCOORD1;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
	float4 posInLight : TEXCOORD1;
};

struct fragout {
	float4 col        : COLOR;
};

#include "shadow.shader"

pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 lightMatrix)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	// vertex pos in light-space
	O.posInLight = mul(pos4, lightMatrix);
	// adjust a little bit
	O.posInLight.xy = 0.5 * O.posInLight.xy + float2(0.5, 0.5);
	O.posInLight.y = 1.0 - O.posInLight.y;

	// texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D shadow_map,
    uniform sampler2D color_map,
    uniform sampler3D textureVolume,
    uniform int anzIterations,
    uniform float4 shadow_data)
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

	// shadow mapping
	float shadow = calcShadow(shadow_map, textureVolume, I.posInLight, float2(0.0, 0.0), shadow_data.y, shadow_data.x, anzIterations);

	// get color/depth from projected color map
  s2half4 color = tex2Dproj(color_map, I.posInLight);

  /*
  float4 cmap = tex2Dproj(color_map, I.posInLight);
  float depth = cmap.w;
	float3 color;

  if(I.posInLight.z / 5000.0 < depth)
    color = shadow.xxx;
  else
    color = shadow * cmap.xyz;

    */

	// set output shadow "color"
	O.col = float4(shadow * color.xyz, tex0.a);

	return O;
} 
