//#OptDef:SPASS_G
//#OptDef:SPASS_SHADOWMAP
//#OptDef:SPASS_CUBESHADOWMAP
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
//#OptDef:SPASS_LIGHTNING
//#OptDef:S2_FOG
//#OptDef:TREE_HOLE

#define VS_IN_TREEVERTEX

/////////////////////////////////////
// SPASS_AMBDIF setup
/////////////////////////////////////
#ifdef SPASS_AMBDIF
  #define VS_OUT_G
  #define PS_TRUNK_SPASS_AMBDIF_20
#endif

/////////////////////////////////////
// SPASS_PNT setup
/////////////////////////////////////
#ifdef SPASS_PNT
  #define VS_OUT_PNT_20_X
  #define PS_TRUNK_SPASS_PNT_20
#endif


#include "treeShared.shader"




/////////////////////////////////////////////////
//PASS_AMBDIF pixel shader (>=SM2_0)
/////////////////////////////////////////////////
#ifdef PS_TRUNK_SPASS_AMBDIF_20
    #include "normalmap.shader"
    fragout2 mainPS(pixdata           I,
                    float2            vPos : VPOS,
                    uniform sampler2D texture0,
                    uniform sampler2D texture1,
                    uniform sampler2D shadow_map,
                    uniform sampler2D fog_texture,
                    uniform sampler3D textureVolume,
                    uniform float4    light_col_amb,
                    uniform float4    light_col_diff,
                    uniform float4    param,
                    uniform float4    materialID )
    {
	    fragout2 O;
  
	    half4  tex_diffuse = tex2D(texture0, I.texcoord0.xy);
	    tex_diffuse		     = srgb2linear( tex_diffuse );
	    
	    s2half3 diffuse    = tex_diffuse.xyz;
	    s2half3 specular   = tex_diffuse.www;
	    



      // calc worldspace normal
      s2half4 normal_TS = ReadNormalMap2D(texture1, I.texcoord0.xy);
      float3x3 TS_to_WS = { normalize(I.matrix_TS_to_WS[0]), 
                            normalize(I.matrix_TS_to_WS[1]), 
                            normalize(I.matrix_TS_to_WS[2]) };
#ifdef PS3_IMPL
      s2half3 normal = normalize( mul( TS_to_WS, normal_TS.xyz ) );
#else
      s2half3 normal = normalize( mul( normal_TS.xyz, TS_to_WS ) );
#endif

      // set output color
      O = CalcSunlight( s2half4(diffuse, 1 ),
                        s2half4(normal, materialID.x ),
                        s2half4(specular, 0 ),
                        I.posInLight,
                        I.pix_to_cam,
                        -I.li_to_pix_w,
                        light_col_amb,
                        light_col_diff,
                        shadow_map,
                        textureVolume //Brdf_Sampler
       ); 
      O.col[0].rgb = linear2srgb(O.col[0].rgb);
      O.col[1].rgb = linear2srgb(O.col[1].rgb);
      O.col[0].a   = calcHoleAlpha(I.hpos, param.x);
     
      return O;
    }
#endif


/////////////////////////////////////////////////
//PASS_PNT pixel shader (>=SM2_0)
/////////////////////////////////////////////////
#ifdef PS_TRUNK_SPASS_PNT_20
  fragout2 mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D texture1,
      uniform sampler2D fog_texture,
      uniform float4 light_col_diff,
      uniform float4 light_data)
  {
	  fragout2 O;

	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	  // get normal vector from bumpmap texture
	  s2half3 nrm = normalize(tex1.xyz - s2half3(0.5, 0.5, 0.5));

	  // calc diffuse
	  s2half3 l0_dir = normalize(I.pix_to_li_t.xyz);
	  s2half4 diffuse = saturate(dot(l0_dir, nrm)) * light_col_diff;

	  // calc specular
	  s2half3 c_dir = normalize(I.pix_to_c.xyz);
	  s2half3 half_vec = normalize(l0_dir + c_dir);
	  s2half4 specular =  pow(saturate(dot(half_vec, nrm)), 20.0) * tex1.w * light_col_diff;

	  // calc distance of light
	  float dist_to_light = dot(I.pix_to_li_o.xyz, I.pix_to_li_o.xyz);
	  // build intensity from distance to light using light radius
	  s2half temp_dist = saturate(dist_to_light / (light_data.x * light_data.x));
	  s2half intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
	  // multiply it by intensity of ight source
	  intensity *= light_data.y;
  #ifdef S2_FOG
    // fog
    fogPnt( intensity, fog_texture, I.depthFog );
  #endif

	  O.col[0] = intensity * ((diffuse * tex0) + specular);
	  O.col[0].a = tex0.a;
	  O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
	  return O;
  } 
#endif 


