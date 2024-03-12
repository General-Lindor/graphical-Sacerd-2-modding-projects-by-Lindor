// ambient

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

	return O;
}

fragout mainPS(pixdata I)
{
	fragout O;
	O.col[0] = float4(0,0,0,0);
	O.col[1] = float4(0,0,0,0);
	return O;
} 
