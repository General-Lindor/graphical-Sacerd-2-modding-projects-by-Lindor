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
	O.scrcoord = I.position.xyyy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D texture0,
  uniform sampler2D texture1,
  uniform sampler3D textureVolume,
  uniform float4    param)
{
	fragout O;
	
	// give usefull names
	float timing = param.x;
	
	// change lookup point
	float2 lookup_point = float2(I.texcoordGlow.x + 0.006 * sin(timing + 15.0 * I.texcoordGlow.x), I.texcoordGlow.y + 0.005 * sin(timing + 15.0 * I.texcoordGlow.y));
    
  // get original color
	s2half4 org_color   = tex2D(texture0, lookup_point);
	s2half4 glow_color  = tex2D(texture1, lookup_point);
	org_color          += glow_color;

  // put it through 3d-lookup
  float4 final_color = tex3D(textureVolume, org_color);
  // make it grey
  float grey = dot(final_color.xyz, float3(0.222, 0.707, 0.071));
  float4 grey_color = grey.xxxx;
  // green factor
  float green_factor = dot(final_color.xyz, float3(-0.5, 1.0, -0.5));
  // kick in pulsating green-factor
  float green_factor_strength = 4.5 + sin(timing);
  grey_color.g += saturate(green_factor_strength * green_factor);
  
  // out 
  O.col = grey_color;
	return O;
} 

