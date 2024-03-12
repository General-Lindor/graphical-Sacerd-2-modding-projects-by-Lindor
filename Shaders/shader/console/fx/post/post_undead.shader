// post render blit
#include "s2types.shader"

float4 mainVS( float4 pos : POSITION ) : POSITION
{
	return pos;
}


s2half4 mainPS(float2    vPos : VPOS,
       uniform sampler2D texture0,
       uniform sampler2D texture1,
       uniform sampler3D textureVolume,
       uniform float4    param) : COLOR
{
	s2half2 vTexCoord = (vPos+s2half2(0.5,0.5))*target_data.zw;
	
	// give usefull names
	float timing = param.x;
	
	// change lookup point
	float2 lookup_point = float2(vTexCoord.x + 0.006 * sin(timing + 15.0 * vTexCoord.x), vTexCoord.y + 0.005 * sin(timing + 15.0 * vTexCoord.y));
    
	s2half4 org_color   = tex2D(texture0, vTexCoord);

	//apply glow
	s2half4 glow = tex2D(texture1, vTexCoord);
	org_color.rgb = org_color*glow.a+glow;
	
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
  return grey_color;
} 

