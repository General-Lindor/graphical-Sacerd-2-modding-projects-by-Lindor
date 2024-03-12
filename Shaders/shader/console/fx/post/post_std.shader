// post render blit
//#define MKDEBUG
#include "S2Types.shader"

float4 mainVS( float4 pos : POSITION ) : POSITION
{
	return pos;
}

s2half4 mainPS(float2    vPos : VPOS,
       uniform sampler2D texture0,
       uniform sampler2D texture1,
       uniform sampler3D textureVolume ) : COLOR
{
	float4 final_color = 0;

	s2half2 vTexCoord = (vPos+0.5.xx)*target_data.zw;
	s2half4 org_color   = tex2D(texture0, vTexCoord);

	//apply glow
	s2half4 glow = tex2D(texture1, vTexCoord);
	org_color.rgb = org_color*glow.a+glow;
	
	final_color = org_color;
#ifdef MKDEBUG
	if(vTexCoord.x < .25)
	    final_color = img1;
	else if(vTexCoord.x < .5)
	    final_color = img2;
	else if(vTexCoord.x < .75)
	    final_color = img3;
	else
		final_color = img4;
#endif // MKDEBUG

  final_color.a = 1; // [BC] HACK
  // out 
  return final_color;// * (1.0 + param.z * saturate(2.0 * (1.0 - saturate(length(vTexCoord.xy)))));
} 