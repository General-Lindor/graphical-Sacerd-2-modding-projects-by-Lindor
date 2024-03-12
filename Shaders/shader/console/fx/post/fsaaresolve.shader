// post render blit
#include "S2Types.shader"

struct appdata {
	float3 position   : POSITION;
	float2 texcoord0  : TEXCOORD0;
	float2 texcoord1  : TEXCOORD1;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord   : TEXCOORD0;
};

struct fragout {
	float4 col        : COLOR;
};


pixdata mainVS(appdata I,
               uniform float4    vtx_data_array[3])
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = float4(I.position.xy, 0.0, 1.0);
	// pass texture coord
	O.texcoord.xy  = (I.position.xy+float2(1,-1))*float2(0.5,-0.5);
	O.texcoord.zw  = float2(0,0);
	
	O.texcoord += vtx_data_array[2];

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D texture0,
  uniform sampler2D texture1,
  uniform float4    pix_data_array[3])
{
	fragout O;
  // get original color
  float4 texcoord = I.texcoord;
	float4 sample1  = tex2D(texture0, texcoord.xy+pix_data_array[0]);
	float4 sample2  = tex2D(texture0, texcoord.xy-pix_data_array[0]);
	float4 sample3  = tex2D(texture0, texcoord.xy+pix_data_array[1]);
	float4 sample4  = tex2D(texture0, texcoord.xy-pix_data_array[1]);
	
  // out 
  O.col = (sample1+sample2+sample3+sample4)*0.25;
	return O;
} 

