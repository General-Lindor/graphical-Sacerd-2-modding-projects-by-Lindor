// standard nova in ground


//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:LAYER_BIT2

#include "extractvalues.shader"

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

/////////////////////////////////////
// Nova setup
/////////////////////////////////////
#ifdef NOVA
  #define VS_GENERAL
  #define VS_OUT_NOVA     // VS output struct
  #if defined(SM1_1)
    #define PS_MASK       // PS == ps_1_4
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
  #define PS_MASK
  #define PS_OUT_COL1
#endif

/////////////////////////////////////
// Refraction setup
/////////////////////////////////////
#ifdef REFRACTION
  #define VS_GENERAL
  #define VS_OUT_REFRACTION
  #if defined(SM1_1)
    #define PS_MASK       //    ps_1_4
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
  };
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
pixdata mainVS( appdata I,
                uniform float4x4 worldViewProjMatrix,
                uniform float4 vtx_data_array[2] )
{
	pixdata O;

  // usefull names
  float inner_radius = vtx_data_array[0].x;
  float delta_radius = vtx_data_array[0].y;

#if !defined(MASK)
  float intensity = vtx_data_array[0].z;
#endif

  float z_offset = vtx_data_array[0].w;

  // position (put at level z to avoid z-fighting!)
	float4 pos4 = float4(I.position.xy, z_offset, 1.0);

  // make circular (+ 1.0 because circle is calc'ed from geom and we need more "space on poly"!)
  pos4.xy += inner_radius * I.normal.xy + 2.0 * I.position.z * delta_radius * I.normal.xy;

	// transform
	O.hposition = mul(pos4, worldViewProjMatrix);

#ifdef VS_OUT_screenCoord
	// vertex-position in screen space
  O.screenCoord = calcScreenToTexCoord(O.hposition);
#endif

#ifdef VS_OUT_circ_pos
  // pass pos
  O.circ_pos = float4(pos4.xy, inner_radius, delta_radius);
#endif

#ifdef VS_OUT_texcoord0
  // texcoords
  O.texcoord0 = float4(I.texcoord.xy, intensity, 0.f);
#endif

	return O;
}
#endif

#ifdef PS_MASK
fragout mainPS(pixdata I)
{
	fragout O;

  // out
	O.col = float4(1.0, 1.0, 1.0, 1.0);

	return O;
} 
#endif


#ifdef PS_GENERAL
#ifdef NOVA
fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler3D   textureVolume,
  uniform float4      param)
#endif
#ifdef REFRACTION
fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform sampler2D   texture3,
  uniform sampler3D   textureVolume,
  uniform float4      param)
#endif
{
	fragout O;

  // usefull names
  float intensity = I.texcoord0.z;
  float inner_radius = I.circ_pos.z;
  float delta_radius = I.circ_pos.w;
  float time = param.x;

  // one texcoord comes from pos
  s2half radial_tc = saturate((length(I.circ_pos.xy) - inner_radius) / delta_radius);

#ifdef NOVA
  // calc v-stretch
  float umfang = 1.0 * delta_radius;
#endif
#ifdef REFRACTION
  // calc v-stretch
  float umfang = 0.5 * delta_radius;
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
	float2 scr_offset = (I.screenCoord.z / I.screenCoord.w) * target_data.zw * normalize(I.circ_pos.xy) * tex0.x * intensity * cau.x;
	// screenpos of this pixel
	float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;
	// offset due to refraction and distance!
	float2 offs_scr_pos = scr_pos - 20.0 * scr_offset;
	
	// transparency <-> opaque mask
	s2half4 t_mask = tex2D(texture3, offs_scr_pos);
	
	// offset'ed background
	s2half4 offs_bgr = tex2D(texture2, offs_scr_pos);
	// non-offset'ed background
	s2half4 nonoffs_bgr = tex2D(texture2, scr_pos);
	
	// lerp with mask
	s2half4 bgr = lerp(nonoffs_bgr, offs_bgr, t_mask.x);


  // out
	O.col[0] = float4(bgr.xyz, 1.0);
	O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
#endif

	return O;
} 
#endif