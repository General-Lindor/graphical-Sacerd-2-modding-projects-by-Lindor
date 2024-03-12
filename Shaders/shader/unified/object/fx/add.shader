// plasma

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
};

struct pixdata {
	float4 hposition  : POSITION;
  float4 texcoord   : TEXCOORD0;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix)
{
	pixdata O;

  // position
  float4 pos4 = float4(I.position, 1.0);
  // transform
  O.hposition = mul(pos4, worldViewProjMatrix);
  // tc's
  O.texcoord = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0)
{
	fragout O;
	
	// just sample at given location
	s2half4 add_col = tex2D(texture0, I.texcoord.xy);
	
  // out
  O.col[0] = float4(add_col.xyz, 1.0);
  O.col[1] = add_col.a * float4(add_col.xyz, 1.0);

  return O;
} 
