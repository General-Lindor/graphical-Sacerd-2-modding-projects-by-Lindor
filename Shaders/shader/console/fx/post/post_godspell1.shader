// post render blit for godspell1
#include "s2types.shader"

float4 mainVS( float4 pos : POSITION ) : POSITION
{
	return pos;
}

s2half4 mainPS(float2    vPos : VPOS,
       uniform sampler2D texture0,
       uniform sampler2D texture1,
       uniform sampler2D texture3,
       uniform sampler3D textureVolume,
       uniform float4    pix_data_array[2]) : COLOR
{
	s2half2 vTexCoord = (vPos+s2half2(0.5,0.5))*target_data.zw;

	s2half4 org_color   = tex2D(texture0, vTexCoord);

	//apply glow
	s2half4 glow = tex2D(texture1, vTexCoord);
	org_color.rgb = org_color*glow.a+glow;
	
	// get usefull names
	float streamStrength = pix_data_array[0].x;
	float streamLength = pix_data_array[0].y;
	float falloutPower = pix_data_array[0].z;
	float flashPower = pix_data_array[0].w;
	
	// colorize
	float4 spell_color = pix_data_array[1];
    
  // "stream" out with offset from special texture
  s2half4 offset_tex = tex2D(texture3, vTexCoord.xy);
  s2half2 offset_dir = streamLength * (offset_tex.xy - float2(0.5, 0.5));
  
  offset_dir *= offset_tex.a;
  
  int i;
  float4 res = 0.0;
  float2 lup = vTexCoord.xy;
  for(i = 0; i < 10; i++)
  {
    lup += offset_dir;
    res += tex2D(texture0, lup);
  }
  res /= 10.0;
  
  // colorize it
  res *= spell_color;
  
  // make it grey!
  float4 res_bw = dot(res.xyz, float3(0.222, 0.707, 0.071)).xxxx;
  
  float4 new_color = streamStrength * offset_tex.a * res_bw + org_color;
  
  // apply "fallout"
  new_color = lerp(new_color, dot(res.xyz, float3(0.222, 0.707, 0.071)), falloutPower); 
  // apply "flash"
  new_color *= flashPower;

  // out
  return tex3D(textureVolume, new_color);
} 

