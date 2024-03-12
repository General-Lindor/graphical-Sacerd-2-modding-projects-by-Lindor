#include "extractvalues.shader"
// null

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
};


pixdata mainVS(appdata I)
{
	pixdata O;
	O.hposition = float4(0.0, 0.0, 0.0, 0.0);
	return O;
}

fragout_t mainPS(pixdata I)
{
	fragout_t O;
	set_out_color(float4(0.0, 0.0, 0.0, 0.0));
	set_out_glow(float4(0.0, 0.0, 0.0, 0.0));
	return O;
} 
