#ifndef SUNLIGHT_XENON_SHADER
#define SUNLIGHT_XENON_SHADER

void CalcPointLight( const int i, 
                     const float3  viewVec, 
                     const float3  dir_refl,
                     const s2half3 tex_normal,
                     const s2half  dots_y,
                     const s2half  brdf_scale,
                     const s2half2 brdf_offset,
                     inout s2half3 diffuse,
                     inout s2half3 specular )
{
  s2half3 tmp_diff;
  s2half3 tmp_spec;
  
  float3 l_to_pix = g_LightInfo[i].vLightPos.xyz - viewVec;
  float3 dir_light = normalize(l_to_pix);
	                      
  s2half3 dots = 0;
  dots.x  = dot(dir_light.xyz, tex_normal.xyz)*0.5+0.5;
  dots.y  = dots_y;
  dots.z  = dot(dir_light.xyz, dir_refl.xyz)*0.5+0.5;
  dots.xz =  dots.xz*brdf_scale.xx + brdf_offset.xy;

  tex_brdf( Brdf_Sampler,
            dots,
            tmp_diff,      //out
            tmp_spec );    //out

  float  light_dist_sq = dot(l_to_pix, l_to_pix);
  s2half temp_dist = saturate(light_dist_sq*g_LightInfo[i].vLightPos.w + 1);
  diffuse  += g_LightInfo[i].vLightCol.rgb * temp_dist*temp_dist * tmp_diff;
  specular += g_LightInfo[i].vLightCol.rgb * temp_dist*temp_dist * tmp_spec;
}

// calculate pointlight-color with shadow
void CalcShdPointLight( int i, 
			            uniform samplerCUBE shadowMap,
                        float3 viewVec,
                        float3  dir_refl,
                        s2half3 tex_normal,
                        const s2half  dots_y,
                        const s2half  brdf_scale,
                        const s2half2 brdf_offset,
                        inout s2half3 diffuse,
                        inout s2half3 specular )
{
  s2half3 tmp_diff;
  s2half3 tmp_spec;
  s2half4 pnt_dat = g_ShdLightInfo[i].vLightDat;
  
  float3 l_to_pix = g_ShdLightInfo[i].vLightPos.xyz - viewVec;
  float3 dir_light = normalize(l_to_pix);
  float  light_dist_sq = dot(l_to_pix, l_to_pix);
  float  light_dist = sqrt(light_dist_sq);
  
  s2half3 dots = 0;
  dots.x  = dot(dir_light.xyz, tex_normal.xyz)*0.5+0.5;
  dots.y  = dots_y;
  dots.z  = dot(dir_light.xyz, dir_refl.xyz)*0.5+0.5;
  dots.xz =  dots.xz*brdf_scale.xx + brdf_offset.xy;

  tex_brdf( Brdf_Sampler,
            dots,
            tmp_diff,      //out
            tmp_spec );    //out

  s2half shadow = calcPntFadeShadow( shadowMap, -dir_light.xzy, light_dist*pnt_dat.z, pnt_dat.w );

//  s2half ambientDiffuseFade = dots.x;
//  s2half fader = saturate(lerp(1, shadow, ambientDiffuseFade));
  
  s2half temp_dist = saturate(light_dist_sq*g_ShdLightInfo[i].vLightPos.w + 1);
  diffuse  += g_ShdLightInfo[i].vLightCol.rgb * temp_dist*temp_dist * tmp_diff * shadow;
  specular += g_ShdLightInfo[i].vLightCol.rgb * temp_dist*temp_dist * tmp_spec * shadow;
}
#endif //include guard
