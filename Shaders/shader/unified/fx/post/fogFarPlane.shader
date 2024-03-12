
// post render blit
#include "shadow.shader"
#include "extractvalues.shader"

struct appdata {
	float3 position   : POSITION;
	float2 texcoord0  : TEXCOORD0;
	float2 texcoord1  : TEXCOORD1;
};

struct pixdata {
	float4 hposition    : POSITION;
	float4 texcoord     : TEXCOORD0;
};

struct fragout {
	float4 col[2]        : COLOR;
};


pixdata mainVS(appdata I)
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = float4(I.position.xy, 0.0, 1.0);
	// pass texture coord
	O.texcoord = I.texcoord0.xyyy;
	return O;
}

 
fragout mainPS(pixdata I,
               uniform float4    fog_color,
               uniform sampler2D depth_map,
               uniform float4    zfrustum_data)
{
	fragout O;
	float  depth_val = tex2D(depth_map, I.texcoord.xy).x;
	O.col[0]         = lerp(float4(0,0,0,0),fog_color,depth_val);
	O.col[1]         = float4(0,0,0,0);
	return O;
} 

