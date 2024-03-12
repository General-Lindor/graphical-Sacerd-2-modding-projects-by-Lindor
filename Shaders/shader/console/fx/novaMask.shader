// mask for refrection nova
#define VERT_XVERTEX
#include "extractvalues.shader"


#if defined(SM1_1)
  DEFINE_VERTEX_DATA

  struct pixdata {
	  float4 hposition   : POSITION;
  };

  struct fragout {
	  float4 col         : COLOR;
  };

  pixdata mainVS(appdata I,
      uniform float4x4 worldViewProjMatrix,
      uniform float4 vtx_data_array[2])
  {
	  pixdata O;

    // usefull names
    float inner_radius = vtx_data_array[0].x;
    float delta_radius = vtx_data_array[0].y;
    float z_offset = vtx_data_array[0].w;

    // position (put at level z to avoid z-fighting!)
	  float4 pos4 = float4(I.position.xy, z_offset, 1.0);

    // make circular (+ 1.0 because circle is calc'ed from geom and we need more "space on poly"!)
    pos4.xy += inner_radius * I.normal.xy + 2.0 * I.position.z * delta_radius * I.normal.xy;

	  // transform
	  O.hposition = mul(pos4, worldViewProjMatrix);

	  return O;
  }

  fragout mainPS(pixdata I)
  {
	  fragout O;

    // out
	  O.col = float4(1.0, 1.0, 1.0, 1.0);

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
  };

  struct fragout {
	  float4 col         : COLOR;
  };


  pixdata mainVS(appdata I,
      uniform float4x4 worldViewProjMatrix,
      uniform float4 vtx_data_array[2])
  {
	  pixdata O;

    // useful names
    float inner_radius = vtx_data_array[0].x;
    float delta_radius = vtx_data_array[0].y;
    float z_offset = vtx_data_array[0].w;

    // position (put at level z to avoid z-fighting!)
	  float4 pos4 = float4(I.position.xy, z_offset, 1.0);

    // make circular (+ 1.0 because circle is calc'ed from geom and we need more "space on poly"!)
    pos4.xy += inner_radius * I.normal.xy + 2.0 * I.position.z * delta_radius * I.normal.xy;

	  // transform
	  O.hposition = mul(pos4, worldViewProjMatrix);

	  return O;
  }

  fragout mainPS(pixdata I)
  {
	  fragout O;

    // out
	  O.col = float4(1.0, 1.0, 1.0, 1.0);

	  return O;
  } 

#endif

