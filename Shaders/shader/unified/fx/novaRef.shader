// refraction nova in ground

#define VERT_XVERTEX
#include "extractvalues.shader"

#if defined(SM1_1)
  DEFINE_VERTEX_DATA

  struct pixdata {
	  float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float4 circ_pos    : TEXCOORD1;
	  float4 screenCoord : TEXCOORD2;
  };

  struct fragout {
	  float4 col      : COLOR;
  };
  
  pixdata mainVS(appdata I,
      uniform float4x4 worldViewProjMatrix,
      uniform float4   target_data,
      uniform float4   vtx_data_array[2])
  {
	  pixdata O;

    // usefull names
    float inner_radius = vtx_data_array[0].x;
    float delta_radius = vtx_data_array[0].y;
    float intensity = vtx_data_array[0].z;
    float z_offset = vtx_data_array[0].w;

    // position (put at level z==x to avoid z-fighting!)
	  float4 pos4 = float4(I.position.xy, z_offset, 1.0);

    // make circular (+ 0.5 because circle is calc'ed from geom and we need more "space on poly"!)
    pos4.xy += inner_radius * I.normal.xy + 1.5 * I.position.z * delta_radius * I.normal.xy;

	  // transform
	  O.hposition = mul(pos4, worldViewProjMatrix);

	  // vertex-position in screen space
	  O.screenCoord.x = O.hposition.w + O.hposition.x;
	  O.screenCoord.y = O.hposition.w - O.hposition.y;
	  O.screenCoord.z = O.hposition.z;
	  O.screenCoord.w = 2.0 * O.hposition.w;
	  O.screenCoord.xy *= target_data.xy;

    // pass pos
    O.circ_pos = float4(pos4.xy, inner_radius, delta_radius);
    // texcoords
    O.texcoord0 = float4(I.texcoord.xy, intensity, 0.f);

	  return O;
  }

  fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler2D   texture3,
    uniform sampler3D   textureVolume,
    uniform float4      param,
    uniform float4      target_data)
  {
	  fragout O;

  /*  // usefull names
    float intensity = I.texcoord0.z;
    float inner_radius = I.circ_pos.z;
    float delta_radius = I.circ_pos.w;
    float time = param.x;

    // one texcoord comes from pos
    s2half radial_tc = saturate((length(I.circ_pos.xy) - inner_radius) / delta_radius);

    // calc v-stretch
    float umfang = 0.5 * delta_radius;

	  // gradient
	  s2half4 tex0 = tex2D(texture0, float2(radial_tc, umfang * I.texcoord0.x));
    // caust
    s2half4 cau = tex3D(textureVolume, float3(radial_tc, umfang * I.texcoord0.x, time));


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
	  O.col = float4(bgr.xyz, 1.0);*/
	  O.col = float4(0.0, 0.0, 0.0, 1.0);

	  return O;
  } 
  
#else
  struct appdata {
	  float3 position    : POSITION;
	  float3 normal      : NORMAL;
	  float3 tangent     : TANGENT;
	  float3 binormal    : BINORMAL;
	  float2 texcoord    : TEXCOORD0;
	  float2 data        : TEXCOORD1;
  };

  struct pixdata {
	  float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float4 circ_pos    : TEXCOORD1;
	  float4 screenCoord : TEXCOORD2;
  };

  struct fragout {
	  float4 col[2]      : COLOR;
  };


  pixdata mainVS(appdata I,
      uniform float4x4 worldViewProjMatrix,
      uniform float4   target_data,
      uniform float4   vtx_data_array[2])
  {
	  pixdata O;

    // usefull names
    float inner_radius = vtx_data_array[0].x;
    float delta_radius = vtx_data_array[0].y;
    float intensity = vtx_data_array[0].z;
    float z_offset = vtx_data_array[0].w;

    // position (put at level z==x to avoid z-fighting!)
	  float4 pos4 = float4(I.position.xy, z_offset, 1.0);

    // make circular (+ 0.5 because circle is calc'ed from geom and we need more "space on poly"!)
    pos4.xy += inner_radius * I.normal.xy + 1.5 * I.position.z * delta_radius * I.normal.xy;

	  // transform
	  O.hposition = mul(pos4, worldViewProjMatrix);

	  // vertex-position in screen space
	  O.screenCoord.x = O.hposition.w + O.hposition.x;
	  O.screenCoord.y = O.hposition.w - O.hposition.y;
	  O.screenCoord.z = O.hposition.z;
	  O.screenCoord.w = 2.0 * O.hposition.w;
	  O.screenCoord.xy *= target_data.xy;

    // pass pos
    O.circ_pos = float4(pos4.xy, inner_radius, delta_radius);
    // texcoords
    O.texcoord0 = float4(I.texcoord.xy, intensity, 0.f);

	  return O;
  }

  fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler2D   texture3,
    uniform sampler3D   textureVolume,
    uniform float4      param,
    uniform float4      target_data)
  {
	  fragout O;

    // usefull names
    float intensity = I.texcoord0.z;
    float inner_radius = I.circ_pos.z;
    float delta_radius = I.circ_pos.w;
    float time = param.x;

    // one texcoord comes from pos
    s2half radial_tc = saturate((length(I.circ_pos.xy) - inner_radius) / delta_radius);

    // calc v-stretch
    float umfang = 0.5 * delta_radius;

	  // gradient
	  s2half4 tex0 = tex2D(texture0, float2(radial_tc, umfang * I.texcoord0.x));
    // caust
    s2half4 cau = tex3D(textureVolume, float3(radial_tc, umfang * I.texcoord0.x, time));


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

	  return O;
  } 
#endif
