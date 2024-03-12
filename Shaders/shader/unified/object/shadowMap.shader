// granny2 object shadowmap

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
	float4 col        : COLOR;
};

pixdata mainVS(appdata I,
    uniform float4x4 lightMatrix)
{
	pixdata O;
	float4 pos4 = float4(I.position, 1.0);

	// vertex pos
	O.hposition = mul(pos4, lightMatrix);

	// pass texcoords to fragment shader
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform float4 shadow_data)
{
	fragout O;
#ifdef IS_OPAQUE 
	O.col = float4( 0,0,0,1 );
#else
  #ifdef SM1_1
	  O.col = float4(shadow_data.zzz, tex2D(texture0, I.texcoord0.xy).a);
  #else
    O.col = tex2D(texture0, I.texcoord0.xy);
    clip(O.col.a-0.5f);
  #endif
#endif
	return O;
} 
