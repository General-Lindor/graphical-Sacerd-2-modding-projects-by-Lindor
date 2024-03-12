// impact effect
#include "extractvalues.shader"

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
};

struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
};

struct fragout {
	float4 col[2]      : COLOR;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D texture1,
    uniform sampler2D texture2,
    uniform sampler3D textureVolume,
    uniform float4    system_data,
    uniform float4    param)
{
	fragout O;

  // give usefull names
  float intensity = param.x;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	s2half4 tex2 = tex2D(texture2, I.texcoord0.xy);

  // get animated normal
  s2half4 tex_v = tex3D(textureVolume, float3(3.0 * I.texcoord0.xy, 2.0 * system_data.x));

  // lerp between goo and normal
  float3 out0 = intensity * tex_v.xyz;
  float3 out1 = float3(0.0, 0.0, 0.0);

	// set output color
	O.col[0].rgb = out0;
	O.col[0].a = tex0.a;
	O.col[1].rgb = out1;
	O.col[1].a = tex0.a;

  return O;
} 
