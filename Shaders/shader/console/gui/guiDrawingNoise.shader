// gui Drawing
#include "S2Types.shader"

struct appdata {
	float3 position   : POSITION;
	float4 texcoord0  : TEXCOORD0;
	float4 color      : COLOR0;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
	float4 hpos       : TEXCOORD1;
	float4 color      : COLOR0;
};

struct fragout {
	float4 col        : COLOR;
};

pixdata mainVS(appdata I)
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = float4(I.position.x, I.position.y, 0.0, 1.0);
	// only have one texture coord
	O.texcoord0 = I.texcoord0.xyyy;
	// pass screenpos to fragment shader
	O.hpos = float4((I.position.x + 1.0) * 0.5, (1.0 - I.position.y) * 0.5, 0.0, 0.0);
	// pass color
	O.color = I.color;

	return O;
}

fragout mainPS(pixdata I,
	uniform float4    param,
	uniform sampler2D texture0,
	uniform sampler2D texture1,
	uniform sampler2D texture2)
{
	fragout O;

	// calc color
	float4 col = tex2D(texture0, I.texcoord0.xy);
	// get noise from texture
	float4 nse = tex2D(texture1, I.hpos.xy * param.w + param.yz);
	// get scanlines from texture
	float4 scl = tex2D(texture2, I.hpos.xy * param.w);
	// multi
	O.col = I.color * col;
	O.col.a *= saturate(nse.x + 0.2) * scl.x;

	return O;
} 
