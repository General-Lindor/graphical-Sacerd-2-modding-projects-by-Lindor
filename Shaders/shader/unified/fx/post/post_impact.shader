// post render blit
#include "s2types.shader"

struct appdata {
	float3 position   : POSITION;
	float2 texcoord0  : TEXCOORD0;
	float2 texcoord1  : TEXCOORD1;
};

struct pixdata {
	float4 hposition     : POSITION;
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


float4 blur(sampler2D sourceTex, sampler3D jitterTex, float2 screenPos, float2 penSize, float2 texScale, int n)
{
	int i;
	float4 jitterOffset, blurCoord;
	float4 res;
	
	// accumulate via adding
	res = 0.0;
	// make a lot of lookups around our texel to do blur filtering
	for(i = 0; i < n; i++)
	{
		jitterOffset = (2.0 * tex3D(jitterTex, float3(texScale * screenPos, 1.0 / (float)i))) - 1.0;
		// add
    blurCoord.xy = screenPos.xy + penSize * jitterOffset.xy;
		res += tex2Dlod(sourceTex, float4(blurCoord.xy, 0.0, 0.0));
		blurCoord.xy = screenPos.xy + penSize * jitterOffset.zw;
		res += tex2Dlod(sourceTex, float4(blurCoord.xy, 0.0, 0.0));
	}
  // durchscnitt!
	res /= (2 * n);
	// this is it!
	return res;
}


fragout mainPS(pixdata I,
  uniform sampler2D texture0,
  uniform sampler2D texture1,
  uniform sampler3D textureVolume,
  uniform sampler3D jitterVolume,
  uniform float4    light_data)
{
	fragout O;
	
	// give usefull names
	float intensity = light_data.x;
	float timing = light_data.y;
    
  // get original color
	s2half4 org_color = tex2D(texture0, I.texcoordCol.xy);
	org_color        += tex2D(texture1, I.texcoordGlow.xy);

#ifdef SM1_1
  O.col = org_color;
#else
  
	// jitter from texture
  float4 jitterOffset = tex3D(jitterVolume, float3(float2(1.0, target_data.z / target_data.w) * I.texcoordCol.xy, timing)) - 0.5;
	// sample
	float4 new_color = float4(0.0, 0.0, 0.0, 0.0);
	float2 penSize = 0.03 * float2(1.0, target_data.w / target_data.z);
  float2 blurCoord = I.texcoordCol.xy + intensity * penSize * jitterOffset.xy;
#ifdef SM3_0
	new_color += tex2Dlod(texture0, float4(blurCoord, 0.0, 0.0));
#else
  new_color += tex2D(texture0, blurCoord);
#endif
	blurCoord = I.texcoordCol.xy + intensity * penSize * jitterOffset.zw;
#ifdef SM3_0
  new_color += tex2Dlod(texture0, float4(blurCoord, 0.0, 0.0));
#else
  new_color += tex2D(texture0, blurCoord);
#endif
	new_color /= 2.0;
	
	// red
	new_color *= lerp(float4(1.0, 1.0, 1.0, 1.0), float4(1.2, 0.85, 0.85, 1.0), intensity);

  // out
  O.col = tex3D(textureVolume, new_color);
#endif

	return O;
} 

