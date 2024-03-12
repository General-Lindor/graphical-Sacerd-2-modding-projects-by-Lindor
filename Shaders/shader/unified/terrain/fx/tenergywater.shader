//#OptDef:SPASS_MASK
//#OptDef:SPASS_AMBDIF
//#OptDef:LOWEND_RENDERER

#include "extractvalues.shader"

#define LAYER_BIT0

#ifdef LAYER_BIT0
  #define OCEAN
#endif

#ifdef LAYER_BIT1
  #define RIVER
#endif

#ifdef SPASS_MASK
  struct pixdata
  {
    float4	hposition			          : POSITION;     // vertex position in clip space
  };
  #define VS_OUT_hposition

  fragout1 mainPS (pixdata I,
                  uniform sampler2D   texture0, // pertub
                  uniform sampler2D   texture1, // tenergy1
                  uniform sampler2D   texture2, // tenergy2
                  uniform sampler2D   depth_map, //depth
                  uniform samplerCUBE textureCube,
                  uniform sampler3D   textureVolume,
                  uniform sampler2D   fog_texture,
                  uniform sampler3D   noise_map,
                  uniform float4      system_data,
                  uniform float4      light_col_diff,
                  uniform float4      light_col_amb,
                  uniform float4      fog_color)
  {
	  fragout1 O;
  	O.col = float4(1.0, 1.0, 1.0, 1.0);
	  return O;
  }

#endif


#ifdef SPASS_AMBDIF
  struct pixdata
  {
    float4	hposition			          : POSITION;     // vertex position in clip space
    float4  depthDist               : TEXCOORD0;    // depth values for fogging and water depth calculations (depth,far plane,fogtc)
    float4	bumpCoords01       	    : TEXCOORD1;    // 2 sets of UV coordinates for bump textures
    float4	bumpCoords23       	    : TEXCOORD2;    // 2 sets of UV coordinates for bump textures
    float4  height                  : TEXCOORD3;    // 2 sets of UV coordinates for coast foam textures   
    float4	screenCoordsInTexSpace  : TEXCOORD4;    // Projective UVs for screen texture lookups (background)
  };
  #define VS_OUT_hposition
  #define VS_OUT_depthDist
  #define VS_OUT_bumpCoords
  #define VS_OUT_height
  #define VS_OUT_screenCoordsInTexSpace


  fragout_2 mainPS (pixdata I,
                  uniform sampler2D   texture1, // tEnergy1 texture
                  uniform sampler2D   texture2, // tEnergy2 texture
                  uniform sampler2D   depth_map, //depth
                  uniform sampler2D   fog_texture,
                  uniform sampler3D   noise_map,
                  uniform float4      system_data,
                  uniform float4      fog_color)
  {
	  fragout_2 O;
    sTEnergy tenergy;
#ifdef LOWEND_PIPELINE
    float waterdepth   = 1.0;
#else
    float  viewdepth   = I.depthDist.x;
    float4 proj_tcs    = I.screenCoordsInTexSpace;
    float  grounddepth = tex2Dproj( depth_map, proj_tcs ).x * I.depthDist.y;
    float  waterdepth  = ( grounddepth - viewdepth ) / ( S2_WORLD_METER * 0.5 ); // water depth in m along viewing axis
           waterdepth  = saturate(waterdepth);
#endif
    float  height      = 1 - I.height.x;
    float  iheight     = 1 - height;
    
    // T Energy noise calculations
    calc_tenergy( tenergy, noise_map, texture1, texture2, I.bumpCoords01.xy, -iheight, system_data.x * 0.5 );
    float3 te0          = tenergy.color_fractal + tenergy.color_fractal * pow( tenergy.color_pulse1.xyz, 4 ) * 2.9;
    float3 energy_color = float3( 0.1, 0.2, 0.4 ) + te0 * 0.4;
    energy_color       *= 0.5 + iheight;
    
    // compose final colors
    float3 out_color    = energy_color;
    float3 glow_color   = te0 * waterdepth * 0.05;
    
    // add distance fog
#ifdef S2_FOG
    fogDiffuse( out_color, fog_texture, I.depthDist.zw, fog_color );
    fogGlow( glow_color, fog_texture, I.depthDist.zw );
#endif

    // write color output with alpha blending
    O.col0 = float4( out_color , waterdepth );
    O.col1 = float4( glow_color, waterdepth );
	  return O;
  }
#endif



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
                uniform float4   fog_data )
{
  pixdata  VSO;
  float3x3 mat_TS;
  float4   pos_tmp;
  float    time = system_data.x;

#ifdef RIVER
  pos_tmp       = float4( I.position.xyz, 1.0 );
  // transform position into clipspace	
	VSO.hposition = mul( pos_tmp, worldViewProjMatrix );
  // transform position into world space
  pos_tmp       = mul( pos_tmp, worldMatrix );
#endif

#ifdef OCEAN
  // Our waves are defined in worldspace, so we first have to find our vertex position in worldspace
  float    depth        = I.position.w;
           I.position.w = 1.0;
           pos_tmp      = mul( I.position, worldMatrix );
  float4   pos_world    = pos_tmp;
  VSO.hposition         = mul( pos_tmp, worldViewProjMatrix );
#endif

  float dotty = 0.0;

#ifdef VS_OUT_depth
  VSO.depth = depth;
#endif

#ifdef VS_OUT_height
  VSO.height = float4(depth*0.5,0,0,0);
#endif

#ifdef RIVER
  // calculate tangent space matrix
  float3 normal = { I.norm_binorm.xy * 2.0 - 1.0, 0.0 };
  normal.z      = sqrt( 1.0 - dot( normal.xy, normal.xy ) );
  float3 binorm = { I.norm_binorm.zw * 2.0 - 1.0, 0.0 };
  binorm.z      = sqrt( 1.0 - dot( binorm.xy, binorm.xy ) );
  normal = mul( normal, worldMatrix );
  binorm = mul( binorm, worldMatrix );

  mat_TS[0] = binorm;
  mat_TS[1] = cross( normal, binorm );
  mat_TS[2] = normal;
  // extract the texture coordinates
  float4 tex_x = I.uv0.x / 256.0;
  float4 tex_y = I.uv0.y / 256.0;
  float depth  = I.uv0.z / S2_WORLD_METER;
  float width  = I.uv0.w / 256.0;

  // calculate river transparencies
  float4 vals = I.uv1 / 256.0;
  float4 fade_values = vtx_data_array[VS_FADE_PARAMETERS];
  float foam  = dot( vals.yw, fade_values.zw );
  float trans = dot( vals.xz, fade_values.xy );
  float fac   = 1.0 - sqrt( width * width + (1.0-trans) * (1.0-trans) );
        trans = trans < 1.0 ? ( pow( sin( saturate( fac ) * S2_PI * 0.5 ), 1.0) ) : 1.0;
  VSO.params.x = time;
  VSO.params.y = foam;
  VSO.params.z = depth;
  VSO.params.w = trans; 

  sPixelWaveDescription pixel_descs;
  pixel_descs.speed    = vtx_data_array[VS_PIXEL_WAVE_SPEEDS  ];
  pixel_descs.offset_x = vtx_data_array[VS_PIXEL_WAVE_OFFSET_X];
  pixel_descs.offset_y = vtx_data_array[VS_PIXEL_WAVE_OFFSET_Y];
  pixel_descs.scale    = vtx_data_array[VS_PIXEL_WAVE_SCALES  ];
  // scale and translate the texture coordinates
  tex_x = tex_x * pixel_descs.scale + pixel_descs.offset_x;
  tex_y = tex_y * pixel_descs.scale + pixel_descs.offset_y;
#endif


#ifdef OCEAN

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
#endif // OCEAN

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

#ifdef RIVER
  #ifdef VS_OUT_foamCoords
  VSO.foamCoords.xy = VSO.bumpCoords01.xy;
  VSO.foamCoords.zw = VSO.bumpCoords01.zw;
  #endif
  #ifdef VS_OUT_rainCoords
    VSO.rainCoords = (pos_tmp.xy) * 0.01;
  #endif
#endif
  // vertex-position in screen space
#ifdef VS_OUT_screenCoordsInTexSpace
  VSO.screenCoordsInTexSpace = calcScreenToTexCoord(VSO.hposition);
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
