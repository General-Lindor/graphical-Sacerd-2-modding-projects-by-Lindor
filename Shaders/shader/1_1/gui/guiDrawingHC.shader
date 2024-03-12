// render a gr2 in the gui

#define VERT_XVERTEX
#include "extractvalues.shader"

DEFINE_VERTEX_DATA


struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
};

struct fragout {
	float4 col         : COLOR;
};

pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix)
{
	pixdata O;

	// pos is in unitiy space	
	float4 pos4 = float4(I.position, 1.0);

	// explode
	pos4.xy *= 50.0;

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0)
{
	fragout O;

	// turn from texcoords to radial
  float2 centered = 2.0 * (I.texcoord0.xy - float2(0.5, 0.5));
  //float radial = length(centered * centered);
  float radial = 1.0;

	// set output color
	O.col = float4(0.0, 1.0, 0.0, radial);

	return O;
} 
