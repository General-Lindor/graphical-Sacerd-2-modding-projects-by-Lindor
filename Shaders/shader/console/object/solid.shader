// ambient
#include "S2Types.shader"

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
};

#ifdef SM1_1
struct fragout {
	float4 col         : COLOR;
};
#else
struct fragout {
	float4 col[2]      : COLOR;
};
#endif

pixdata mainVS(appdata I,
	uniform float4x4 worldViewProjMatrix)
{
	pixdata O;
	
	float4 pos4 = float4(I.position.xyz, 1.0);
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	// pass texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
	uniform sampler2D texture0,
	uniform sampler2D texture1)
{
	fragout O;

#ifdef SM1_1
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	O.col = float4(tex0.xyz, 1.0);
#else
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);

	O.col[0] = float4(tex0.xyz, 1.0);
	O.col[1] = float4(tex1.a * tex0.xyz, 0.0);
#endif

	return O;
} 
