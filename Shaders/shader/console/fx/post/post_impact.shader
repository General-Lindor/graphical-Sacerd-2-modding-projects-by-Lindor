// post render blit
#include "s2types.shader"

float4 mainVS( float4 pos : POSITION ) : POSITION
{
	return pos;
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


s2half4 mainPS(float2    vPos : VPOS,
       uniform sampler2D texture0,
       uniform sampler2D texture1,
       uniform sampler3D textureVolume,
       uniform sampler3D jitterVolume,
       uniform float4    light_data ) : COLOR
{
	s2half2 vTexCoord = (vPos+s2half2(0.5,0.5))*target_data.zw;

	s2half4 org_color   = tex2D(texture0, vTexCoord);

	//apply glow
	s2half4 glow = tex2D(texture1, vTexCoord);
	org_color.rgb = org_color*glow.a+glow;

	// give usefull names
	float intensity = light_data.x;
	float timing = light_data.y;

	// jitter from texture
	float4 jitterOffset = tex3D(jitterVolume, float3(float2(1.0, target_data.z / target_data.w) * vTexCoord, timing)) - 0.5;
	// sample
	float4 new_color = float4(0.0, 0.0, 0.0, 0.0);
	float2 penSize = 0.03 * float2(1.0, target_data.w / target_data.z);
	float2 blurCoord = vTexCoord.xy + intensity * penSize * jitterOffset.xy;
	new_color += tex2Dlod(texture0, float4(blurCoord, 0.0, 0.0));
	blurCoord = vTexCoord.xy + intensity * penSize * jitterOffset.zw;
	new_color += tex2Dlod(texture0, float4(blurCoord, 0.0, 0.0));
	new_color /= 2.0;

	// red
	new_color *= lerp(float4(1.0, 1.0, 1.0, 1.0), float4(1.2, 0.85, 0.85, 1.0), intensity);

  // out
  return tex3D(textureVolume, new_color);
} 

