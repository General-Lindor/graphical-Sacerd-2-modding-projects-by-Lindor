// just a white (1.0) mask output, but use extrusion

#define VERT_XVERTEX
#include "extractvalues.shader"

DEFINE_VERTEX_DATA


struct pixdata {
	float4 hposition  : POSITION;
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
  // extrude
  pos4.xyz += extruSize * I.normal;
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	return O;
}

fragout mainPS(pixdata I)
{
	fragout O;

	O.col = float4(1.0, 1.0, 1.0, 1.0);

	return O;
} 
