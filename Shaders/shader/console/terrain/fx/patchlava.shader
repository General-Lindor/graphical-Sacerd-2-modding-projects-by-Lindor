#include "extractvalues.shader"

  struct pixdata
  {
    float4	hposition			          : POSITION;     // vertex position in clip space
    float4  depthDist               : TEXCOORD0;    // depth values for fogging and water depth calculations (depth,far plane,fogtc)
    float4	bumpCoords01       	    : TEXCOORD1;    // 2 sets of UV coordinates for bump textures
    float4	bumpCoords23       	    : TEXCOORD2;    // 2 sets of UV coordinates for bump textures
    float4  height                  : TEXCOORD3;    // 2 sets of UV coordinates for coast foam textures   
  };
  #define VS_OUT_hposition
  #define VS_OUT_depthDist
  #define VS_OUT_bumpCoords
  #define VS_OUT_height


  fragout_2 mainPS (pixdata   I,
                    float2    vPos           : VPOS,
            uniform sampler2D texture0, // refraction
            uniform sampler2D texture1, // patchLavaBase
            uniform sampler2D texture2, // patchLavaRef
            uniform sampler2D fog_texture,
            uniform sampler3D noise_map,
            uniform float4    system_data,
            uniform float4    light_col_diff,
            uniform float4    light_col_amb,
            uniform float4    fog_color
#ifdef CONSOLE_IMPL
           ,uniform float4    fog_data
#endif                    
                  )
  {
	  fragout_2 O;
	  float2 tex_ref = I.bumpCoords01.xy;
	  tex_ref.x += system_data.x*0.01;
	  
	  
	  float height  = I.height.x;
	  float iheight = 1-height;
#ifdef XENON_IMPL	  
    float2 refract_tcs = float2( tiling_data_half_tile.zw*vPos.xy );
#else
    float2 refract_tcs = float2( target_data.zw*vPos.xy );
#endif 
    s2half4 background  = tex2D( texture0, refract_tcs );
	  
    s2half3 out_color   = calc_tnoise(noise_map,texture1,I.bumpCoords01.xy*0.5,system_data.x*1);
    tex_ref.x += out_color.x*0.1f;
    tex_ref.y += out_color.y*0.1f;

    s2half3 col_ref = tex2D(texture2,tex_ref)+out_color;
    s2half3 glow_color    = float3(0,0,0);
    s2half fog_intensity = 0;
	  
	  out_color += col_ref*0.03;
	  
	  out_color *= 2;
	  if(out_color.r > 1.5)
	  {
	    out_color  = col_ref;
	    glow_color = s2half3(out_color/2);
	  }
	  out_color += float3(0.9,0.5,0)*height*height;
	  float3 col_out  = out_color*I.height.x;

	out_color = saturate(out_color);
	glow_color = saturate(glow_color);
	
#ifdef S2_FOG
	  /**************/
	 /* do Fogging */
	/**************/
	float2 fog_coord = getFogTCs(I.depthDist.x*1.f, fog_data);

	float4 skyFog = light_col_diff;
/*	
	skyFog = saturate((world_pos.z + 300)/700);
	skyFog = 1-((1-skyFog) * (1-skyFog));
	skyFog = lerp(light_col_diff, s2half4(0.15f, 0.15f, 0.3f, 0.0f), skyFog.x);
	skyFog = saturate(skyFog);
	skyFog = lerp(light_col_diff, skyFog, fog_coord.r);
*/
	//comment to get skylight
	skyFog = light_col_diff;

	fogGlowMK( out_color, glow_color, fog_intensity, fog_texture, fog_coord, skyFog );
#endif

      out_color  = out_color - background * (1-saturate(I.height.x/0.2));
      out_color  = lerp( background, out_color, saturate(I.height.x/0.05));
	  glow_color = glow_color*saturate(I.height.x/0.2);

      O.col0 = s2half4(out_color.xyz,0);
      O.col1 = s2half4(glow_color.xyz,1);
	  return O;
  }



struct sPixelWaveDescription_river
{
  float4 speed;
  float4 offset_x;
  float4 offset_y;
  float4 scale;
};

struct sPixelWaveDescription_ocean
{
  float4 speed;
  float4 dir_x;
  float4 dir_y;
};


struct appdata
{
  float4 position     : POSITION;
  float4 norm_binorm  : TEXCOORD0;
  float4 uv0          : TEXCOORD1;
  float4 uv1          : TEXCOORD2;
};


pixdata mainVS(appdata  I,
                uniform float4x4 worldViewProjMatrix,
                uniform float4x4 worldMatrix,
                uniform float4   light_pos,
                uniform float4   camera_pos,
                uniform float4   zfrustum_data,
                uniform float4    system_data,
                uniform float4   fog_data
#ifdef XENON_IMPL
               ,uniform float4   viewport_data
#endif                 
                )
{
  pixdata  VSO;
  float3x3 mat_TS;
  float4   pos_tmp;
  float    time = system_data.x;

  // Our waves are defined in worldspace, so we first have to find our vertex position in worldspace
  float    depth        = I.position.w;
           I.position.w = 1.0;
           pos_tmp      = mul( I.position, worldMatrix );
  float4   pos_world    = pos_tmp;
  VSO.hposition         = mul( pos_tmp, worldViewProjMatrix );

  float dotty = 0.0;

#ifdef VS_OUT_depth
  VSO.depth = depth;
#endif

#ifdef VS_OUT_height
  VSO.height = float4(depth*0.2,0,0,0);
#endif

  mat_TS[0] = float3(1,0,0);
  mat_TS[1] = float3(0,1,0);
  mat_TS[2] = float3(0,0,1);

#ifdef VS_OUT_params
  VSO.params.x = time;
  VSO.params.y = dotty;
  VSO.params.z = depth;
  VSO.params.w = 0.0;
#endif

  // Foam coordinates
#ifdef VS_OUT_foamCoords
  VSO.foamCoords.xy = (pos_world.xy - wave_origin.xy) * foam_scales.x + sin( time ) * foam_offsets.x;
  VSO.foamCoords.zw = (pos_world.xy - wave_origin.xy) * foam_scales.y;// + sin( time ) * 0.1 + sin(time - S2_PI - 0.5) * 0.1;
  VSO.foamCoords.z += sin( time ) * foam_offsets.x + sin(time - S2_PI - 0.5) * foam_offsets.y;
  VSO.foamCoords.w -= sin( time ) * foam_offsets.x;
#endif

#ifdef VS_OUT_rainCoords
  VSO.rainCoords = (pos_world.xy - wave_origin.xy) * 0.01;
#endif

  // Bumpmap coordinates
  float4 tex_x = (pos_world.x) * 0.005;
  float4 tex_y = (pos_world.y) * 0.005;    


  // Scroll the bump maps
  //tex_y = tex_y - pixel_descs.speed * time;// - slowdown;// * pixel_descs[0].speed;

#ifdef VS_OUT_bumpCoords
  VSO.bumpCoords01.x = tex_x.x;
  VSO.bumpCoords01.y = tex_y.x;
  VSO.bumpCoords01.z = tex_x.y;
  VSO.bumpCoords01.w = tex_y.y;

  VSO.bumpCoords23.x = tex_x.z;
  VSO.bumpCoords23.y = tex_y.z;
  VSO.bumpCoords23.z = tex_x.w;
  VSO.bumpCoords23.w = tex_y.w;
#endif

  // transform the light vector into tangent space
#ifdef VS_OUT_toLight
  mat_TS      = transpose( mat_TS );
  VSO.toLight = mul( light_pos.xyz, mat_TS );
#endif
  
#ifdef VS_OUT_depthDist
  // put (normalized!) distance&height
  VSO.depthDist.x  = VSO.hposition.w;   // depth of this pixel
  VSO.depthDist.y  = zfrustum_data.y;   // far plane needed to normalize the value read from the depth map
  VSO.depthDist.zw = 0;
  VSO.depthDist.zw = getFogTCs( VSO.hposition.w, fog_data );
#endif

#ifdef VS_OUT_sectorPos
	  // sector position
	  VSO.sectorPos = float4(worldPosition.xyz, TimeMisc.y);
#endif


  return VSO;
}
