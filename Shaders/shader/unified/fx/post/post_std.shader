// post render blit
#include "s2types.shader"

struct appdata {
	float3 position   : POSITION;
	float2 texcoord0  : TEXCOORD0;
	float2 texcoord1  : TEXCOORD1;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoordCol   : TEXCOORD0;
	float4 texcoordGlow  : TEXCOORD1;
	float4 scrcoord      : TEXCOORD2;
};

struct fragout {
	float4 col        : COLOR;
};


pixdata mainVS(appdata I)
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = float4(I.position.xy, 0.0, 1.0);
	// pass texture coord
	O.texcoordGlow   = I.texcoord0.xyyy;
	O.texcoordCol    = I.texcoord0.xyyy;
	O.texcoordCol.xy = (O.texcoordCol.xy-viewport_data.xy)*viewport_data.zw;
	// pass screen coord
	O.scrcoord    = I.position.xyyy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D texture0,
  uniform sampler2D texture1,
  uniform sampler3D textureVolume)
{
	fragout O;
    
  // get original color
	s2half4 org_color   = tex2D(texture0, I.texcoordCol.xy);
	s2half4 glow_color  = tex2D(texture1, I.texcoordGlow.xy);
	org_color          += glow_color;

  float4 final_color = tex3D( textureVolume, org_color );
  // out 
  O.col = final_color;// * (1.0 + param.z * saturate(2.0 * (1.0 - saturate(length(I.scrcoord.xy)))));
	return O;
} 

