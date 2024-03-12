// render a gr2 in the gui

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
	float4 col         : COLOR;
};

pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix)
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
    uniform sampler2D texture0)
{
	fragout O;

	// get texture values
	float4 tex0 = tex2D(texture0, I.texcoord0.xy);


	// set output color
	O.col = float4(tex0.xyz, 1.0);

	return O;
} 
