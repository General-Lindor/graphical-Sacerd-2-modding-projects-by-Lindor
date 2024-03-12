//#OptDef:S2_FOG

// standard
#define VERT_XVERTEX
#include "extractvalues.shader"



DEFINE_VERTEX_DATA


struct pixdata {
	float4 hposition   : POSITION;
	float4 diffuse     : COLOR0;
	float2 texcoord0   : TEXCOORD0;
#ifdef S2_FOG
  float fog    : FOG;
#endif
};

struct fragout {
	float4 col      : COLOR;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 worldMatrix,
  uniform float4   camera_pos,
  uniform lightData globLightData,
  uniform float4 fog_data)
{
	pixdata O;

	EXTRACT_VERTEX_VALUES;

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// texture coords
	O.texcoord0.xy = uv0.xy;

	O.diffuse = float4(1.0f, 1.0f, 1.0f, 1.0f);

#ifdef S2_FOG
  O.fog = calcFog(O.hposition, fog_data);
#endif

	return O;
}


fragout mainPS(pixdata I,
    uniform sampler2D texture0)
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0);

	O.col.rgb = float3(0.0f, 0.0f, 0.0f);
	O.col.a = tex0.a * I.diffuse.a;

	return O;
}
