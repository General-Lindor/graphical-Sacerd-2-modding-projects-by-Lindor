// ambient dissolve

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

struct fragout {
	float4 col      : COLOR;
};


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
	uniform sampler2D texture4,
	uniform sampler2D texture5,
	uniform float4    system_data,
	uniform float4    param)
{
	fragout O;

	float4 tex0 = tex2D(texture0, I.texcoord0.xy);

/*	float time = param.x;
	float uvroll = param.y;
	float strength = param.z;
	float4 col = 0.75 * tex2D(texture5, float2((0.94 + (uvroll / 10.0f)) * I.texcoord0.xy));
	float4 diss_col = tex2D(texture4, saturate(float4(6.0 * col.xyz / strength, 0.0)));

	O.col = diss_col;*/
	O.col.xyz = tex0.rgb;
	O.col.a = 1.0f;

	return O;
} 
