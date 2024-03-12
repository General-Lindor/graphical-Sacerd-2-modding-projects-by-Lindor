// refraction nova in ground
#include "extractvalues.shader"

//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:LAYER_BIT2
//#OptDef:LAYER_BIT3

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
};


#ifdef LAYER_BIT0
  #define NOVA
#endif
#ifdef LAYER_BIT1
  #define MASK
#endif
#ifdef LAYER_BIT2
  #define REFRACTION
#endif
#ifdef LAYER_BIT3
  #define PROJECT_IN_OBJECT_SPACE
#endif

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
// Nova setup
/////////////////////////////////////
#ifdef NOVA
  #define VS_GENERAL
  #define VS_OUT_NOVA     // VS output struct
  #if defined(SM1_1)
    #define PS_DUMMY      // PS == ps_1_4
    #define PS_OUT_COL1   // PS output struct
  #else
    #define PS_GENERAL    // PS >= ps_2_0
    #define PS_OUT_COL2   // PS output struct
  #endif
#endif

/////////////////////////////////////
// Mask setup
/////////////////////////////////////
#ifdef MASK
  #define VS_GENERAL
  #define VS_OUT_MASK
  #define PS_OUT_COL1   // >= ps_2_0
  #if defined(SM1_1)
    #define PS_DUMMY    //    ps_1_4
  #else
    #define PS_GENERAL
  #endif
#endif

/////////////////////////////////////
// Refraction setup
/////////////////////////////////////
#ifdef REFRACTION
  #define VS_GENERAL
  #define VS_OUT_REFRACTION
  #if defined(SM1_1)
    #define PS_DUMMY      //    ps_1_4
    #define PS_OUT_COL1
  #else
    #define PS_GENERAL
    #define PS_OUT_COL2   // >= ps_2_0
  #endif
#endif

/////////////////////////////////////
// Vertex Shader Setups
/////////////////////////////////////
#ifdef VS_OUT_NOVA
  struct pixdata
  {
	  float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float4 circ_pos    : TEXCOORD1;
  };
  #define VS_OUT_texcoord0
  #define VS_OUT_circ_pos
#endif

#ifdef VS_OUT_MASK
  struct pixdata 
  {
	  float4 hposition   : POSITION;
    float  v           : TEXCOORD;
  };
  #define VS_OUT_v

#endif

#ifdef VS_OUT_REFRACTION
  struct pixdata
  {
	  float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float4 circ_pos    : TEXCOORD1;
	  float4 screenCoord : TEXCOORD2;
  };
  #define VS_OUT_texcoord0
  #define VS_OUT_circ_pos
  #define VS_OUT_screenCoord
#endif

/////////////////////////////////////
// Pixel Shader Setups
/////////////////////////////////////
#ifdef PS_OUT_COL1
  struct fragout
  {
	  float4 col       : COLOR;
  };
  #define PS_OUT_col
#endif

#ifdef PS_OUT_COL2
  struct fragout
  {
	  float4 col[2]    : COLOR;
  };
  #define PS_OUT_col[2]
#endif



//////////////////////////////////////////////////
// VERTEX SHADERS
//////////////////////////////////////////////////
#ifdef VS_GENERAL
#ifdef PROJECT_IN_OBJECT_SPACE
pixdata mainVS(		small_appdata sI,
				uniform float4    weather_pos,
#else
pixdata mainVS(         appdata   I,
#endif
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldMatrix,
    uniform float4   vtx_data_array[4]
#ifdef XENON_IMPL
   ,uniform float4   viewport_data
#endif     
    )
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
  float  depth        = vtx_data_array[1].x;            // thickness of the ring
  float  glob_z       = vtx_data_array[1].y;            // general effect z offset
  float4 e_center     = vtx_data_array[3];              // center of effect in object coordinates
  // vertex position + z offset along normal
#ifdef PROJECT_IN_OBJECT_SPACE
	float4 pos4         = float4(I.position + (bias + glob_z) * I.normal, 1.0);
#else
  float4 pos4         = float4( I.position, 1.0 );
         pos4         = mul( pos4, worldMatrix );
  float3 normal       = mul( I.normal, worldMatrix );
         pos4.xyz     = pos4.xyz + (bias + glob_z) * normal;
#endif

  // let the intensity fade with the height distance around the effect
  intensity   *= saturate( 1.0 - ( abs( pos4.z - e_center.z ) - 50.0 ) / 50.0 );
	// transform vertices into clip space
	O.hposition = mul(pos4, worldViewProjMatrix);

#ifdef VS_OUT_v
  // pass distance to effect center
  O.v = ( length( pos4.xy - e_center.xy ) - size ) / ( 2.0 * depth );
  // use this for rings starting out from the center
  //O.v = ( length( pos4.xy - e_center.xy ) - (size-depth) ) / depth;
#endif

#ifdef VS_OUT_circ_pos
  // pass pos
  float2 tc = pos4.xy - e_center.xy;
  O.circ_pos = float4( tc, size, depth );
#endif

#ifdef VS_OUT_texcoord0
  float u, v;
  u = acos( normalize( tc ).y );
  v = (length( tc ) - size) / ( 1.5 * depth );
  // use this for rings starting out from the center
  //v = (length( tc ) - (size-depth)) / depth;
  // texcoords
  O.texcoord0 = float4( u, v, intensity, 0.f);
#endif

#ifdef VS_OUT_screenCoord
  O.screenCoord = O.hposition;
// 	#ifndef PS3_IMPL //TB:Not sure what this is supposed to do...	
// 	  // vertex-position in screen space
// 	  O.screenCoord.x = O.hposition.w + O.hposition.x;
// 	  O.screenCoord.y = O.hposition.w - O.hposition.y;
// 	  O.screenCoord.z = O.hposition.z;
// 	  O.screenCoord.w = 2.0 * O.hposition.w;
// 	  O.screenCoord.xy *= target_data.xy;
//     #ifdef CONSOLE_IMPL
//       O.screenCoord.xy /= O.screenCoord.w;
//       O.screenCoord.xy  = (O.screenCoord.xy - viewport_data.xy) * viewport_data.zw;
//       O.screenCoord.xy *= O.screenCoord.w;
//     #endif
//   #else
// 	  O.screenCoord=float4(O.hposition.x,-O.hposition.y,O.hposition.z,1);
// 	  O.screenCoord.xyz/=2*O.hposition.w;
// 	  O.screenCoord.xyz+=float3(0.5f,0.5f,0.5f);
// 	  O.screenCoord.xyzw*=O.hposition.wwww;
//   #endif
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
#ifdef REFRACTION
fragout mainPS( pixdata I,
                float2    vPos           : VPOS,
                uniform sampler2D   texture0,
                uniform sampler2D   texture1,
                uniform sampler2D   texture2,
                uniform sampler2D   texture3,
                uniform sampler3D   textureVolume,
                uniform float4      param)
#else
fragout mainPS( pixdata I,
                uniform sampler2D   texture0,
                uniform sampler2D   texture1,
                uniform sampler3D   textureVolume,
                uniform float4      param )
#endif
{
  fragout O;

#ifdef MASK
   if( I.v >= 0.0 && I.v <= 1.0 )
    O.col = float4( 1.0, 1.0, 1.0, 1.0 );
  else
    O.col = float4( 0.0, 0.0, 0.0, 0.0 );
#else
  // useful names
  float intensity = I.texcoord0.z;
  float inner_radius = I.circ_pos.z;
  float delta_radius = I.circ_pos.w;
  float time = param.x;

  // one texcoord comes from pos
  s2half radial_tc = saturate((length(I.circ_pos.xy) - inner_radius) / delta_radius);
  // use this for rings starting out from the center
  //s2half radial_tc = saturate((length(I.circ_pos.xy) - (inner_radius-delta_radius)) / delta_radius);

#ifdef NOVA
  // calc v-stretch - increase the factor to create tighter caustics
  float umfang = 1.0;
#endif

#ifdef REFRACTION
    // calc v-stretch
  float umfang = 0.5 * delta_radius;
  //float umfang = 1.0;
#endif

	// gradient
	s2half4 tex0 = tex2D(texture0, float2(radial_tc, umfang * I.texcoord0.x));
  // caust
  s2half4 cau = tex3D(textureVolume, float3(radial_tc, umfang * I.texcoord0.x, time));

#ifdef NOVA
  // caustic strength is in alpha channel
  s2half cauStrength = tex0.a;
  // calc color
  s2half3 col = lerp(tex0.xyz, tex0.xyz * cau.xyz, cauStrength);

  // out
	O.col[0] = float4(intensity * col, 1.0);
	O.col[1] = float4(0.2 * intensity * col, 1.0);
#endif

#ifdef REFRACTION 
	// offset
// 	float2 scr_offset = (I.screenCoord.z / I.screenCoord.w) * target_data.zw * normalize(I.circ_pos.xy) * tex0.x * intensity * cau.x;
// 	// screenpos of this pixel
// 	float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;
// 	// offset due to refraction and distance!
// 	float2 offs_scr_pos = scr_pos - 20.0 * scr_offset;

  float surfaceZ = I.screenCoord.w;

  float4 ofs_scr_pos = RefractionOffsets(false, vPos.xy, 20, normalize(I.circ_pos.xy) * tex0.x * intensity * cau.x);

  float depth = DEPTH_SAMPLE(texture3, ofs_scr_pos.zw).x;

  // offset'ed background
  s2half4 bgr = tex2D(texture2, (depth<surfaceZ) ? ofs_scr_pos.xy : ofs_scr_pos.zw );

// 	// transparency <-> opaque mask
// 	#ifdef CONSOLE_IMPL
//     float depth = DEPTH_SAMPLE(texture3, offs_scr_pos).x;
//     s2half4 t_mask = (depth<surfaceZ) ? 0 : 1;      
//   #else	    
// 	  s2half4 t_mask = tex2D(texture3, offs_scr_pos);
//   #endif
// 	
// 	// offset'ed background
// 	s2half4 offs_bgr = tex2D(texture2, offs_scr_pos);
// 	// non-offset'ed background
// 	s2half4 nonoffs_bgr = tex2D(texture2, scr_pos);
//	
//	// lerp with mask
//	s2half4 bgr = lerp(nonoffs_bgr, offs_bgr, t_mask.x);

  // out
	O.col[0] = float4(bgr.xyz, 1.0);
//	O.col[0] = float4(depth, surfaceZ, t_mask.x, 1.0);
//	O.col[0] = float4(1.0, 1.0, 0.0, 1.0);
	O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
#endif
#endif

  return O;
} 
#endif