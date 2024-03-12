#include "extractvalues.shader"


//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:LAYER_BIT2
//#OptDef:LAYER_BIT3
//#OptDef:LAYER_BIT4
//#OptDef:S2_FOG
//#OptDef:TREE_HOLE


#ifdef LAYER_BIT0
  #define OCEAN
  #define OCEAN_RIVER
#endif

#ifdef LAYER_BIT1
  #define RIVER
  #define OCEAN_RIVER
#endif

#ifdef LAYER_BIT2
  #define MASK
#endif

#ifdef LAYER_BIT3
  #define RAINING
#endif

#ifdef LAYER_BIT4
  #define ALPHA_BLEND_FOAM
#endif

#ifdef TREE_HOLE
  #define NEW_WATER
#endif


#ifdef NEW_WATER



//#################################################################
//#                                                               #
//#                       NEW WATER SHADER                        #
//#                                                               #
//#################################################################

#ifdef OCEAN_RIVER
  // Set Pixel shader
  #ifdef SM1_1
    #define PS_DUMMY
  #else
    #ifdef MASK
      #define PS_MASK
    #else
      #define PS_WATER
    #endif
  #endif


/********************************************************************
 *                                                                  *
 *              VERTEX SHADER CONSTANTS DEFINITIONS                 *
 *                                                                  *
 ********************************************************************/

  #ifdef RIVER
    // River water specific defines
    #define NUM_PIXEL_WAVE_BLOCKS     1   // Set this to the number of pixel wave blocks you want
    #define VS_TIME                   0
    #define VS_PIXEL_WAVE_SPEEDS      1
    #define VS_PIXEL_WAVE_OFFSET_X    2
    #define VS_PIXEL_WAVE_OFFSET_Y    3
    #define VS_PIXEL_WAVE_SCALES      4
    #define VS_FADE_PARAMETERS        5
    #define VS_NUMOF                  6
  #endif

  #ifdef OCEAN
    /*************************************************************************
     * number of waves - keep this synchronized with --- renderGlobals.h --- *
     *************************************************************************/
#ifdef SM3_0
    #define NUM_VERTEX_WAVE_BLOCKS   2   // Set this to the number of geometric wave blocks you want
#else
    #define NUM_VERTEX_WAVE_BLOCKS   1   // Set this to the number of geometric wave blocks you want
#endif
    #define NUM_PIXEL_WAVE_BLOCKS    1   // Set this to the number of pixel wave blocks you want
    #define NUM_VERTEX_WAVES         4 * NUM_VERTEX_WAVE_BLOCKS
    #define NUM_PIXEL_WAVES          4 * NUM_PIXEL_WAVE_BLOCKS

    // used for indexing the uniform VS input array
    #define VS_TIME                      0
    #define VS_WAVE_ORIGIN               1
    #define VS_VERTEX_WAVE_AMPLITUDES    2
    #define VS_VERTEX_WAVE_LENGTHS       VS_VERTEX_WAVE_AMPLITUDES  + NUM_VERTEX_WAVE_BLOCKS
    #define VS_VERTEX_WAVE_SPEEDS        VS_VERTEX_WAVE_LENGTHS     + NUM_VERTEX_WAVE_BLOCKS
    #define VS_VERTEX_WAVE_SHARPNESSES   VS_VERTEX_WAVE_SPEEDS      + NUM_VERTEX_WAVE_BLOCKS
    #define VS_VERTEX_WAVE_DIR_X         VS_VERTEX_WAVE_SHARPNESSES + NUM_VERTEX_WAVE_BLOCKS
    #define VS_VERTEX_WAVE_DIR_Y         VS_VERTEX_WAVE_DIR_X       + NUM_VERTEX_WAVE_BLOCKS
    #define VS_PIXEL_WAVE_SPEEDS         VS_VERTEX_WAVE_DIR_Y       + NUM_VERTEX_WAVE_BLOCKS
    #define VS_PIXEL_WAVE_DIR_X          VS_PIXEL_WAVE_SPEEDS       + NUM_PIXEL_WAVE_BLOCKS
    #define VS_PIXEL_WAVE_DIR_Y          VS_PIXEL_WAVE_DIR_X        + NUM_PIXEL_WAVE_BLOCKS
    #define VS_FOAM_PARAMETERS           VS_PIXEL_WAVE_DIR_Y        + NUM_PIXEL_WAVE_BLOCKS
    #define VS_NUMOF                     VS_FOAM_PARAMETERS         + 1
  #endif


/********************************************************************
 *                                                                  *
 *               PIXEL SHADER CONSTANTS DEFINITIONS                 *
 *                                                                  *
 ********************************************************************/
  #define PS_WATER_COLOR                0
  #define PS_WATER_PARAMETERS           PS_WATER_COLOR      + 1
  #define PS_FOAM_PARAMETERS            PS_WATER_PARAMETERS + 1
  #define PS_NUMOF                      PS_FOAM_PARAMETERS  + 1



/********************************************************************
 *                                                                  *
 *               VERTEX SHADER APPLICATION INPUT                    *
 *                                                                  *
 ********************************************************************/
  struct appdata
  {
    float4 position     : POSITION;
    float4 norm_binorm  : TEXCOORD0;
    float4 uv0          : TEXCOORD1;
    float4 uv1          : TEXCOORD2;
  };


/********************************************************************
 *                                                                  *
 *         INTERPOLATORS: VERTEX SHADER -> PIXEL SHADER             *
 *                                                                  *
 ********************************************************************/
  struct pixdata
  {
    float4	hposition			          : POSITION;     // vertex position in clip space
  #ifdef MASK
  #ifdef OCEAN
    float   depth                   : TEXCOORD0;    // needed for caustic rendering of ocean waves
  #endif
  #else
    float4  depthDist               : TEXCOORD0;    // depth values for fogging and water depth calculations
    float4	bumpCoords01       	    : TEXCOORD1;    // 2 sets of UV coordinates for bump textures
    float4	bumpCoords23       	    : TEXCOORD2;    // 2 sets of UV coordinates for bump textures
    float4  foamCoords              : TEXCOORD3;    // 2 sets of UV coordinates for coast foam textures   
    float4	screenCoordsInTexSpace  : TEXCOORD4;    // Projective UVs for screen texture lookups (background)
    float4  base_TS                 : TEXCOORD5;    // normal xy and tangent xy to get the tangent space matrix in the pixel shader
    float4  params                  : TEXCOORD6;    // various other parameters depending on river or ocean
  #ifdef RAINING
    float2  rainCoords              : TEXCOORD7;
  #endif
  #ifdef SM2_0
    float3  toCamera                : COLOR0;       // unit vector to sun light
    float3  toLight                 : COLOR1;       // unit vector to camera
  #else
    float4  toCamera                : TEXCOORD8;    // unit vector to sun light
    float3  toLight                 : TEXCOORD9;    // unit vector to camera
  #endif
  #endif
  };

/********************************************************************
 *                                                                  *
 *                      PIXEL SHADER OUTPUTS                        *
 *                                                                  *
 ********************************************************************/
  struct fragout
  {
    float4 col0        : COLOR0;
  #ifndef MASK // used by all non-mask passes
    float4 col1        : COLOR1;
  #endif
  };
#endif



/********************************************************************
 *                                                                  *
 *                   WATER PARAMETER STRUCTS                        *
 *                                                                  *
 ********************************************************************/
#ifdef RIVER
  // contains data for pixel normal mapping effects
struct sPixelWaveDescription
{
  float4 speed;
  float4 offset_x;
  float4 offset_y;
  float4 scale;
};
#endif


#ifdef OCEAN
// NEW WATER SIMULATION CODE
// these structs actually encode 4 waves
// contains data for vertex displacement
struct sWaveDescription 
{
  float4  amplitude;
  float4  wavelength;
  float4  speed;
  float4  sharpness;
  float4  dir_x;
  float4  dir_y;
};

// contains data for pixel normal mapping effects
struct sPixelWaveDescription
{
  float4 speed;
  float4 dir_x;
  float4 dir_y;
};


/********************************************************************
 *                                                                  *
 *                   OCEAN VERTEX DISPLACEMENT ROUTINE              *
 *                                                                  *
 ********************************************************************/
void transformVertex( inout float3 world_pos, in float time, in float depth, in float2 wave_origin, in sWaveDescription wave_descs[NUM_VERTEX_WAVE_BLOCKS], out float3 binormal, out float3 tangent )
{
  float fade_level = 2.0;
  // initialize return parameters
  float3x4 offset   = 0;
  // attenuation factor starting at a depth of fade_level meters
  float4 attenuate  = exp( -( (1.0 - clamp( depth / fade_level, 0.2, 1.0 )) * 1.0 ) );
  // initialize tangent space base vectors
  float3x4 bt = 0; // binormal temporary accumulated results
  float3x4 tt = 0; // tangent  temporary accumulated results
  float2 tp = (world_pos.xy - wave_origin) / S2_WORLD_METER;

  // we iterate over every wave and sum its components
  for( int i = 0; i < NUM_VERTEX_WAVE_BLOCKS; i++ )
  {
    float4 amplitude  = wave_descs[i].amplitude;
    float4 wavelength = wave_descs[i].wavelength;
    float4 speed      = wave_descs[i].speed;
    float4 sharpness  = wave_descs[i].sharpness;
    float4 d_x        = wave_descs[i].dir_x;
    float4 d_y        = wave_descs[i].dir_y;

    // Gerstner Waves (Tessendorf / GPU Gems 1)
    float4 k         = S2_PI2 / wavelength;
    float4 kd_x      = d_x * k;
    float4 kd_y      = d_y * k;
    float4 w_deep    = sqrt( k * 9.81 * speed );
    float4 w_shallow = sqrt( k * 9.81 * speed * (tanh( k * depth ) + 1) * 1.0 );
    //float4 w         = lerp( w_shallow, w_deep, clamp( attenuate, 0.96, 1.0 ) );
    float4 w         = w_deep;
    //float slowdown   = cos( saturate(depth / fade_level) * S2_PI * 0.5 ) * 10;
    float4 slowdown   = ( 1.0 - attenuate ) * 5.0;


    // calculate x
    float4 x  = kd_x * tp.x + kd_y * tp.y - time * w + slowdown;

/*
    // mess up the surface a bit
    //float a = d_x * tp.x + d_y * tp.y;
    float a = tp.x;
    float c = length( tp );
    float b = (c - a) * (c - a);
    float lateral_att = ( abs( sin( b / 4.7 ) - cos( b / 1.3 ) ) );
    amplitude *= lateral_att;
    sharpness *= lateral_att;
*/

    amplitude *= attenuate;
#ifdef SM3_0
    sharpness *= attenuate;//saturate( depth );//attenuate;
#endif

    // get the sine and cosine
    float4 sine, cosine;
    sincos( x, sine, cosine );

    sharpness /= k * amplitude * NUM_VERTEX_WAVES;
    // accumulate the result
    offset[0] -= d_x * amplitude * sine * sharpness;
    offset[1] -= d_y * amplitude * sine * sharpness;
    offset[2] +=       amplitude * cosine;

    bt[0] += kd_x * d_x * amplitude * cosine * sharpness;
    bt[1] += kd_x * d_y * amplitude * cosine * sharpness;
    bt[2] += kd_x *       amplitude * sine;

    tt[0] += kd_y * d_x * amplitude * cosine * sharpness;
    tt[1] += kd_y * d_y * amplitude * cosine * sharpness;
    tt[2] += kd_y *       amplitude * sine;
  }
  binormal.x = 1.0 - ( bt[0].x + bt[0].y + bt[0].z + bt[0].w );
  binormal.y =     - ( bt[1].x + bt[1].y + bt[1].z + bt[1].w );
  binormal.z =     - ( bt[2].x + bt[2].y + bt[2].z + bt[2].w );
  tangent.x  =     - ( tt[0].x + tt[0].y + tt[0].z + tt[0].w );
  tangent.y  = 1.0 - ( tt[1].x + tt[1].y + tt[1].z + tt[1].w );
  tangent.z  =     - ( tt[2].x + tt[2].y + tt[2].z + tt[2].w );
  binormal = normalize( binormal );
  tangent  = normalize( tangent  );

  // shift the vertex and scale to world size
  world_pos.x += ( offset[0].x + offset[0].y + offset[0].z + offset[0].w ) * S2_WORLD_METER;
  world_pos.y += ( offset[1].x + offset[1].y + offset[1].z + offset[1].w ) * S2_WORLD_METER;
  world_pos.z += ( offset[2].x + offset[2].y + offset[2].z + offset[2].w ) * S2_WORLD_METER;
}
#endif




pixdata mainVS(         appdata  I,
                uniform float4x4 worldViewProjMatrix,
                uniform float4x4 worldMatrix,
                uniform float4   light_pos,
                uniform float4   camera_pos,
                uniform float4   vtx_data_array[VS_NUMOF],
                uniform float4   zfrustum_data,
                uniform float4   fog_data )
{
  pixdata  VSO;
  float3x3 mat_TS;
  float4   pos_tmp;
  float    time = vtx_data_array[VS_TIME].x;
  float    visc = vtx_data_array[VS_TIME].y;  // water viscosity
  float    wave_crest_foam = vtx_data_array[VS_TIME].z; // show foam at wave crests

#ifdef RIVER
  pos_tmp       = float4( I.position.xyz, 1.0 );
  // transform position into clipspace	
	VSO.hposition = mul( pos_tmp, worldViewProjMatrix );
  // transform position into world space
  pos_tmp       = mul( pos_tmp, worldMatrix );
#endif

#ifdef OCEAN
  // build wave descriptions from the constant shader parameters
  sWaveDescription vertex_descs[NUM_VERTEX_WAVE_BLOCKS];
  // we need these to calculate the general wave direction to put foam on the crests
  float4 t1 = 0;
  float4 t2 = 0;
  for( int i = 0; i < NUM_VERTEX_WAVE_BLOCKS; i++ )
  {
    vertex_descs[i].amplitude  = vtx_data_array[VS_VERTEX_WAVE_AMPLITUDES  + i];
    vertex_descs[i].wavelength = vtx_data_array[VS_VERTEX_WAVE_LENGTHS     + i];
    vertex_descs[i].speed      = vtx_data_array[VS_VERTEX_WAVE_SPEEDS      + i];
    vertex_descs[i].sharpness  = vtx_data_array[VS_VERTEX_WAVE_SHARPNESSES + i];
    vertex_descs[i].dir_x      = vtx_data_array[VS_VERTEX_WAVE_DIR_X       + i];
    vertex_descs[i].dir_y      = vtx_data_array[VS_VERTEX_WAVE_DIR_Y       + i];
#ifdef MINIMAPMODE // disable vertex displacement in xy plane to avoid seams in the minimap
    vertex_descs[i].sharpness  = 0;
#endif
#ifdef SM3_0
    if( wave_crest_foam )
    {
      t1 += vertex_descs[i].dir_x * vertex_descs[i].amplitude;
      t2 += vertex_descs[i].dir_y * vertex_descs[i].amplitude;
    }
#endif
  }

  // Our waves are defined in worldspace, so we first have to find our vertex position in worldspace
  float4   wave_origin  = vtx_data_array[VS_WAVE_ORIGIN];
  float    depth        = I.position.w;
           I.position.w = 1.0;
           pos_tmp      = mul( I.position, worldMatrix );
  float4   pos_world    = pos_tmp;
           // now transform the actual position
           transformVertex( pos_tmp.xyz, time, depth, wave_origin.xy, vertex_descs, mat_TS[0], mat_TS[1] );
           mat_TS[2]    = cross( mat_TS[0], mat_TS[1] );
  VSO.hposition         = mul( pos_tmp, worldViewProjMatrix );

  float dotty = 0.0;
#ifdef SM3_0
  if( wave_crest_foam )
  {
    float4 one = { 1,1,1,1 };
    float2 wav_dir = { dot( t1, one ), dot( t2, one ) };
    wav_dir        = normalize( wav_dir );
    dotty          = dot( wav_dir, mat_TS[2].xy );
  }
#endif

#endif


#ifdef MASK
#ifdef OCEAN
  VSO.depth = depth;
#endif
#endif

#ifndef MASK




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
  sPixelWaveDescription pixel_descs;
  pixel_descs.speed = vtx_data_array[VS_PIXEL_WAVE_SPEEDS];
  pixel_descs.dir_x = vtx_data_array[VS_PIXEL_WAVE_DIR_X ];
  pixel_descs.dir_y = vtx_data_array[VS_PIXEL_WAVE_DIR_Y ];
/*
  float2 vnormal = (I.norm_binorm.xy * 2.0) - 1.0;
         vnormal = - normalize( vnormal );
  float4 dot4    = abs( vnormal.x * pixel_descs.dir_y + vnormal.y * pixel_descs.dir_x );

  VSO.params.x = saturate( (depth - 0.5) / 2.0 );
  VSO.params.y = dot4.x;
  VSO.params.z = depth;
  VSO.params.w = pos_tmp.z - pos_world.z;

 
  float4 slowdown_c = cos( saturate(depth / 2.0) * S2_PI * 0.5 );
  float4 slowdown_s = sin( saturate(depth / 2.0) * S2_PI * 0.5 );
  float4 slowdown   = slowdown_c * dot4;
*/  
  VSO.params.x = time;
  VSO.params.y = dotty;
  VSO.params.z = depth;
  VSO.params.w = 0.0;

  // Foam coordinates
  float2 foam_offsets = vtx_data_array[VS_FOAM_PARAMETERS].xy;
  float2 foam_scales  = vtx_data_array[VS_FOAM_PARAMETERS].zw;
  VSO.foamCoords.xy = (pos_world.xy - wave_origin.xy) * foam_scales.x + sin( time ) * foam_offsets.x;
  VSO.foamCoords.zw = (pos_world.xy - wave_origin.xy) * foam_scales.y;// + sin( time ) * 0.1 + sin(time - S2_PI - 0.5) * 0.1;
  VSO.foamCoords.z += sin( time ) * foam_offsets.x + sin(time - S2_PI - 0.5) * foam_offsets.y;
  VSO.foamCoords.w -= sin( time ) * foam_offsets.x;

#ifdef RAINING
  VSO.rainCoords = (pos_world.xy - wave_origin.xy) * 0.01;
#endif

  // Bumpmap coordinates
  float4 tex_x = (pos_world.x - wave_origin.x) * 0.005;
  float4 tex_y = (pos_world.y - wave_origin.y) * 0.005;    

  float4 tmp_tex_x = tex_x * pixel_descs.dir_x - tex_y * pixel_descs.dir_y;
  float4 tmp_tex_y = tex_y * pixel_descs.dir_x + tex_x * pixel_descs.dir_y;

  tex_x = tmp_tex_x;
  tex_y = tmp_tex_y;
#endif // OCEAN

  // Scroll the bump maps
  tex_y = tex_y - pixel_descs.speed * time;// - slowdown;// * pixel_descs[0].speed;

  VSO.bumpCoords01.x = tex_x.x;
  VSO.bumpCoords01.y = tex_y.x;
  VSO.bumpCoords01.z = tex_x.y;
  VSO.bumpCoords01.w = tex_y.y;

  VSO.bumpCoords23.x = tex_x.z;
  VSO.bumpCoords23.y = tex_y.z;
  VSO.bumpCoords23.z = tex_x.w;
  VSO.bumpCoords23.w = tex_y.w;

#ifdef RIVER
  VSO.foamCoords.xy = VSO.bumpCoords01.xy;
  VSO.foamCoords.zw = VSO.bumpCoords01.zw;
  #ifdef RAINING
    VSO.rainCoords = (pos_tmp.xy) * 0.01;
  #endif
#endif
  // vertex-position in screen space
  VSO.screenCoordsInTexSpace = calcScreenToTexCoord(VSO.hposition);

  // transform the light vector into tangent space
  VSO.base_TS.xy  = mat_TS[0].xy;
  VSO.base_TS.zw  = mat_TS[1].xy;
#ifdef SM3_0
  VSO.toCamera.w  = sign( mat_TS[0].z ) >= 0.0 ?  1.0 : 0.0;
  VSO.toCamera.w += sign( mat_TS[1].z ) >= 0.0 ? 10.0 : 0.0;
#endif
  mat_TS          = transpose( mat_TS );
  VSO.toLight = mul( light_pos.xyz, mat_TS );
  
    // Output vector to camera
#ifdef MINIMAPMODE
    VSO.toCamera.xyz = normalize( -camera_pos.xyz );
#else
	  VSO.toCamera.xyz = mul( normalize( camera_pos.xyz - pos_tmp ), mat_TS );
#endif

  // pack vectors because the color registers are [0;1] in SM2
#ifdef SM2_0
  VSO.toLight  = normalize( VSO.toLight ) * 0.5 + 0.5;
  VSO.toCamera = VSO.toCamera * 0.5 + 0.5;
#endif

  // put (normalized!) distance&height
  VSO.depthDist.x  = VSO.hposition.w;   // depth of this pixel
  VSO.depthDist.y  = zfrustum_data.y;   // far plane needed to normalize the value read from the depth map
  VSO.depthDist.zw = 0;
#ifdef S2_FOG
  VSO.depthDist.zw = getFogTCs( VSO.hposition.w, fog_data );
#endif


#endif // NOT MASK

  return VSO;
}


//------------------------- PIXEL SHADER FOR MASK PASSES -------------------------------//

#ifdef PS_MASK
fragout mainPS( pixdata In, uniform float4 param )
{
	fragout PSO;
	PSO.col0 = 1.0;
#ifdef OCEAN
  // preliminary code for caustics
  PSO.col0.g = saturate( In.depth / param.x );
#endif
	return PSO;
}
#endif


//------------------------- JOINT PIXEL SHADER FOR WATER AND RIVER ---------------------//


// Pixel shader of river water rendering pass
#ifdef PS_WATER

//-------- Helper functions for Pixel Shader ----------- //

// Pretty expensive routine (unused at the moment)
float getFresnel( float3 incident, float3 normal, float n1, float n2 )
{
  // calculate refraction ray
  float3 refr = refract( incident, normal, n2 / n1 );
  float2 cos_theta = { saturate( -dot( incident, normal ) ), saturate( -dot( refr, normal ) ) };

  float  r_perp = ( n1 * cos_theta.x - n2 * cos_theta.y ) / ( n1 * cos_theta.x + n2 * cos_theta.y );
  float  r_par  = ( n1 * cos_theta.y - n2 * cos_theta.x ) / ( n1 * cos_theta.y + n2 * cos_theta.x );

  return 0.5 * (r_perp * r_perp + r_par * r_par);
}

// Cheap fresnel term, has nothing to do with fresnel equations, though - pure fake
float getSimpleFresnel( float3 eyeVec, float3 normal, float minimum, float maximum )
{
  return clamp( 1.0 - dot( eyeVec, normal ), minimum, maximum );
}


fragout mainPS (        pixdata     In,
                uniform sampler2D   texture0,                 // background texture
                uniform sampler2D   texture1,                 // mask texture
                uniform sampler2D   texture2,                 // bumpmap
                uniform sampler2D   texture3,                 // bumpmap
                uniform sampler2D   texture4,                 // bumpmap
                uniform sampler2D   texture5,                 // bumpmap
                uniform sampler2D   texture6,                 // foam at coast
                uniform sampler2D   texture7,                 // foam at coast
                uniform sampler2D   texture8,                 // foam on wave crests
                uniform sampler2D   depth_map,                // depth
                uniform samplerCUBE textureCube,              // environment texture
                uniform sampler3D   textureVolume,            // animated rain texture
                uniform sampler2D   fog_texture,              // fog texture
                uniform float4      light_col_diff,           // diffuse sunlight color
                uniform float4      light_col_amb,            // ambient color (contains the rain strength in w component)
                uniform float4      param,                    // lightning containing direction and intensity
                uniform float4      pix_data_array[PS_NUMOF]  // water parameters
                )
{
  fragout PSO;
  // Read the pixel shader constants
  float3 watercolor  = pix_data_array[PS_WATER_COLOR].rgb;
  float  depthfade   = pix_data_array[PS_WATER_COLOR].a;  
  float2 fresnel_lim = pix_data_array[PS_WATER_PARAMETERS].xy;
  float  spec_pow    = pix_data_array[PS_WATER_PARAMETERS].z;
  float  refr_str    = pix_data_array[PS_WATER_PARAMETERS].w;
  float2 foam_depth  = pix_data_array[PS_FOAM_PARAMETERS].xy;
  float2 shore_trans = pix_data_array[PS_FOAM_PARAMETERS].zw; // x is min transparency, y is depth scale
  // map interpolators
  float  depth       = In.params.z;
  float  viewdepth   = In.depthDist.x;
  // normalize vectors
#ifdef SM2_0
	float3 eyeVec   = normalize( In.toCamera - 0.5 );
  float3 lightVec = normalize( In.toLight  - 0.5 );
#else
  float3 eyeVec   = normalize( In.toCamera.xyz );
  float3 lightVec = normalize( In.toLight );
#endif
  float3 halfVec  = normalize( eyeVec + lightVec );

  // Read bump maps
  float3 bump0  = tex2D(texture2, In.bumpCoords01.xy).rgb;
  float3 bump1  = tex2D(texture3, In.bumpCoords01.zw).rgb;
  float3 bump2  = tex2D(texture4, In.bumpCoords23.xy).rgb;
  float3 bump3  = tex2D(texture5, In.bumpCoords23.zw).rgb;
  float3 norm   = normalize( 2.0 * (bump0 + bump1 + bump2 + bump3) - 4.0);

#ifdef RAINING
  // Read rain texture
  float  rain_str = light_col_amb.w;
  float3 looky3d  = { In.rainCoords.xy, In.params.x * 0.7 };
  float3 rain     = tex3D( textureVolume, looky3d );
#ifdef SM2_0
         norm     = normalize( 2.0 * (bump0 + bump1 + bump2 + bump3 + rain) - 5.0);
#else
         rain     = normalize( 2.0 * (bump0 + bump1 + bump2 + bump3 + rain) - 5.0);
         norm     = lerp( norm, rain, rain_str );
#endif
#endif


/*
#ifdef OCEAN
  // you can use this to fade into another bump map at the shore
  float  bump_lerp = In.params.x;
  float3 norm = normalize( bump0 + bump1 + bump2 );
         norm = lerp( bump3, norm, bump_lerp );
         norm = normalize( norm );
#endif

#ifdef RIVER
  float3 norm = normalize( bump0 + bump1 + bump2 + bump3 );
#endif
*/


  float4 refract_tcs = In.screenCoordsInTexSpace;

#ifdef SM3_0
  // Get vectors in world space
  float sign1 = sign( In.toCamera.w - 5.0 );
  float sign0 = sign( frac( In.toCamera.w / 10.0 ) - 0.05 );
  
  float3x3 mat_TS;
  mat_TS[0].xy = In.base_TS.xy;
  mat_TS[0].z  = sqrt( 1.0 - dot( In.base_TS.xy, In.base_TS.xy ) ) * sign0;
  mat_TS[1].xy = In.base_TS.zw;
  mat_TS[1].z  = sqrt( 1.0 - dot( In.base_TS.zw, In.base_TS.zw ) ) * sign1;
  mat_TS[2]    = cross( mat_TS[0], mat_TS[1] );

  // calculate vectors for environment lookup
  float3 norm_WS = mul( norm, mat_TS );
  float3 eye_WS  = mul( eyeVec, mat_TS );
  // get the environment
  float3 environment = texCUBE( textureCube, reflect( - eye_WS, norm_WS ) ).rgb;
  // Use the normal for image space refraction
         refract_tcs.xy += norm_WS.xy * refr_str;
  float4 mask            = tex2Dproj( texture1, refract_tcs );
         refract_tcs     = mask.r > 0.0 ? refract_tcs : In.screenCoordsInTexSpace;

   // calculate lightning
   float3 lightning_WS = normalize( param.xyz );
   float  lightning    = step( 0.4, dot( norm_WS, lightning_WS ) ) * param.w;
#else
  float3 environment = texCUBE( textureCube, reflect( - eyeVec, norm ) ).rgb;
  float  lightning   = 0.0;
#endif

  // Read background color
  float4 background  = tex2Dproj( texture0, refract_tcs );
  float  grounddepth = tex2Dproj( depth_map, refract_tcs ).x * In.depthDist.y;
  float  waterdepth  = ( grounddepth - viewdepth ) / S2_WORLD_METER; // water depth in m along viewing axis
         waterdepth  = waterdepth < 0.0 ? 0.0 : waterdepth;
                  
  // Calculate factor for fading the background color into the water color
  float  attenuation = exp( - waterdepth * depthfade );

  // some cosines
  float  diffuse   = saturate( dot( norm, lightVec ) );
         diffuse   = diffuse < 0.5 ? 0.5 : diffuse;
  float  specular  = pow( saturate( dot( norm, halfVec ) ), spec_pow );

#ifdef SM3_0
  // calculate foam
  float4 foam_soft   = tex2D( texture6, In.foamCoords.xy );
  float4 foam_hard   = tex2D( texture7, In.foamCoords.zw );
  float  weight_soft = pow( cos( saturate( depth / foam_depth.x ) * S2_PI * 0.5 ), 1.0 );
  float  weight_hard = pow( cos( saturate( depth / foam_depth.y ) * S2_PI * 0.5 ), 1.0 );
  float4 foam        = diffuse * ((foam_soft * weight_soft) + (foam_hard * weight_hard));
#ifdef RIVER
         //foam       *= In.params.y; // fade the foam in for the last segment
#endif
#else
  float4 foam = 0;
#endif

  float3 crest = 0;
#ifdef SM3_0
#ifndef MINIMAPMODE
  // wave crest calculations
  if( In.params.y < 0.0 )
    crest = diffuse * tex2D( texture8, In.foamCoords.zw * 1.0 ).rgb * 25 * (-In.params.y) * ( 1.0 - saturate(depth / 3.5) );
#endif
#endif

  // calculate the fresnel term
  //float fresnel  = saturate( abs( getFresnel( -eyeVec, norm, 1.0, 1.3 ) ) );
  float  fresnel   = getSimpleFresnel( eyeVec, norm, fresnel_lim.x, fresnel_lim.y );

  // compose underwater and abovewater colors, modulate with sun light intensity
#ifdef LOWEND_PIPELINE
  float3 underwater = watercolor * (light_col_diff.a < 0.35 ? 0.35 : light_col_diff.a);
#else
  float3 underwater = lerp( watercolor, background, attenuation ) * (light_col_diff.a < 0.35 ? 0.35 : light_col_diff.a);
#endif

//  float3 abovewater = (specular * 5.0 + environment) * light_col_diff.rgb;
  float3 abovewater = ( specular * 5.0 ) * light_col_diff.rgb + environment;
  
  // compose final color
#ifdef ALPHA_BLEND_FOAM
  float3 result = lerp( underwater, abovewater, fresnel );
         result = lerp( result, foam.rgb * light_col_diff.rgb, foam.a ) + crest * light_col_diff.rgb;
#else
  float3 result = lerp( underwater, abovewater, fresnel ) + ( foam.rgb + crest ) * light_col_diff.rgb;
#endif


#ifdef S2_FOG
  // fog
  fogDiffuse( result, fog_texture, In.depthDist.zw, light_col_diff );
  fogPnt( lightning, fog_texture, In.depthDist.zw );
#endif

  result += lightning;

#ifdef RIVER
  PSO.col0.rgb = result;
  PSO.col0.a   = clamp( depth * shore_trans.y, shore_trans.x, 1.0 ) * In.params.w;
#else
  PSO.col0.rgb = result;
  PSO.col0.a   = clamp( depth * shore_trans.y, shore_trans.x, 1.0 );
#endif

  PSO.col1     = 0.0;
  //PSO.col1     = lightning * 0.1;
  //PSO.col1.a   = lightning > 0.0 ? 1.0 : 0.0;

	return PSO;
}
#endif



//------------------ DUMMY PIXEL SHADER FOR SM1_1 ----------------------//

#ifdef PS_DUMMY
fragout mainPS( pixdata In )
{
  fragout PSO;
  PSO.col0 = float4( 0.1, 0.1, 0.4, 0.7 );
  return PSO;
}
#endif






#else

//#################################################################
//#                                                               #
//#                       OLD WATER SHADER                        #
//#                                                               #
//#################################################################



#ifdef LAYER_BIT0
  #define OCEAN
#endif

#ifdef LAYER_BIT1
  #define RIVER
#endif

#ifdef LAYER_BIT2
  #define MASK
#endif

#ifdef LAYER_BIT3
  #define RAINING
#endif

#ifdef SPASS_DECALS
  #define DECALS
#endif

struct WaveRecord {
	float y;
	float3 Position;
	//float3 Normal;
};

#define SECTOR_SIZE 3200.0f

// ----------------------------------------------------------------------------
// calculate per-vertex displacement and derivatives
WaveRecord CalculateWaves (float3 position, float weight, float2 time, float4 waveheight,float4 waveDirSpeed)
{
  WaveRecord Out;

  float wavePos = position.x * waveDirSpeed.x + position.y * waveDirSpeed.y; // dot really
  float periodicyValue = 6.283185307 / (100.0 * (abs(waveDirSpeed.x) + abs(waveDirSpeed.y))); // 2 * PI / (sector_size * size scale) - this value can be precalced, given a set direction!

  wavePos = wavePos * periodicyValue;

  float4 sins;
  float4 coss;
  sincos(time.xxxx * waveDirSpeed.zzzz + float4(wavePos, wavePos / 2.0, wavePos / 4.0, wavePos / 8.0), sins, coss);
  sins = sins * 0.5 + 0.5; // change range from -1..1 to 0..1
  Out.y = waveheight.x * (dot(sins, float4(0.35, 0.0, 0.2, 0.15)) + dot(coss, float4(0.0, 0.3, 0.0, 0.0))); // relative importance for each term (ought to add up to 1.0)

	// set to zero - there is no way to render water sectors seamless since we're using multiple matrices 
	//Out.y = 0;

	Out.Position = position + float3( 0, 0, Out.y );
	//Out.Normal = normalize( float3( 0, 1, 0 ) + dN * weight );

	return Out;
}


//--------------------- MASK ------------------------//

#ifdef MASK // Mask pass
  #define PS_MASK
  #define VS_IN_worldViewProjMatrix

  #ifdef RIVER
    struct appdata
    {
	    float4 position    : POSITION;
	    float4 normal      : NORMAL;
	    float4 texcoord    : TEXCOORD0;
    };
  #endif

  #ifdef OCEAN
    #define VERTEXARRAY_INDICES
    #define VS_IN_worldMatrix
    #define VS_IN_light_pos
    #define VS_IN_camera_pos
    #define VS_IN_vtx_data_array[VERTEXARRAY_NUMOF]
    #define VS_IN_target_data

    struct appdata
    {
	    float3 position   : POSITION;
	    float3 normal     : NORMAL;
	    float3 tangent    : TANGENT;
    };

  #endif
  struct pixdata 
  {
	  float4	hposition	: POSITION;
  };

//--------------------- NON-MASK ------------------------//

#else // normal rendering pass

//---------------- RIVER ------------------//

  // river water specific
  #ifdef RIVER
    // Set Pixel shader
    #ifdef SM1_1
      #define PS_DUMMY
    #else
      #define PS_WATER
      #define PS_OUT_col1
    #endif

    #define VS_IN_worldViewProjMatrix
    #define VS_IN_worldMatrix
    #define VS_IN_camera_pos
    #define VS_IN_vtx_data_array
    #define VS_IN_target_data
    #define VS_IN_zfrustum_data
  #ifdef S2_FOG
    #define VS_IN_fog_data
  #endif

    struct appdata
    {
	    float4 position    : POSITION;
	    float4 normal      : NORMAL;
	    float4 texcoord    : TEXCOORD0;
    };

    struct pixdata
    {
	    float4	hposition			          : POSITION;
	    float4  DepthDist               : TEXCOORD1;	// w = interpolated depth
	    half3	  V				                : TEXCOORD2;
	    float4  sectorPos               : TEXCOORD3;
	    float4	PerturpationCoordAB	    : TEXCOORD4;
	    float4	PerturpationCoordCD	    : TEXCOORD5;
	    float4	ScreenCoordsInTexSpace  : TEXCOORD6;
    };

    //-------------- Shader specific defines -------------------//

    // ----------- Vertex shader defines -------------//

    // specular width
    #define WATER_SPECULAR_POWER 32 //256
    // strength of specular color
    #define SPECULARSTRENGTH    0.35 //0.55
    // strength of environmental reflection
    #define ENVMAPSTRENGTH      0.15
    // caustic strength factor
    #define CAUSTICSTRENGTH     0.80

    // River water specific defines
    #define FRESNEL_B 0.05
    #define FRESNEL_M 0.97
    #define FRESNEL_POWER 2

    #define PARAM_POS 0
    #define PARAM_TANGENT 1
    #define PARAM_NORMAL 2
    #define PARAM_BINORMAL 3
    #define PARAM_NUMOF 4

    #define VERTEXARRAY_TIMEMISC       0
    #define VERTEXARRAY_RIPPLEDESC1	   1
    #define VERTEXARRAY_RIPPLEDESC2	   2
    #define VERTEXARRAY_RIPPLEDESC3	   3

    #define VERTEXARRAY_RIPPLEPLANES1  4
    #define VERTEXARRAY_RIPPLEPLANES2  5
    #define VERTEXARRAY_RIPPLEPLANES3  6
    #define VERTEXARRAY_RIPPLEPLANES4  7
    #define VERTEXARRAY_RIPPLEPLANES5  8
    #define VERTEXARRAY_RIPPLEPLANES6  9
    #define VERTEXARRAY_RIPPLEPLANES7  10
    #define VERTEXARRAY_RIPPLEPLANES8  11
    #define VERTEXARRAY_NUMOF          12

    // ----------- Pixel shader defines  -------------//

    #define PIXELARRAY_LIGHTDIR        0
    #define PIXELARRAY_RIPPLEHEIGHTS1  1
    #define PIXELARRAY_RIPPLEHEIGHTS2  2
    #define PIXELARRAY_PARAM           3
    #define PIXELARRAY_WATERCOLOR1     4
    #define PIXELARRAY_WATERCOLOR2     5
    #define PIXELARRAY_AMBIENT         6
    #define PIXELARRAY_WEATHER         7
    #define PIXELARRAY_NUMOF           8

  #endif

//------------------- OCEAN ------------------//

  // Ocean shaders
  #ifdef OCEAN
    // Set Pixel shader
    #ifdef SM1_1
      #define PS_DUMMY
    #else
      #define PS_WATER
      #define PS_OUT_col1
    #endif

    #define VERTEXARRAY_INDICES
    #define VS_IN_worldViewProjMatrix
    #define VS_IN_worldMatrix
    #define VS_IN_light_pos
    #define VS_IN_camera_pos
    #define VS_IN_vtx_data_array
    #define VS_IN_target_data
    #define VS_IN_zfrustum_data
  #ifdef S2_FOG
    #define VS_IN_fog_data
  #endif

    struct appdata
    {
	    float3 position   : POSITION;
	    float3 normal     : NORMAL;
	    float2 texcoord   : TEXCOORD0;
    };

    struct pixdata 
    {
	    float4	hposition               : POSITION;
	    float4  DepthDist               : TEXCOORD1;	// w = interpolated depth
	    half3	  V                       : TEXCOORD2;
	    float4  sectorPos               : TEXCOORD3;
	    float4	PerturpationCoordAB     : TEXCOORD4;
	    float4	PerturpationCoordCD     : TEXCOORD5;
	    float4	ScreenCoordsInTexSpace  : TEXCOORD6;
    };

    //-------------- Shader specific defines -------------------//

    // specular width
    #define WATER_SPECULAR_POWER 32 //256
    // strength of specular color
    #define SPECULARSTRENGTH    0.35 //0.55
    // strength of environmental reflection
    #define ENVMAPSTRENGTH      0.15
    // caustic strength factor
    #define CAUSTICSTRENGTH     0.80

    // ----------- Pixel shader defines  -------------//

    #define PIXELARRAY_RIPPLEHEIGHTS    0	// 2 constants
    #define PIXELARRAY_AMBIENT          2
    #define PIXELARRAY_PARAM            3	// x=shoreLineFactor  y=deepWaterFactor z=specFactCol w=specFactGlow
    #define PIXELARRAY_WEATHER          4
    #define PIXELARRAY_LIGHTDIR         5
    #define PIXELARRAY_WATERCOLOR1      6
    #define PIXELARRAY_WATERCOLOR2      7
    #define PIXELARRAY_NUMOF            8

  #endif

//-------------------- DECALS ----------------//

  #ifdef DECALS
    // Set Pixel shader
    #ifdef SM1_1
      #define PS_DUMMY
    #else
      #define PS_DECALS
    #endif

    #define VS_IN_worldViewProjMatrix
    #define VS_IN_worldMatrix
    #define VS_IN_light_pos
    #define VS_IN_camera_pos
    #define VS_IN_vtx_data_array
    #define VS_IN_target_data

    struct appdata
    {
      float4 color      : COLOR0;
      float2 uv         : TEXCOORD0;
    };

    struct pixdata
    {
      float4  hposition	    	  	: POSITION;
      half4	  Color       		  	: COLOR0;
      //half4	N					: TEXCOORD1;	// w = interpolated depth
      float3	V				          	: TEXCOORD2;
      float3	L					          : TEXCOORD3;
      float2	TexCoord01			    : TEXCOORD4;
      float4	PerturpationCoordAB	: TEXCOORD5;
    };

    // water wave overlays
    //-------------- Shader specific defines -------------------//

    // ----------- Vertex shader defines -------------//

    #define SECOND_RIPPLE_STRENGTH	0.50
    #define WATER_SPECULAR_POWER 64


    #define MAX_SEGMENTS 64

    #define VERTEXARRAY_TIMEMISC      0
    #define VERTEXARRAY_RIPPLEPLANES  1   // 2 constants
    #define VERTEXARRAY_WAVEPLANES    3   // 4 constants
    #define VERTEXARRAY_WAVEHEIGHT    7
    #define VERTEXARRAY_DYNAMIC       8
    #define VERTEXARRAY_WATERCOLOR    9
    #define VERTEXARRAY_VERRTEXANIM   10

    #define VERTEXARRAY_SEGMENTSTART  11

    #define VERTEXARRAY_NUMOF         VERTEXARRAY_SEGMENTSTART+1+MAX_SEGMENTS*3


    // ----------- Pixel shader defines  -------------//

  #endif

#endif

// all purpose fragment output struct
struct fragout
{
  float4 col0        : COLOR0;
#ifdef PS_OUT_col1 // used by all non-mask passes
  float4 col1        : COLOR1;
#endif
};



// used for indexing the uniform VS input array
#ifdef VERTEXARRAY_INDICES
  #define VERTEXARRAY_TIMEMISC      0
  #define VERTEXARRAY_RIPPLEPLANES  1   // 8 constants
  #define VERTEXARRAY_WAVEPLANES    9   // 4 constants
  #define VERTEXARRAY_WAVEHEIGHT    13
  #define VERTEXARRAY_WATERCOLOR    14
  #define VERTEXARRAY_CAUSTIC       16
  #define VERTEXARRAY_VERRTEXANIM   17
  #define VERTEXARRAY_NUMOF         18
#endif




pixdata mainVS(   appdata I
#ifdef VS_IN_worldViewProjMatrix
                ,uniform float4x4 worldViewProjMatrix
#endif
#ifdef VS_IN_worldMatrix
                ,uniform float4x4 worldMatrix
#endif
#ifdef VS_IN_light_pos
                ,uniform float4   light_pos
#endif
#ifdef VS_IN_camera_pos
                ,uniform float4   camera_pos
#endif
#ifdef VS_IN_vtx_data_array
                ,uniform float4   vtx_data_array[VERTEXARRAY_NUMOF]
#endif
#ifdef VS_IN_zfrustum_data
                ,uniform float4   zfrustum_data
#endif
#ifdef VS_IN_fog_data
                ,uniform float4   fog_data
#endif
                                                                )
{
  pixdata VSO;
//--------------- BEGIN MASK VS --------------//
#ifdef MASK

  #ifdef OCEAN
	  float3 worldPosition  = mul(I.position,worldMatrix);
    float4 TimeMisc       = vtx_data_array[VERTEXARRAY_TIMEMISC];
	  WaveRecord wave       = CalculateWaves(worldPosition, 1.0, TimeMisc.xy,vtx_data_array[VERTEXARRAY_WAVEHEIGHT],vtx_data_array[VERTEXARRAY_VERRTEXANIM]);
	  worldPosition         = wave.Position;
	  // transform position into clipspace	
	  VSO.hposition = mul(float4(worldPosition,1), worldViewProjMatrix);
  #endif
  #ifdef RIVER
	  float4 worldPosition = float4(I.position.xyz / I.position.w + I.texcoord.www, 1.0);
	  // vertex pos
	  VSO.hposition         = mul(worldPosition, worldViewProjMatrix);
  #endif
//------------------ END MASK VS -----------------//
#else
//-------------------- RIVER VS -------------------//
  #ifdef RIVER
    float4 worldPosition = float4( I.position.xyz / I.position.w + I.texcoord.www, 1.0 );
	  float4 nrm4 = float4( I.normal.xyz * 2.0 - 1.0, 0.0 );

	  float4 TimeMisc = vtx_data_array[VERTEXARRAY_TIMEMISC];

	  // vertex pos
	  VSO.hposition = mul(worldPosition, worldViewProjMatrix);

	  // vertex-position in screen space
    VSO.ScreenCoordsInTexSpace = calcScreenToTexCoord(VSO.hposition);

  /*
	  float2 ripplePos = _In.texcoord.xy / 256.0;
	  Out.PerturpationCoordAB.x = dot(float4(worldPosition.xzy, ripplePos.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES1]);
	  Out.PerturpationCoordAB.y = dot(float4(worldPosition.xzy, ripplePos.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES2]);
	  Out.PerturpationCoordAB.z = dot(float4(worldPosition.xzy, ripplePos.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES3]);
	  Out.PerturpationCoordAB.w = dot(float4(worldPosition.xzy, ripplePos.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES4]);
	  Out.PerturpationCoordCD.x = dot(float4(worldPosition.xzy, ripplePos.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES5]);
	  Out.PerturpationCoordCD.y = dot(float4(worldPosition.xzy, ripplePos.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES6]);
	  Out.PerturpationCoordCD.z = dot(float4(worldPosition.xzy, ripplePos.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES7]);
	  Out.PerturpationCoordCD.w = dot(float4(worldPosition.xzy, ripplePos.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES8]);
  */

	  worldPosition = mul(float4( I.position.xyz / I.position.w + I.texcoord.www, 1 ), worldMatrix);
    // calculate view vector
#ifdef MINIMAPMODE
    VSO.V = normalize( -camera_pos.xyz );
#else
	  VSO.V = normalize(worldPosition - camera_pos.xyz);
#endif

	  // calculate texture coordinates
	  float2 ripplePos = I.texcoord.xy / 256.0;

	  // get UV coordinates	
	  VSO.PerturpationCoordAB.xyzw = ripplePos.xyxy * vtx_data_array[VERTEXARRAY_RIPPLEDESC1+0].xxyy;
	  // add speed
	  VSO.PerturpationCoordAB.xyzw += vtx_data_array[VERTEXARRAY_TIMEMISC].x * vtx_data_array[VERTEXARRAY_RIPPLEDESC1+1].xyzw;

	  // get UV coordinates	
	  VSO.PerturpationCoordCD.xyzw = ripplePos.xyxy * vtx_data_array[VERTEXARRAY_RIPPLEDESC1+0].zzww;
	  // add speed
	  VSO.PerturpationCoordCD.xyzw += vtx_data_array[VERTEXARRAY_TIMEMISC].x * vtx_data_array[VERTEXARRAY_RIPPLEDESC1+2].xyzw;
	  
	  //zFrustumData = vector4d( zn, zf, 1.f / (zf-zn), 1.0f/zf);

//	  VSO.DepthDist.x = (VSO.hposition.w - zfrustum_data.x) * zfrustum_data.z;
	  VSO.DepthDist.x = VSO.hposition.w * zfrustum_data.w;
	  VSO.DepthDist.y = TimeMisc.z / distance(worldPosition, camera_pos.xyz);
#ifdef S2_FOG
//    VSO.DepthDist.z = (VSO.hposition.w - fog_data.x) * zfrustum_data.z;
    VSO.DepthDist.zw = getFogTCs(VSO.hposition.w, fog_data);
#else
    VSO.DepthDist.zw = 0;
#endif


	  // sector position
	  VSO.sectorPos = float4(worldPosition.xyz, TimeMisc.y);
  #endif

//-------------------- OCEAN VS -------------------//

  #ifdef OCEAN
   float3 worldPosition = I.position;
   float4 TimeMisc      = vtx_data_array[VERTEXARRAY_TIMEMISC];

	  WaveRecord wave = CalculateWaves(worldPosition, 1.0, TimeMisc.xy, vtx_data_array[VERTEXARRAY_WAVEHEIGHT],vtx_data_array[VERTEXARRAY_VERRTEXANIM]);
	  worldPosition = wave.Position;
  	
	  // transform position into clipspace	
	  VSO.hposition = mul(float4(worldPosition,1), worldViewProjMatrix);
  		
	  // calculate normal vector and distance value	
	  //VSO.N = half4(0, 0, 1, TimeMisc.z / distance(worldPosition,camera_pos.xyz));

	  worldPosition = mul(float4(I.position,1),worldMatrix);

	  // calculate view vector
#ifdef MINIMAPMODE
    VSO.V = normalize( -camera_pos.xyz );
#else
	  VSO.V = normalize(worldPosition - camera_pos.xyz);
#endif

	  // calculate perturpation texture coordinates for each ripple
	  VSO.PerturpationCoordAB.x = dot(float4(worldPosition.xzy, TimeMisc.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES+0]);
	  VSO.PerturpationCoordAB.y = dot(float4(worldPosition.xzy, TimeMisc.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES+1]);
	  VSO.PerturpationCoordAB.z = dot(float4(worldPosition.xzy, TimeMisc.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES+2]);
	  VSO.PerturpationCoordAB.w = dot(float4(worldPosition.xzy, TimeMisc.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES+3]);
	  VSO.PerturpationCoordCD.x = dot(float4(worldPosition.xzy, TimeMisc.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES+4]);
	  VSO.PerturpationCoordCD.y = dot(float4(worldPosition.xzy, TimeMisc.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES+5]);
	  VSO.PerturpationCoordCD.z = dot(float4(worldPosition.xzy, TimeMisc.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES+6]);
	  VSO.PerturpationCoordCD.w = dot(float4(worldPosition.xzy, TimeMisc.x ), vtx_data_array[VERTEXARRAY_RIPPLEPLANES+7]);
    
	  // save refraction UV coordinates	
	  //Out.ScreenPos = Out.Position;
	  // vertex-position in screen space
    VSO.ScreenCoordsInTexSpace = calcScreenToTexCoord(VSO.hposition);

	  /// put (normalized!) distance&height
//	  VSO.DepthDist.x = (VSO.hposition.w - zfrustum_data.x) * zfrustum_data.z;
	  VSO.DepthDist.x = VSO.hposition.w * zfrustum_data.w;
	  VSO.DepthDist.y = TimeMisc.z / distance(worldPosition, camera_pos.xyz);
#ifdef S2_FOG
//    VSO.DepthDist.z = saturate( (VSO.hposition.w - fog_data.x) * zfrustum_data.z );
    VSO.DepthDist.zw = getFogTCs(VSO.hposition.w, fog_data);
#else
    VSO.DepthDist.zw = 0;
#endif

	  // sector position
	  VSO.sectorPos = float4(worldPosition.xyz, TimeMisc.w);
  #endif

//-------------------- DECALS VS -------------------//

  #ifdef DECALS

    // map constants
    float4 TimeMisc = vtx_data_array[VERTEXARRAY_TIMEMISC];

    int iIndices[4] = (int[4]) D3DCOLORtoUBYTE4(I.color);
    int iSegmentIndex = VERTEXARRAY_SEGMENTSTART + iIndices[0] * 3;

      //int iIndex = 0;
	  float4 direction_length = vtx_data_array[iSegmentIndex];
	  float4 origin = vtx_data_array[iSegmentIndex+1];
	  float endLength = pow(TimeMisc.w, vtx_data_array[VERTEXARRAY_DYNAMIC].z);
	  float startLength = endLength * vtx_data_array[VERTEXARRAY_DYNAMIC].w;
	  float length = lerp(endLength, startLength, I.uv.y);
    	
	  origin.xyz += direction_length.xyz * direction_length.w * length;
	  float3 worldPosition = origin.xyz;

	  WaveRecord wave = CalculateWaves(worldPosition, 1.0, TimeMisc.xy, vtx_data_array[VERTEXARRAY_WAVEHEIGHT], vtx_data_array[VERTEXARRAY_VERRTEXANIM]);
	  worldPosition = wave.Position;
  	
	  // transform position into clipspace	
	  VSO.hposition = mul(float4(worldPosition,1), worldViewProjMatrix);

	  // get tangent space
	  float3 normal = direction_length.xyz;
	  float3 tangent = vtx_data_array[iSegmentIndex+2].xyz;
	  float3 binormal = direction_length.xyz;
  	
	  // calculate view vector
    worldPosition = mul(float4(worldPosition,1),worldMatrix);
	  float3 view = normalize(worldPosition - camera_pos.xyz);
	  // transform view vector into tangent space
#ifdef MINIMAPMODE
    VSO.V = normalize( camera_pos.xyz );
#else
	  VSO.V.x = dot(view, tangent);
	  VSO.V.y = dot(view, binormal);
	  VSO.V.z = dot(view, float3(0,0,1));
#endif

	  // transform light into tangent space
	  VSO.L.x = dot(light_pos.xyz, tangent);
	  VSO.L.y = dot(light_pos.xyz, binormal);
	  VSO.L.z = dot(light_pos.xyz, float3(0,0,1));
  	
	  VSO.TexCoord01 = I.uv * vtx_data_array[VERTEXARRAY_DYNAMIC].xy;

	  VSO.PerturpationCoordAB.xy = I.uv * vtx_data_array[VERTEXARRAY_RIPPLEPLANES+0].xy;
	  VSO.PerturpationCoordAB.zw = I.uv * vtx_data_array[VERTEXARRAY_RIPPLEPLANES+1].xy;

	  VSO.PerturpationCoordAB.xy += TimeMisc.x * vtx_data_array[VERTEXARRAY_RIPPLEPLANES+0].zw;
	  VSO.PerturpationCoordAB.zw += TimeMisc.x * vtx_data_array[VERTEXARRAY_RIPPLEPLANES+1].zw;
  	
	  // save watercolors
	  VSO.Color = vtx_data_array[VERTEXARRAY_WATERCOLOR];
    // multiply with segment fade value
    VSO.Color.a *= vtx_data_array[iSegmentIndex+1].w;

  #endif

#endif

  return VSO;
}


//------------------------- PIXEL SHADER FOR MASK PASSES -------------------------------//

#ifdef PS_MASK
fragout mainPS( pixdata In )
{
	fragout PSO;
	PSO.col0 = float4(1.0, 0.0, 0.0, 1.0);
	return PSO;
}
#endif


//------------------------- JOINT PIXEL SHADER FOR WATER AND RIVER ---------------------//


// Pixel shader of river water rendering pass
#ifdef PS_WATER

//-------- Helper functions for Pixel Shader ----------- //

half Fresnel(half _NdotL, half _fresnelBias, half _fresnelPow)
{
	half facing = (1.0-_NdotL);
	return max(_fresnelBias + (1.0 - _fresnelBias) * (pow(facing, _fresnelPow)), 0.0);
}

// decode depth from 2-channel-encoded-depthbuffer
/*
float getDepth(float2 encoded)
{
  return dot(encoded, float2(1.0, 1.0 / 256.0));
}

*/

float getDepth(in sampler2D depth_map,float4 texcoord,float cur_w)
{
  float val = tex2Dproj(depth_map,texcoord).x;
  return val-cur_w;
}

fragout mainPS (pixdata In,
                uniform sampler2D   texture0, // pertub
                uniform sampler2D   texture1, // refraction
                uniform sampler2D   texture2, // mask texture
                uniform sampler2D   texture3, // depth
                uniform sampler2D   depth_map, //depth
                uniform samplerCUBE textureCube,
                uniform sampler3D   textureVolume,
                uniform sampler2D   fog_texture,
                uniform float4      light_col_diff,
                uniform float4      light_col_amb,
                uniform float4    fog_color,
                uniform float4      pix_data_array[PIXELARRAY_NUMOF] )
{
	half3 eyeVec = normalize(In.V);

  float4 ripple_heights, ripple_heights2;
#ifdef OCEAN
  ripple_heights  = pix_data_array[PIXELARRAY_RIPPLEHEIGHTS];
  ripple_heights2 = pix_data_array[PIXELARRAY_RIPPLEHEIGHTS+1];
#endif
#ifdef RIVER
  ripple_heights = pix_data_array[PIXELARRAY_RIPPLEHEIGHTS1];
  ripple_heights2 = pix_data_array[PIXELARRAY_RIPPLEHEIGHTS1+1];
#endif

	half3 BumpTexA = ripple_heights.x * tex2D(texture0, In.PerturpationCoordAB.xy).rgb;
	half3 BumpTexB = ripple_heights.y * tex2D(texture0, In.PerturpationCoordAB.zw).rgb;
	half3 BumpTexC = ripple_heights.z * tex2D(texture0, In.PerturpationCoordCD.xy).rgb;
	half3 BumpTexD = ripple_heights.w * tex2D(texture0, In.PerturpationCoordCD.zw).rgb;
  half3 BumpAll = (BumpTexA + BumpTexB + BumpTexC + BumpTexD) + ripple_heights2.xyz;

	BumpAll = normalize(BumpAll);
	
	// rain platscher intensity
	float rainIntensity = pix_data_array[PIXELARRAY_WEATHER].x;

  // ripple effect on water caused by rain drops
#ifdef RAINING
	// rain platscher offset!
	float3 lookup = frac(In.sectorPos.xyw * float3(0.015, 0.015, 1.0));
	modf(In.sectorPos.w, lookup.z);
	lookup.z = (lookup.z / 32.0) + (1.0 / 64.0);
	s2half4 rainringTex = tex3D(textureVolume, lookup);
	s2half3 rainringNrm = normalize(rainringTex.xyz - s2half3(0.5, 0.5, 0.5));
	
	// linear interpolate between standard waves and raindrops
	BumpAll = lerp(BumpAll, rainringNrm, rainIntensity * saturate(rainringTex.a + 0.3));
#endif

	// Calculate refraction UV coordinates
	half3  refractionBump  = BumpAll * half3(4.5, 4.5, 1.0); // * half3(0.025, 0.025, 1.0);
	float4 refractionCoord = In.ScreenCoordsInTexSpace;
    // Get distorted depth from map
	float4 distortedCoord     = refractionCoord;
	       distortedCoord.xy += refractionBump;
	// get mask pixel
	float4 maskCoord = distortedCoord;
	half4  maskPixel = tex2Dproj(texture2, maskCoord);

#ifdef SM3_0
  // Get depth from map
	float depthMapA   = getDepth(depth_map, refractionCoord,In.DepthDist.x);
	float depthMapB   = getDepth(depth_map, distortedCoord,In.DepthDist.x);
	float depthMinMap = saturate( min(depthMapA, depthMapB*maskPixel.r) );
	// Get depth fadein value (0: low depth, 1: high depth)
	half waterFadeInFactor = saturate(depthMinMap * pix_data_array[PIXELARRAY_PARAM].x);
	// Get distorted refraction UV coordinates
  refractionCoord.xy += refractionBump * waterFadeInFactor; // refractionCoord.w;
#else
  refractionCoord.xy += refractionBump;// refractionCoord.w;
#endif

	// Get final refraction color
	half4 refractionMap = tex2Dproj(texture1, refractionCoord);
#ifdef SM3_0
	// Get final depth
	float depthMap = getDepth(depth_map, refractionCoord,In.DepthDist.x);
	half deepWaterFactor = saturate(depthMap * pix_data_array[PIXELARRAY_PARAM].y);
#endif

  // multiply with global ambient color
#ifdef MINIMAPMODE
  float4 baseColor = float4( 1.2, 1.2, 1.2, 1.0 );
#else
	float4 baseColor = pix_data_array[PIXELARRAY_AMBIENT];
#endif

	// Add caustic brightness
#ifdef SM3_0
  refractionMap += maskPixel.gggg * CAUSTICSTRENGTH * baseColor * deepWaterFactor;
#else
	refractionMap += maskPixel.gggg * CAUSTICSTRENGTH * baseColor;
#endif

	// Calculate reflection UV coordinates
	half3 reflectionBump = BumpAll * half3(0.08, 0.08, 1);
	// Get reflection color value
	half3 reflectionMap = half3(0,0,0); //tex2Dproj(texture4, reflectionCoord);
	
	// Calculate reflect vector
	half3 R = reflect(eyeVec, BumpAll.xyz);
	// Get environmental color
	half3 envMap = texCUBE(textureCube, R);

	// Compute Fresnel term
	half NdotL = max(dot(-eyeVec, reflectionBump.xyz), 0);
	half facing = (1.0 - NdotL);
	half fresnel = Fresnel(NdotL, 0.2, 5.0);


  // Use distance to lerp between refraction and deep water color
#ifdef SM3_0
	half fDistScale = 1 - deepWaterFactor;
#else
  half fDistScale = 1 - In.DepthDist.y;
#endif
  // for the minimap we ignore the refraction part and just take the water and specular color
#ifdef MINIMAPMODE
  fDistScale = 0.0;
#endif

  // Calculate the water color
  half3 watcol1 = pix_data_array[PIXELARRAY_WATERCOLOR1];
  half3 watcol2 = pix_data_array[PIXELARRAY_WATERCOLOR2];
  // Calculate deep water color
	half3 WaterDeepColor = (refractionMap.rgb * fDistScale + (1 - fDistScale) * watcol1);
	// Lerp between water color and deep water color
	half3 waterColor = lerp(WaterDeepColor, watcol2, facing);
#ifdef RAINING  
  waterColor += 0.3 * rainIntensity * rainringTex.a * watcol1;
#endif


  // Specular terms
  half3 specFactCol  = pix_data_array[PIXELARRAY_PARAM].z;
	half3 specFactGlow = pix_data_array[PIXELARRAY_PARAM].w;
  half specular      = pow(saturate(dot(R, pix_data_array[PIXELARRAY_LIGHTDIR].xyz)), WATER_SPECULAR_POWER);
  half3 specularcol  = specular * light_col_amb;
	half3 cReflect     = fresnel  * reflectionMap;
	cReflect += (specularcol * specFactCol) + /*fresnel **/ envMap * ENVMAPSTRENGTH * baseColor;


  // Final Result
	half3 result = cReflect + waterColor; 
#ifdef SM3_0
#ifndef MINIMAPMODE
  // Lerp refraction map to fadein low water surfaces
  result = lerp(refractionMap.rgb,result, saturate(depthMap*pix_data_array[PIXELARRAY_PARAM].x));
#endif
#endif

  float3 glow = specularcol * specFactGlow;
#ifdef S2_FOG
  fogDiffuse( result, fog_texture, In.DepthDist.zw, fog_color );
  fogGlow( glow, fog_texture, In.DepthDist.zw);
#endif

	fragout O;
	O.col0 = float4( result,1 );
  O.col1 = float4( glow  ,1 );
	return O;
}
#endif

//------------------------- DECAL PIXEL SHADER ------------------------------------//

#ifdef PS_DECALS
fragout mainPS(pixdata I,
               uniform sampler2D texture0, // diffuse 
               uniform sampler2D texture1, // bump
               uniform float4    light_col_amb)
{
	fragout PSO;
 
	// renormalize vectors
	half3 eyeVec = normalize(I.V);
	half3 lightVec = normalize(I.L);

	// calculate ripple heights	
	half3 BumpTexA = tex2D(texture1, I.PerturpationCoordAB.xy).rgb - 0.5f;
	half3 BumpTexB = tex2D(texture1, I.PerturpationCoordAB.zw).rgb - 0.5f;
	half3 Normal = normalize( BumpTexA + BumpTexB * SECOND_RIPPLE_STRENGTH);
	
	// get color
	half4 colorAlpha = tex2D(texture0, I.TexCoord01);
  // modulate with water color
	colorAlpha *= I.Color;
	
	// Calculate reflect vector
	half3 R = reflect(eyeVec, Normal);
	
	// phong lighting
	half diffuseStrength = saturate(dot(lightVec, Normal));

  // modulate texture color with diffuse lighting
  colorAlpha.xyz *= (diffuseStrength * light_col_amb.rgb);

	// calculate specular	
	half specularStrength = pow(saturate(dot(R, lightVec)), WATER_SPECULAR_POWER);

  // add specular color
	colorAlpha.xyz += light_col_amb.rgb * specularStrength * 0.5;
	
	specularStrength *= colorAlpha.a;
	diffuseStrength *= colorAlpha.a;
	
	// add alpha values from diffuse and specular lighting
	colorAlpha.a = colorAlpha.a * 0.25 + (specularStrength + diffuseStrength) * 0.60;

  PSO.col0 = colorAlpha;
	return PSO;
}
#endif

//------------------ DUMMY PIXEL SHADER FOR SM1_1 ----------------------//

#ifdef PS_DUMMY
fragout mainPS( pixdata In )
{
  fragout PSO;
  PSO.col0 = float4( 0.1, 0.1, 0.4, 0.7 );
  return PSO;
}
#endif


#endif // end of old water shader code