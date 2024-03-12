// simple adding with fader

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
  uniform float4      param,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1)
{
	fragout O;
	
  // give usefull names
  float full_fader = param.x;
  float overlay_fader = param.y;
  float2 overlay_offset = param.zw;

  // just sample at given location
  s2half4 add_col = tex2D(texture0, I.texcoord.xy);
  
  // and sample overlay at offset'ed location
  s2half4 overlay_col = tex2D(texture1, I.texcoord.xy + overlay_offset);
	
  // out
  O.col[0] = float4(full_fader * (add_col.xyz + overlay_fader * overlay_col.xyz), 1.0);
  O.col[1] = float4(add_col.a * full_fader * add_col.xyz + overlay_col.a * overlay_fader * overlay_col.xyz, 1.0);

  return O;
} 
