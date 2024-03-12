#include "extractvalues.shader"

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

struct pixdata
{
	float4	hposition			    : POSITION;     // vertex position in clip space
	float4  depthDist               : TEXCOORD0;    // depth values for fogging and water depth calculations (depth,far plane,fogtc)
	float4	bumpCoords01       	    : TEXCOORD1;    // 2 sets of UV coordinates for bump textures
	float4	bumpCoords23       	    : TEXCOORD2;    // 2 sets of UV coordinates for bump textures
	float4  height                  : TEXCOORD3;    // 2 sets of UV coordinates for coast foam textures
};

#define VS_OUT_hposition
#define VS_OUT_depthDist
#define VS_OUT_bumpCoords
#define VS_OUT_height

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
  VSO.height = float4(depth*0.5,0,0,0);
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

//  float4 tmp_tex_x = tex_x * pixel_descs.dir_x - tex_y * pixel_descs.dir_y;
//  float4 tmp_tex_y = tex_y * pixel_descs.dir_x + tex_x * pixel_descs.dir_y;

//  tex_x = tmp_tex_x;
//  tex_y = tmp_tex_y;

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

  fragout_2 mainPS (pixdata   I,
                    float2    vPos           : VPOS,
            uniform sampler2D texture0, // pertub
            uniform sampler2D texture1, // refraction
            uniform sampler2D texture2, // mask texture
            uniform sampler2D depth_map, //depth
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
    sTEnergy tenergy;
    float  viewdepth   = I.depthDist.x;

    // screenpos of this pixel, zw is refracted
#ifdef XENON_IMPL    
    float2 scr_pos = float2( tiling_data_half_tile.zw*vPos.xy );
#else
    float2 scr_pos = float2( target_data.zw*vPos.xy );
#endif    
    float4 background  = tex2D( texture0, scr_pos );
    float  grounddepth = DEPTH_SAMPLE_RAW(depth_map, scr_pos).x;
	grounddepth = (2*Z_FAR*Z_NEAR) / ((Z_FAR+Z_NEAR) - (2*grounddepth-1)*(Z_FAR-Z_NEAR));
    
    float  waterdepth  = ( grounddepth - viewdepth ) / (S2_WORLD_METER*0.5); // water depth in m along viewing axis
    float height = 1-I.height.x;
    float iheight = 1-height;
    waterdepth = saturate(waterdepth);
    calc_tenergy(tenergy,noise_map,texture1,texture2,I.bumpCoords01.xy,-iheight,system_data.x*0.5);
    float3 te0          = tenergy.color_fractal+tenergy.color_fractal*pow(tenergy.color_pulse1.xyz,4)*2.9;
    s2half3 energy_color = s2half3(0.1,0.2,0.4)+te0*0.4;
    energy_color *= 0.5+iheight;

	s2half3 glow_color   = float3(te0*waterdepth*0.05);
	s2half  fog_intensity=1.f;
#ifdef S2_FOG
	  /**************/
	 /* do Fogging */
	/**************/
	float2 fog_coord = getFogTCs(viewdepth, fog_data);

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

	fogGlowMK( energy_color, glow_color, fog_intensity, fog_texture, fog_coord, skyFog );
#endif

    s2half3 out_color    = lerp(background,energy_color,waterdepth);
    
//    fogDiffuse(out_color,fog_texture,I.depthDist.zw,fog_color);
//    fogGlow(glow_color,fog_texture,I.depthDist.zw);

    O.col0 = float4(out_color,1);
    O.col1 = s2half4( glow_color + out_color * fog_intensity, 1 - fog_intensity );
    
#ifdef PS3_IMPL
    ret.col1.a = 1 - SQRT(fog_intensity); // Hardware converts RGB to srgb - we do it for alpha
#endif

	return O;
  }