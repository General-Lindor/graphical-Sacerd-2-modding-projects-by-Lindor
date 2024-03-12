// just a white (1.0) mask output, but use extrusion
#include "extractvalues.shader"

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
  float2 tcs        : TEXCOORD0;
};

struct fragout {
	float4 col        : COLOR;
};


pixdata mainVS(appdata I,
	uniform float4x4 worldViewProjMatrix,
  uniform float4   param)
{
	pixdata O;

  // give usefull names
  float extruSize = param.x;
	
	float4 pos4 = float4(I.position.xyz, 1.0);
	O.hposition = mul(pos4, worldViewProjMatrix);
  O.tcs       = I.texcoord;

	return O;
}

fragout mainPS(pixdata I, uniform sampler2D texture0)
{
	fragout O;
  
	O.col = float4(1.0, 1.0, 1.0, tex2D( texture0, I.tcs ).a );

	return O;
} 
