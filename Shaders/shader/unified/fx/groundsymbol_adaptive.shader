// Groundsymbol Adaptive Shader
// This shader gets called by groundsymbol.cpp
// Input geometry are terrain patches and objects
// covered by the effect.
// The shader covers types
// _2D_TEXTURE_COLORED
// _2D_PATTERN_3
// _2D_PATTERN_5
// _2D_PATTERN_^10


//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:LAYER_BIT2
//#OptDef:LAYER_BIT3
//#OptDef:LAYER_BIT4
//#OptDef:VS_IN_INSTANCED_MINIVERTEX

#ifdef LAYER_BIT0
  #define PATTERN1
#endif
#ifdef LAYER_BIT1
  #define PATTERN3
#endif
#ifdef LAYER_BIT2
  #define PATTERN5
#endif
#ifdef LAYER_BIT3
  #define PROJECT_IN_OBJECT_SPACE
#endif
#ifdef LAYER_BIT4
  #define PATTERN9
#endif
#ifdef VS_IN_INSTANCED_MINIVERTEX
  #define INSTANCING
#endif


// XVERTEX data + zoffset from Stream1
struct appdata 
{
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float2 texcoord   : TEXCOORD0;
	float2 data       : TEXCOORD1;
#ifdef INSTANCING
  float  zoffset    : TEXCOORD2;
#else
  float  pix_height : TEXCOORD2;
#endif
};

// Terrain?
#ifdef PROJECT_IN_OBJECT_SPACE
struct small_appdata
{
	float	height:position;
	float4	uvn:color;
#ifdef INSTANCING
  float  zoffset    : TEXCOORD0;
#endif
};
#endif


/////////////////////////////////////
// Pattern 1 setup
/////////////////////////////////////
#ifdef PATTERN1
  #define VS_GENERAL
  #define VS_OUT_P1       // VS output struct
  #if defined(SM1_1)
    #define PS_DUMMY      // PS == ps_1_4
    #define PS_OUT_COL1   // PS output struct
  #else
    #define PS_GENERAL    // PS >= ps_2_0
    #define PS_OUT_COL2   // PS output struct
  #endif
#endif

/////////////////////////////////////
// Pattern 3 setup
/////////////////////////////////////
#ifdef PATTERN3
  #define VS_GENERAL
  #define VS_OUT_P3       // VS output struct
  #if defined(SM1_1)
    #define PS_DUMMY      // PS == ps_1_4
    #define PS_OUT_COL1   // PS output struct
  #else
    #define PS_GENERAL    // PS >= ps_2_0
    #define PS_OUT_COL2   // PS output struct
  #endif
#endif

/////////////////////////////////////
// Pattern 5 setup
/////////////////////////////////////
#ifdef PATTERN5
  #define VS_GENERAL
  #define VS_OUT_P5       // VS output struct
  #if defined(SM1_1)
    #define PS_DUMMY      // PS == ps_1_4
    #define PS_OUT_COL1   // PS output struct
  #else
    #define PS_GENERAL    // PS >= ps_2_0
    #define PS_OUT_COL2   // PS output struct
  #endif
#endif

/////////////////////////////////////
// Pattern 9 setup
/////////////////////////////////////
#ifdef PATTERN9
  #define VS_GENERAL
  #define VS_OUT_P9       // VS output struct
  #if defined(SM1_1)
    #define PS_DUMMY      // PS == ps_1_4
    #define PS_OUT_COL1   // PS output struct
  #else
    #define PS_GENERAL    // PS >= ps_2_0
    #define PS_OUT_COL2   // PS output struct
  #endif
#endif


/////////////////////////////////////
// Vertex Shader Setups
/////////////////////////////////////
#ifdef VS_OUT_P1
  struct pixdata
  {
	  float4 hposition        : POSITION; 
    float  data             : TEXCOORD0;
    float4 tcs[1]           : TEXCOORD1;  
  };
  #define VS_OUT_data
  #define VS_OUT_tcs0
#endif

#ifdef VS_OUT_P3
  struct pixdata
  {
	  float4 hposition        : POSITION; 
    float  data             : TEXCOORD0;
    float4 tcs[3]           : TEXCOORD1;  
  };
  #define VS_OUT_data
  #define VS_OUT_tcs0
  #define VS_OUT_tcs1
  #define VS_OUT_tcs2
#endif

#ifdef VS_OUT_P5
  struct pixdata
  {
	  float4 hposition        : POSITION; 
    float  data             : TEXCOORD0;
    float4 tcs[5]           : TEXCOORD1;  
  };
  #define VS_OUT_data
  #define VS_OUT_tcs0
  #define VS_OUT_tcs1
  #define VS_OUT_tcs2
  #define VS_OUT_tcs3
  #define VS_OUT_tcs4
#endif

#ifdef VS_OUT_P9
  struct pixdata
  {
	  float4 hposition        : POSITION; 
    float  data             : TEXCOORD0;
    float4 tcs[9]           : TEXCOORD1;  
  };
  #define VS_OUT_data
  #define VS_OUT_tcs0
  #define VS_OUT_tcs1
  #define VS_OUT_tcs2
  #define VS_OUT_tcs3
  #define VS_OUT_tcs4
  #define VS_OUT_tcs5
  #define VS_OUT_tcs6
  #define VS_OUT_tcs7
  #define VS_OUT_tcs8
#endif


/////////////////////////////////////
// Pixel Shader Setups
/////////////////////////////////////
#ifdef PS_OUT_COL1
  struct fragout
  {
	  float4 col       : COLOR;
  };
#endif

#ifdef PS_OUT_COL2
  struct fragout
  {
	  float4 col[2]    : COLOR;
  };
#endif



//////////////////////////////////////////////////
// VERTEX SHADER
//////////////////////////////////////////////////
#ifdef VS_GENERAL
#ifdef PROJECT_IN_OBJECT_SPACE
pixdata mainVS(		small_appdata sI,
				uniform float4    weather_pos,
#else
pixdata mainVS(         appdata   I,
#endif
                uniform float4x4  worldViewProjMatrix,
                uniform float4x4  worldMatrix,
                uniform float4    vtx_data_array[4]    )
{
#ifdef PROJECT_IN_OBJECT_SPACE
	appdata I;
	// Do all the decompression here, compiler will optimize and remove unused calculations

	// Please do not change this code, as it has been carefully reordered to trick the optimizer
	// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
	float4 scaler = sI.uvn.xyxy * float4(weather_pos.zw * 42.5, 42.5, 42.5);	// Rescale from 0/255..6/255 to 0..1
	I.position = float3(scaler.xy + weather_pos.xy, sI.height);
	I.data.xy = I.texcoord.xy = scaler.zw;	
	// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	I.normal.xy = sI.uvn.zw*2-1;
	I.normal.z = sqrt(1-dot(I.normal.xy,I.normal.xy));
	
	I.binormal = normalize(cross(float3(I.normal.z, 0, -I.normal.x), I.normal));
	I.tangent  = normalize(cross(I.normal, float3(0, I.normal.z, -I.normal.y)));

#ifdef INSTANCING
	I.zoffset = sI.zoffset;
#endif

#endif

	pixdata O;

  // Read parameters
  float  rot          = vtx_data_array[0].x;            // effect rotation
  float  intensity    = vtx_data_array[0].y;            // color intensity
  float  size         = vtx_data_array[0].z;            // size of the symbol
  float  bias         = vtx_data_array[0].w * 0.001;    // z offset depending on character distance to camera
  float  depth        = vtx_data_array[1].x;            // distance of each pattern to the effect center
  float  glob_z       = vtx_data_array[1].y;            // general effect z offset
  float  interp_fac   = vtx_data_array[1].z;            // [0;1] depends on camera distance to the effect
  float  fixed_offset = vtx_data_array[1].w;            // overall height of the entire effect
  float2 color_offset = vtx_data_array[2].xy;           // used for coloring the height
  float  anz_layer    = vtx_data_array[2].z;            // no of layers the effect shall use for instancing
  float  layer_dist   = vtx_data_array[2].w;            // distance between each instanced layer
  float4 e_center     = vtx_data_array[3];              // center of effect in object coordinates
  // vertex position + z offset along normal
#ifdef PROJECT_IN_OBJECT_SPACE // used by patches
  float3 nm = { 0,1,0 };
	float4 pos4         = float4(I.position + (bias + glob_z) * I.normal, 1.0);
#else // used by objects
  float4 pos4         = float4( I.position, 1.0 );
         pos4         = mul( pos4, worldMatrix );
  float3 normal       = normalize( mul( I.normal, worldMatrix ) );
         pos4.xyz     = pos4.xyz + (bias + glob_z) * normal;
#endif
  float zoffset       = glob_z;
#ifdef INSTANCING
  zoffset            += I.zoffset * layer_dist;
  float instance      = I.zoffset / anz_layer;
  // intensity for the pixel shader
  // we only want areas within a certain height range around the symbol to show the effect
  intensity          *= saturate( 1.0 - ( abs( pos4.z - e_center.z ) - 50.0 ) / 50.0 );
  O.data              = intensity * saturate(3.0 * (1.0 - instance) / anz_layer + 0.35 * pow(1.0 - instance, 30.0));
#else
  // we only want areas within a certain height range around the symbol to show the effect
  intensity          *= saturate( 1.0 - ( pos4.z - e_center.z - 15 ) / 15 );
  // if we project on an object, only project on objects above the effect height, not below it
  O.data              = (pos4.z + 35.0) >= e_center.z ? intensity : 0.0;
#endif

	// transform vertices into clip space
  pos4.z             += zoffset;
	O.hposition         = mul(pos4, worldViewProjMatrix);
  
  float anzPatterns    = 1.0;
#ifdef PATTERN3
  anzPatterns         = 3.0;
#endif
#ifdef PATTERN5
  anzPatterns         = 5.0;
#endif
#ifdef PATTERN9
  anzPatterns         = 9.0;
#endif

#ifdef VS_OUT_tcs0
  float  angle_offset = radians( 360.0 / anzPatterns );
  float  fac          = 1.0 / (size * 2.0);
  float2 tc           = pos4.xy - e_center.xy;
  float2 ttc          = tc;
  float2 sin_cos;
  sincos( rot, sin_cos.x, sin_cos.y );
  float2x2 rotmat     = { sin_cos.y, -sin_cos.x, 
                          sin_cos.x,  sin_cos.y };
  // rotate and translate
  ttc    = mul( ttc, rotmat );
  ttc.x += depth;
  // offset to valid range [0;1]
  ttc = fac * ttc + float2( 0.5, 0.5 );
  // write to output register
  O.tcs[0].xy = ttc;
  O.tcs[0].zw = fixed_offset * ttc - color_offset;
#endif

#ifdef VS_OUT_tcs1
  // 2nd pattern
  sincos( rot + angle_offset, sin_cos.x, sin_cos.y );
  rotmat = float2x2( sin_cos.y, -sin_cos.x, 
                     sin_cos.x,  sin_cos.y );
  // rotate and translate
  ttc    = tc;
  ttc    = mul( ttc, rotmat );
  ttc.x += depth;
  // offset to valid range [0;1]
  ttc = fac * ttc + float2( 0.5, 0.5 );
  // write to output register
  O.tcs[1].xy = ttc;
  O.tcs[1].zw = fixed_offset * ttc - color_offset;
#endif

#ifdef VS_OUT_tcs2
  // 3rd pattern
  sincos( rot + (angle_offset * 2.0), sin_cos.x, sin_cos.y );
  rotmat = float2x2( sin_cos.y, -sin_cos.x, 
                     sin_cos.x,  sin_cos.y );
  // rotate and translate
  ttc    = tc;
  ttc    = mul( ttc, rotmat );
  ttc.x += depth;
  // offset to valid range [0;1]
  ttc = fac * ttc + float2( 0.5, 0.5 );
  // write to output register
  O.tcs[2].xy = ttc;
  O.tcs[2].zw = fixed_offset * ttc - color_offset;
#endif

#ifdef VS_OUT_tcs3
  // 4th pattern
  sincos( rot + (angle_offset * 3.0), sin_cos.x, sin_cos.y );
  rotmat = float2x2( sin_cos.y, -sin_cos.x, 
                     sin_cos.x,  sin_cos.y );
  // rotate and translate
  ttc    = tc;
  ttc    = mul( ttc, rotmat );
  ttc.x += depth;
  // offset to valid range [0;1]
  ttc = fac * ttc + float2( 0.5, 0.5 );
  // write to output register
  O.tcs[3].xy = ttc;
  O.tcs[3].zw = fixed_offset * ttc - color_offset;
#endif

#ifdef VS_OUT_tcs4
  // 5th pattern
  sincos( rot + (angle_offset * 4.0), sin_cos.x, sin_cos.y );
  rotmat = float2x2( sin_cos.y, -sin_cos.x, 
                     sin_cos.x,  sin_cos.y );
  // rotate and translate
  ttc    = tc;
  ttc    = mul( ttc, rotmat );
  ttc.x += depth;
  // offset to valid range [0;1]
  ttc = fac * ttc + float2( 0.5, 0.5 );
  // write to output register
  O.tcs[4].xy = ttc;
  O.tcs[4].zw = fixed_offset * ttc - color_offset;
#endif
  
#ifdef VS_OUT_tcs5
  // 5th pattern
  sincos( rot + (angle_offset * 5.0), sin_cos.x, sin_cos.y );
  rotmat = float2x2( sin_cos.y, -sin_cos.x, 
                     sin_cos.x,  sin_cos.y );
  // rotate and translate
  ttc    = tc;
  ttc    = mul( ttc, rotmat );
  ttc.x += depth;
  // offset to valid range [0;1]
  ttc = fac * ttc + float2( 0.5, 0.5 );
  // write to output register
  O.tcs[5].xy = ttc;
  O.tcs[5].zw = fixed_offset * ttc - color_offset;
#endif
  
#ifdef VS_OUT_tcs6
  // 5th pattern
  sincos( rot + (angle_offset * 6.0), sin_cos.x, sin_cos.y );
  rotmat = float2x2( sin_cos.y, -sin_cos.x, 
                     sin_cos.x,  sin_cos.y );
  // rotate and translate
  ttc    = tc;
  ttc    = mul( ttc, rotmat );
  ttc.x += depth;
  // offset to valid range [0;1]
  ttc = fac * ttc + float2( 0.5, 0.5 );
  // write to output register
  O.tcs[6].xy = ttc;
  O.tcs[6].zw = fixed_offset * ttc - color_offset;
#endif
  
#ifdef VS_OUT_tcs7
  // 5th pattern
  sincos( rot + (angle_offset * 7.0), sin_cos.x, sin_cos.y );
  rotmat = float2x2( sin_cos.y, -sin_cos.x, 
                     sin_cos.x,  sin_cos.y );
  // rotate and translate
  ttc    = tc;
  ttc    = mul( ttc, rotmat );
  ttc.x += depth;
  // offset to valid range [0;1]
  ttc = fac * ttc + float2( 0.5, 0.5 );
  // write to output register
  O.tcs[7].xy = ttc;
  O.tcs[7].zw = fixed_offset * ttc - color_offset;
#endif
  
#ifdef VS_OUT_tcs8
  // 5th pattern
  sincos( rot + (angle_offset * 8.0), sin_cos.x, sin_cos.y );
  rotmat = float2x2( sin_cos.y, -sin_cos.x, 
                     sin_cos.x,  sin_cos.y );
  // rotate and translate
  ttc    = tc;
  ttc    = mul( ttc, rotmat );
  ttc.x += depth;
  // offset to valid range [0;1]
  ttc = fac * ttc + float2( 0.5, 0.5 );
  // write to output register
  O.tcs[8].xy = ttc;
  O.tcs[8].zw = fixed_offset * ttc - color_offset;
#endif
  
  return O;
}
#endif


//////////////////////////////////////////////////
// PIXEL SHADERS
//////////////////////////////////////////////////
#ifdef PS_DUMMY
fragout mainPS( pixdata I )
{
  fragout O;
  O.col = float4( 1.0, 1.0, 1.0, 1.0 );
  return O;
}
#endif

#ifdef PS_GENERAL
float4 getColor( float4 tcs, uniform sampler2D t0, uniform sampler2D t1 )
{
  return float4( tex2D( t0, tcs.xy ) * tex2D( t1, tcs.zw ) );
}


fragout mainPS( pixdata I,
                uniform sampler2D texture0,
                uniform sampler2D texture1 )
{
  fragout O;

  float4 tcol = { 0.0, 0.0, 0.0, 0.0 };

#ifdef VS_OUT_tcs0
  tcol += getColor( I.tcs[0], texture0, texture1 );
#endif

#ifdef VS_OUT_tcs1
  tcol += getColor( I.tcs[1], texture0, texture1 );
#endif

#ifdef VS_OUT_tcs2
  tcol += getColor( I.tcs[2], texture0, texture1 );
#endif

#ifdef VS_OUT_tcs3
  tcol += getColor( I.tcs[3], texture0, texture1 );
#endif

#ifdef VS_OUT_tcs4
  tcol += getColor( I.tcs[4], texture0, texture1 );
#endif

#ifdef VS_OUT_tcs5
  tcol += getColor( I.tcs[5], texture0, texture1 );
#endif

#ifdef VS_OUT_tcs6
  tcol += getColor( I.tcs[6], texture0, texture1 );
#endif

#ifdef VS_OUT_tcs7
  tcol += getColor( I.tcs[7], texture0, texture1 );
#endif

#ifdef VS_OUT_tcs8
  tcol += getColor( I.tcs[8], texture0, texture1 );
#endif

  // multiply with the intensity
  tcol *= I.data;
  // out
  O.col[0] = tcol;
  //O.col[1] = tcol;
  O.col[1] = float4( 0,0,0,0 );

  return O;
} 
#endif