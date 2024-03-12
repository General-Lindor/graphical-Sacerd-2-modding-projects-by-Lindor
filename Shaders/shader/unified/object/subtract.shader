// granny2 object subtract lighting

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

pixdata mainVS(appdata I,
    uniform float4x4 lightMatrix)
{
	pixdata O;
	float4 pos4 = float4(I.position, 1.0);

	// vertex pos
	O.hposition = mul(pos4, lightMatrix);
	// vertex pos in light-space
	O.posInLight = O.hposition;

	// pass texcoords to fragment shader
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0)
{
	fragout O;

	// color for subtraxtion comes from diffuse
	float4 tex0 = tex2D(texture0, I.texcoord0.xy);

	// build color from 0.0 via tex0.rgb via 1.0
  s2half3 col = tex0.xyz;
  s2half3 inv_col = float3(1.0, 1.0, 1.0) - col;
  s2half f1 = saturate(2.0 - 2.0 * tex0.a);
  s2half f2 = saturate(1.0 - 2.0 * tex0.a);
	// and out
	O.col = float4(f1 * col + f2 * inv_col, 1.0);

	return O;
} 
