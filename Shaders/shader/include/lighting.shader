#ifndef LIGHTING_H
#define LIGHTING_H
#include "extractvalues.shader"
#include "shadow.shader"


uniform float4    vtx_lightBlocks[MAX_LIGHT_BLOCKS*LIGHT_BLK_VECTOR_CNT+2];
uniform int       vtx_lightBlockCnt;

void computeVertexLightingColorNormal(out float4 color,
                                      out float4 vec_light_os,
                                      float4     pos_os)
{
  color     = float4(0,0,0,0);
  vec_light_os  = float4(0,0,0.01,0);
#ifdef ENABLE_VERTEXLIGHTING
  int k=0;
  for(int l=0; l < vtx_lightBlockCnt;++l)
  { 
    float4 dist0 = vtx_lightBlocks[k+0]-pos_os;
    float4 dist1 = vtx_lightBlocks[k+1]-pos_os;
    float4 dist2 = vtx_lightBlocks[k+2]-pos_os;
    float4 dist3 = vtx_lightBlocks[k+3]-pos_os;

    float4 dist = float4(dot(dist0,dist0),
                         dot(dist1,dist1),
                         dot(dist2,dist2),
                         dot(dist3,dist3));
	dist += float4(0.01,0.01,0.01,0.01);		//avoid division by 0
                         
    float4 tonrm = 1.0f/sqrt(dist);
    float4 invradsq = vtx_lightBlocks[k+8];
    float4 intesity = vtx_lightBlocks[k+9];
    dist        = saturate(dist*invradsq);
    dist        = float4(1,1,1,1)-dist;
    dist       *= dist;
    dist       *= intesity;
    color      += vtx_lightBlocks[k+4]*dist.x+
                  vtx_lightBlocks[k+5]*dist.y+
                  vtx_lightBlocks[k+6]*dist.z+
                  vtx_lightBlocks[k+7]*dist.w;
//    dist=dist*dist*dist;
    dist *= tonrm;
    vec_light_os   += dist0*dist.x+
                      dist1*dist.y+
                      dist2*dist.z+
                      dist3*dist.w;
    k += LIGHT_BLK_VECTOR_CNT;
  }
  color.w=0;
  vec_light_os.xyz = normalize(vec_light_os.xyz);
#endif
  float4 heroLightPos   = vtx_lightBlocks[MAX_LIGHT_BLOCKS*LIGHT_BLK_VECTOR_CNT+0];
  float4 heroLightParam = vtx_lightBlocks[MAX_LIGHT_BLOCKS*LIGHT_BLK_VECTOR_CNT+1];
  float4 toHero   = heroLightPos-pos_os;
  float distHero  = dot(toHero,toHero);
  color.w         = (1-saturate(heroLightParam.x*distHero))*heroLightParam.y;
  
}

float4 computeVertexLightingColor(float4     pos_os,
                                  float4     nrm_os)
{
  float4 light_normal_os;
  float4 final_color;
  computeVertexLightingColorNormal(final_color,light_normal_os,pos_os);
  final_color *= saturate(dot(nrm_os,light_normal_os));
  return final_color;
}


  struct sMaterialData
  { 
    float4 color_diffuse;
    float3 color_spec;
    float  sc_glow_intensity;
    float3 vec_normal_ts;
  };
  void mat_init(out sMaterialData mat)
  {
    mat.color_diffuse   = float4(0,0,0,1);
    mat.color_spec      = float3(0,0,0);
    mat.vec_normal_ts   = float3(0,1,0);
    mat.sc_glow_intensity   = 0;
  }
  void mat_decode_textures_std(inout sMaterialData mat,
                               sampler2D tex0,
                               sampler2D tex1,
                               sampler2D tex2,
                               sampler2D colvar_mask,
                               float4    pix_color_ramp[8],
                               float2    texcoord)
  {
    // get texture values
    mat.color_diffuse     = tex2D(tex0, texcoord.xy);
    float4 val1           = tex2D(tex1, texcoord.xy);
    mat.color_spec        = val1.rgb;
    mat.sc_glow_intensity = val1.a;
    mat.vec_normal_ts     = decode_normal(tex2D(tex2, texcoord.xy));
    #ifdef COLORVARIATIONS
    mat.color_diffuse = apply_colorramp(mat.color_diffuse,
                                        tex2D(colvar_mask, texcoord.xy),
                                        pix_color_ramp);
    #endif

  }                           
    

  struct sLightingData
  { 
    float4 color_ambient;
    float4 color_diffuse;
    float4 color_fog;
    float  sc_shadow_intensity;
    float  sc_fog_intensity;
    float  sc_light_intensity;
    float  sc_spec_intensity;
    float  sc_theta_light;
    float  sc_theta_view;

  };
  void light_init(out sLightingData ld,float4 color_ambient,float4 color_diffuse,float4 color_fog)
  {
    ld.color_ambient      = color_ambient;
    ld.color_diffuse      = color_diffuse;
    ld.color_fog          = color_fog;
    ld.sc_shadow_intensity= 1;
    ld.sc_fog_intensity   = 1;
    ld.sc_light_intensity = 1;
    ld.sc_spec_intensity  = 0;
    ld.sc_theta_light     = 1;
    ld.sc_theta_view      = 0;
  }
  void light_setup_shadow_fog_deferred(inout     sLightingData ld,
                               sampler2D shadow_texture,
                               float4    screenCoordInTexSpace,
                               sampler2D fog_texture,
                               float2    fogUV)
  {
    float4  shadow_tex= tex2Dproj( shadow_texture, screenCoordInTexSpace );
    #ifndef NO_SHADOWS
      ld.sc_shadow_intensity        = shadow_tex.z;
    #endif
    #ifdef S2_FOG
      #ifdef CALC_DEFERRED_FOG
        ld.sc_fog_intensity = shadow_tex.y;
      #else
        ld.sc_fog_intensity = tex2D( fog_texture, fogUV ).w;
      #endif
    #endif
  }
  
  void light_setup_shadow_fog_pnt(inout       sLightingData ld,
                                    samplerCUBE textureCube,     // cube sc_shadow_intensity map of the point light
                                    float4      light_data,
                                    float3      light_vec,
                                    sampler2D   fog_texture,
                                    float2      fogUV)
  {
    #ifdef NO_SHADOWS
    #else
      ld.sc_shadow_intensity = calcPntFadeShadow( textureCube, light_data.z * light_vec,light_data.w);
    #endif
    #ifdef S2_FOG
      ld.sc_fog_intensity = tex2D( fog_texture, fogUV ).w;
    #endif
  }
  void light_set_falloff(inout       sLightingData ld,
                                 float3      pos_to_light,
                                 float4      light_data)
  {
    // calc squared distance from light to point
    float sq_dist_to_light = dot( pos_to_light, pos_to_light );
    // get fraction of light distance to the max light radius
    float temp_dist        = saturate( sq_dist_to_light * light_data.z * light_data.z );
    ld.sc_light_intensity     = (1.0-temp_dist) * (1.0-temp_dist);
    // multiply it by intensity of light source
    ld.sc_light_intensity     *= light_data.y;
  }
  void light_setup_lightvec(inout          sLightingData ld,
                            sMaterialData  mat,
                            float3         pos_to_viewer,
                            float3         pos_to_light)
  {
  	s2half3 view_TS         = normalize( pos_to_viewer  );
	  s2half3 light_TS        = normalize( pos_to_light );
	  // calc light diffuse
#ifdef ALT_LIGHTING_MODE
	  ld.sc_theta_light          = pow( saturate( dot( light_TS, mat.vec_normal_ts ) ), 2.0 );
#else
    ld.sc_theta_light          = saturate( dot( light_TS, mat.vec_normal_ts ) );
#endif
	  ld.sc_theta_view           = saturate( dot( view_TS, mat.vec_normal_ts ) ) + 0.5;
    // calculate specular term
    s2half3 half_vector_TS     = normalize( light_TS + view_TS );
    ld.sc_spec_intensity       = pow( dot( half_vector_TS, mat.vec_normal_ts ), 20.0 );
  }
  float3 light_calc_specular(sLightingData ld,sMaterialData mat)
  {
    return ld.sc_light_intensity * /*mat.sc_spec_intensity * */ld.sc_spec_intensity*mat.color_spec*ld.color_diffuse;
  }
  float3 light_calc_diffuse(sLightingData ld,sMaterialData mat)
  {
    return ld.sc_light_intensity * ld.color_diffuse * mat.color_diffuse * ld.sc_theta_light;
  }                     
  float3 light_calc_ambient(sLightingData ld,sMaterialData mat)
  {
#ifdef ALT_LIGHTING_MODE
    return ld.sc_light_intensity * ld.color_ambient * mat.color_diffuse * (0.8 + 0.6 * ld.sc_theta_light);
#else
    return ld.sc_light_intensity * ld.color_ambient * mat.color_diffuse * ld.sc_theta_view;
#endif
  }                     
  float3 light_calc_glow(sLightingData ld,sMaterialData mat)
  {
    return mat.sc_glow_intensity * mat.color_diffuse;
  }  
  
  float4 light_calc_vertexlighting(float3 vec_normal_vertex,   //must be normalized
                                   float4 color_vertexlight,
                                   float3 vec_light_normal)    //must be normalized
  {
    s2half theta_amb_light = saturate( dot( vec_light_normal, vec_normal_vertex) );
    return float4(theta_amb_light*color_vertexlight.rgb,0);
  }
  
  float4 light_calc_heroLight(float4 color_vertexlight)
  {
    return float4(1,1,0.5,0)*color_vertexlight.w;
  }
  
  void light_setup_vertexlighting(inout sLightingData  ld,
                                  sMaterialData        mat,
                                  float4               color_vertexlight,
                                  float3               vec_light_normal)
  {
    ld.color_ambient += light_calc_heroLight(color_vertexlight);
    ld.color_ambient += light_calc_vertexlighting(mat.vec_normal_ts,
                                                  color_vertexlight,
                                                  normalize(vec_light_normal));
  }
  
  struct sLightingColors
  {
    float3 color_ambient_out;
    float3 color_diffuse_out;
    float3 color_specular_out;
    float3 color_glow_out;

    float4 color_final_color;
    float4 color_final_glow;
  };
  void light_compute(out sLightingColors colors,
                     sLightingData       ld,
                     sMaterialData       mat)
  {
    colors.color_ambient_out = light_calc_ambient(ld,mat);
    colors.color_diffuse_out = light_calc_diffuse(ld,mat);
    colors.color_specular_out= light_calc_specular(ld,mat);
    colors.color_glow_out    = light_calc_glow(ld,mat);

    colors.color_final_color.rgb = colors.color_ambient_out + ld.sc_shadow_intensity * (colors.color_diffuse_out + colors.color_specular_out);
    colors.color_final_color.a   = mat.color_diffuse.a;
    colors.color_final_glow.rgb  = 0.5 * ld.sc_shadow_intensity * colors.color_specular_out;
    colors.color_final_glow.a    = 0;
  }
  void light_add_glow(inout sLightingColors colors)
  {
    colors.color_final_color.rgb += colors.color_glow_out;
    colors.color_final_glow.rgb  += colors.color_glow_out;
  }
   
  float3 light_lerp_fog(sLightingData ld,float3 source_color)
  {
    return lerp(ld.color_fog,source_color,ld.sc_fog_intensity);
  }
  float4 light_lerp_fog(sLightingData ld,float4 source_color)
  {
    source_color.rgb = light_lerp_fog(ld,source_color.rgb);
    return source_color;
  }
  float3 light_scale_fog(sLightingData ld,float3 source_color)
  {
    return source_color*ld.sc_fog_intensity;
  }
  float4 light_scale_fog(sLightingData ld,float4 source_color)
  {
    source_color.rgb = light_scale_fog(ld,source_color.rgb);
    return source_color;
  }


#endif // LIGHTING_H