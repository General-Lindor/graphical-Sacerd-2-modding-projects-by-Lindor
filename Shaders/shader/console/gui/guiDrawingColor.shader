// gui Drawing Xenon
#include "S2Types.shader"

struct appdata {
	float3 position   : POSITION;
	float2 texcoord0  : TEXCOORD0;
};

struct pixdata {
	float4 hposition  : POSITION;
	float2 texcoord0  : TEXCOORD0;
}; 

struct fragout {
	float4 col        : COLOR;
};

pixdata mainVS( appdata I, uniform float4x4 worldViewMatrix, uniform float4x4 projMatrix )
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = mul( float4(I.position.xy, 0.0, 1.0), worldViewMatrix );
	O.hposition = mul( O.hposition, projMatrix );
	// only have one texture coord
	O.texcoord0 = I.texcoord0;

	return O;
}

fragout mainPS(pixdata	I,
	uniform float4	light_col_amb,
	uniform sampler2D texture0)
{
	fragout O;

	O.col = light_col_amb * tex2D(texture0, I.texcoord0);

	return O;
} 
