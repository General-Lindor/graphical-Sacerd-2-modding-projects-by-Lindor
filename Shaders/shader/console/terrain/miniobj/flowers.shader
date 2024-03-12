//#OptDef:SPASS_G
//#OptDef:FLOWER_WOBBLE
//#OptDef:VS_IN_MINIVERTEX
//#OptDef:VS_IN_INSTANCED_MINIVERTEX

#ifdef SPASS_ZONLY
	#define VS_OUT_G_20
#endif
/////////////////////////////////////
// SPASS_G setup
/////////////////////////////////////
#ifdef SPASS_G
  #define VS_OUT_G_20
  #define PS_G_20
#endif

/////////////////////////////////////
// SPASS_DECALS setup
/////////////////////////////////////
#ifdef SPASS_DECALS
  #define VS_OUT_DECALS
  #define PS_DECALS_20
#endif

/////////////////////////////////////
// Vertex Shader Setups
/////////////////////////////////////
#ifdef VS_OUT_G_20
  struct pixdata {
	  half4 hposition  : POSITION;
	  half4 data0      : TEXCOORD0;
  };
  #define VS_OUT_hposition
  #define VS_OUT_data0
#endif 

#ifdef VS_OUT_DECALS
  struct pixdata {
	  half4 hposition  : POSITION;
	  half4 texcoord   : TEXCOORD0;
	  half4 lightDir   : TEXCOORD1;
  };
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_lightDir
#endif 


#include "extractvalues.shader"
#include "shadow.shader"

#include "wobble.shader"


DEFINE_VERTEX_DATA

// Set texture sampler into gradient texture
// and the instance count into param.y

#ifndef PS3_IMPL

// is used in EXTRACT_VERTEX_VALUES, defined in extractvalues.shader

SInstanceData TFetchInstanceData(sampler1D bonePaletteTexture, half instanceIndex, half instanceCount)	// XENON
{
    half TexCoord = instanceIndex / instanceCount;
    half4 Result1;
    half4 Result2;
    half4 Result3;
    asm
    {
        tfetch1D Result1, TexCoord, bonePaletteTexture, UseComputedLOD = false, OffsetX = 0.5	// XENON
        tfetch1D Result2, TexCoord, bonePaletteTexture, UseComputedLOD = false, OffsetX = 1.5	// XENON
        tfetch1D Result3, TexCoord, bonePaletteTexture, UseComputedLOD = false, OffsetX = 2.5	// XENON
    };
    
    SInstanceData Result;
    Result.texcoord1 = Result1.xyzw;	// XENON
    Result.texcoord2 = Result2.xyzw;	// XENON
    Result.texcoord3 = Result3.xyzw;	// XENON
    return Result;
}	// XENON

#define POINT_SAMPLER sampler_state { MipFilter = NONE; MinFilter = POINT; MagFilter = POINT; AddressU = CLAMP; AddressV = CLAMP; }
sampler1D   instanceData : register(s0) = POINT_SAMPLER;

#endif

pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldMatrix,
  	uniform float4x4 invWorldMatrix,
    uniform float4x4 lightMatrix,
    uniform float4   light_pos,
    uniform float4   param,
    uniform float4   camera_pos,
    uniform float4   weather_pos, // HACK for hero position
    uniform lightData globLightData,
    uniform float4   vtx_data_array[FLOWERS_WOBBLE_CENTER_MAX],
    uniform float4   vtx_data2_array[4],
    uniform float4   zfrustum_data,
    uniform float4   fog_data )
{
	pixdata O;

	EXTRACT_VERTEX_VALUES

#ifndef FLOWER_WOBBLE
	// apply wind and calc extreme (=1.0) position
	vertex_pos.xyz += wind_weight * vtx_data2_array[wind_group];
#else
	// apply "wind"
	vertex_pos.xyz += wind_weight* vtx_data2_array[wind_group];
	// get wobble matrix
	float3x3 rotMat = calcWobble(vtx_data_array, flower_center.xy, vertex_pos.z);
	// bend it
	vertex_pos.xyz = mul(vertex_pos.xyz, rotMat);
#endif
	// translate to final position
  vertex_pos.xyz += flower_center;
  
  float3 worldVertPos = mul(vertex_pos, worldMatrix);
  #ifdef VS_OUT_G_20
	  O.data0.zw = distance(weather_pos, worldVertPos);
	#else
	  O.intensity = distance(weather_pos, worldVertPos);
	#endif
  
  float4 _hposition = mul(vertex_pos, worldViewProjMatrix);
	#ifdef VS_OUT_hposition
	  // vertex pos
	  O.hposition = _hposition;
	#endif

  // put (normalized!) distance
  float distance = (_hposition.w - zfrustum_data.x) * zfrustum_data.z;

	// convert light direction vector from worldspace to objectspace
	float4 l_obj = mul(light_pos, invWorldMatrix);
	// convert light pos from worldspace into objectspace
	float4 l_pos_obj = mul(light_pos, invWorldMatrix);
	// convert light pos from worldspace into objectspace
	half4 l_dir_obj = mul(light_pos, invWorldMatrix);
	
	#ifdef VS_OUT_data0
    O.data0.xy = uv0.xy;
    O.data0.w = 0.75f + saturate( 0.25f * (dot(l_obj.xyz, ground_normal.xyz) / l_obj.y) );
	#endif

 	#ifdef VS_OUT_texcoord
	  // pass transformed & untransformed texture coords
	  O.texcoord = uv0.xyyy;
 	#endif

	// build vector from vertex pos to light pos
	half3 pix_to_li = l_pos_obj.xyz - vertex_pos.xyz;
	half3 pix_to_li_nrm = normalize(pix_to_li);

 	#ifdef VS_OUT_lightDir
	  // store light vector & dot
	  O.lightDir = half4(l_dir_obj.xyz, dot(ground_normal.xyz, l_dir_obj.xyz) + height_scale);
 	#endif

	return O;
}

#ifdef SPASS_ZONLY
  #include "normalmap.shader"
 
  s2half4 mainPS(pixdata I
     ,uniform sampler2D texture0
     ,uniform half4     param
     ,uniform float4    materialID ) : COLOR0
  {  
  #ifdef PS3_IMPL
      s2half4 tex0 = h4tex2D(texture0, I.data0.xy);
  #else
	  s2half4 tex0 = tex2D(texture0, I.data0.xy);
  #endif
    
    s2half vis = saturate( 1.f-((I.data0.z-param.x)/param.y));
    return float4(0,0,0, tex0.w*vis );
  } 
#endif

#ifdef PS_G_20
  #include "normalmap.shader"
 
  s2half4 mainPS(pixdata I
     ,uniform sampler2D texture0
     ,uniform half4     param
     ,uniform float4    materialID ) : COLOR0
  {  
  #ifdef PS3_IMPL
      s2half4 tex0 = h4tex2D(texture0, I.data0.xy);
  #else
	  s2half4 tex0 = tex2D(texture0, I.data0.xy);
  #endif
    
  s2half vis = saturate( 1.f-((I.data0.z-param.x)/param.y));
  clip(tex0.w*vis-0.5);
    
#ifdef XENON_IMPL
    s2half texCoord = dot(I.data0.xy, s2half2( 0.5, 0.5 ) ); //Kind of texcoord-hash for motion-FSAA
    return s2half4(  tex0.xyz * I.data0.w, texCoord );
#else
    return s2half4(  tex0.xyz * I.data0.w, tex0.w );
#endif

  } 
#endif

#ifdef PS_DECALS_20
  fragout2 mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform half4    light_col_amb)
  {
	  fragout2 O;
	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord.xy);
	  // calc to-face-lightning
	  half is2Lightning = step(0.2, I.lightDir.w);
	  O.col[0] = half4(is2Lightning * light_col_amb.w * half3(1.0, 1.0, 1.0), tex0.a);
	  O.col[1] = half4(is2Lightning * light_col_amb.w * light_col_amb.xyz, 0.0);
	  return O;
  } 
#endif