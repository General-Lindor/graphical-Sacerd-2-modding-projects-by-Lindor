#ifndef BRDFLIGHTING_SHADER
#define BRDFLIGHTING_SHADER

#include "DeferredMaterials.shader"

void fogGlowMK( inout s2half3 source_color, inout s2half3 source_glow, inout s2half fade, in sampler2D fog_texture, in float2 fog_tcs, in s2half3 sunlight_col )
{
  s2half4 fog_color = tex2D( fog_texture, fog_tcs );
  fog_color.xyz = srgb2linear( fog_color.xyz);

  sunlight_col.rgb *= fog_color.rgb;
  fog_color.w *= fog_color.w;
  source_color  = lerp( source_color, sunlight_col, fog_color.w );
  source_glow   = source_glow / (1 + 7*fog_color.w); // glow mit Fog ausblenden

  // Tiefenunschärfe im Nahbereich: when changing this don't forget to also change extractvalues.shader
//*/  
  //enabled
  fade = ( fog_tcs.x<0 ) ? saturate(-2*fog_tcs.x - 0.5) : saturate(2*fog_tcs.x - 0.5); 
/*/
  //disabled
  fade = saturate(2*fog_tcs.x - 0.25);
//*/
  if( fog_tcs.x>0.999 )
	fade = 0;
}
void fogGlowMKSimple( inout s2half3 source_color, in sampler2D fog_texture, in float2 fog_tcs, in s2half3 sunlight_col )
{
  s2half4 fog_color = tex2D( fog_texture, fog_tcs );
  sunlight_col.rgb *= fog_color.rgb;
  source_color = lerp( source_color, sunlight_col, fog_color.w );
}

void tex_brdf( sampler2D Brdf_Sampler,
               s2half3   dots,
           out s2half3   difCol, 
           out s2half3   spcCol )
{
  s2half4 nt = h4tex2D( Brdf_Sampler, dots.xy ); //BRDF_N	
  s2half4 ht = h4tex2D( Brdf_Sampler, dots.zy ); //BRDF_H
  
  difCol = nt.xyz * ht.a;
  spcCol = ht.xyz * nt.a;
}
#endif //include guard
