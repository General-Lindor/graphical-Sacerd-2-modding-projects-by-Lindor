// dr fluch
#include "extractvalues.shader"

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
  uniform float4 pix_data_array[4],
  uniform float4 param,
  uniform sampler2D texture0)
{
	fragout O;
	int i;
	
	// get overlay texture
	s2half4 linesTex = tex2D(texture0, 8.f * I.texcoord.xy);
	
	float power = 0.0;
	for(i = 0; i < 4; i++)
	{
    // patch timer
	  float timer = pix_data_array[i].z;
  	// delta
	  float uv_dist = length(pix_data_array[i].xy - I.texcoord.xy);
  	float fio = sin(3.141592653589 * timer);
	  power += fio * (1.0 - smoothstep(0.0, 0.1, uv_dist));
	}
	
  // out
  O.col[0] = float4(power * linesTex.xyz, 1.0);
  O.col[1] = float4(power * linesTex.xyz, 0.0);
  
  return O;
} 
