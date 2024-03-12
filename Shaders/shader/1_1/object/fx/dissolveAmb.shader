// ambient dissolve

#define VERT_XVERTEX
#include "extractvalues.shader"

DEFINE_VERTEX_DATA


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
  uniform sampler3D textureVolume,
	uniform float4    system_data,
	uniform float4    param,
	uniform float4    light_col_amb)
{
	fragout O;

	// fetch
	float4 tex0 = tex2D(texture0, I.texcoord0.xy);

/*	int i, octaves = 3;
	float ampi = 0.652;
	float ampm = 0.408;
	float freqi = 0.94;
	float freqm = 2.88;
	float freq = freqi;
	float amp = ampi;
	float4 sum_col = float4(0.0, 0.0, 0.0, 0.0);
	
	for(i = 0; i < octaves; i++)
	{
		sum_col += amp * tex3D(textureVolume, float3(freq * I.texcoord0.xy, 0.01 * system_data.x));
		freq *= freqm;
		amp *= ampm;	
	}
  // lut
  float4 diss_col = tex2D(texture4, saturate(float4(6.0 * sum_col.xyz / param.x, 0.0)));

	O.col = light_col_amb * diss_col;
	O.col.a = tex0.a;*/
	O.col = tex0;

	return O;
} 
