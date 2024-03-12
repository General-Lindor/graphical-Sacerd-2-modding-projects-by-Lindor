// gui 2d drawing
#include "S2Types.shader"

struct appdata {
	float  index      : TEXCOORD0;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
	float4 light_dir  : TEXCOORD1;
};

struct fragout {
	float4 col        : COLOR;
};

pixdata mainVS(appdata I,
    uniform float4   vtx_data_array[4],
    uniform float4   light_pos)
{
	pixdata O;

	// all data is in array
	float4 data = vtx_data_array[I.index];

	// vertex pos already transformed
	O.hposition = float4(data.xy, 1.0, 1.0);
	// only have one texture coord
	O.texcoord0 = float4(data.zw, 0.0, 0.0);
  // pass light_dir to fragment
	O.light_dir = light_pos;

	return O;
}

fragout mainPS(pixdata I,
	uniform sampler2D texture0,
	uniform sampler2D texture1,
	uniform sampler2D texture2)
{
	fragout O;

  // textures
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	s2half4 tex2 = tex2D(texture2, I.texcoord0.xy);

  // normal
  s2half3 nrm = normalize(tex1.xyz - s2half3(0.5, 0.5, 0.5));
  // ambient
  s2half3 amb = tex0.xyz * tex2.x;
  // diffuse
  s2half3 diffuse = tex0.xyz * saturate(dot(nrm, I.light_dir.xyz));
  // specular
  s2half3 specular = pow(saturate(dot(normalize(float3(0.0, 0.0, 1.0) + I.light_dir.xyz), nrm)), 20) * tex2.yyy;
  // glow
  s2half3 glow = tex1.w * tex0.xyz;

  // out
  O.col = float4(specular + diffuse + glow + amb, tex0.a);
	return O;
} 
