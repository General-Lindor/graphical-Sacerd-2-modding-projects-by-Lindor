//#OptDef:S2_FOG

// 2D drawing for deferred shading regarding miniobjs
#include "S2Types.shader"

struct appdata {
	float  index      : TEXCOORD0;
};

struct pixdata {
	float4 hposition  : POSITION;
#ifdef SM1_1
  float2 texcoord0  : TEXCOORD0;
  float2 texcoord1  : TEXCOORD1;
#else
  float4 texcoord0  : TEXCOORD0;
  float4 texcoord1  : TEXCOORD1;
#endif
};

#ifdef SM1_1
  struct fragout {
	  float4 col        : COLOR;
  };
#else
  struct fragout {
	  float4 col[2]     : COLOR;
#ifdef PS3_IMPL
	  s2half4 colCopy   : COLOR2;
#endif
  };
#endif

pixdata mainVS(appdata I,
    uniform float4   vtx_data_array[4],
    uniform float4   fog_data,
    uniform float4   zfrustum_data )
{
	pixdata O;

	// all data is in array
	float4 data = vtx_data_array[I.index];

	// vertex pos already transformed
	O.hposition = float4(data.xy, 1.0, 1.0);

#ifdef SM1_1
  O.texcoord0 = O.texcoord1 = float2( data.zw );
#else
  #ifdef S2_FOG
    O.texcoord0 = float4( data.zw, float2( (fog_data.x - zfrustum_data.x) * zfrustum_data.z, fog_data.w ) );
    O.texcoord1 = float4( zfrustum_data.y - zfrustum_data.x, fog_data.x, fog_data.z, 0.0 );
  #else
    O.texcoord0 = float4( data.zw, float2( 0,0 ) );
    O.texcoord1 = 0;
  #endif
#endif

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D texture1,
    uniform float4    light_col_amb,
    uniform float4    light_col_diff,
    uniform float4    param,
    uniform sampler2D gradient_texture,
    uniform sampler2D fog_texture )
{
	fragout O;

	// get data of this pixel
	float4 data0 = tex2D(texture0, I.texcoord0.xy);
#ifdef SM1_1
  float4 data1 = tex2D(texture1, I.texcoord1.xy);
#else
	float4 data1 = tex2D(texture1, I.texcoord0.xy);
#endif

  data0.xyz = data0.xyz * (light_col_amb.xyz + data1.z * light_col_diff.xyz);

  // is this the right miniobwjID?
/*
  if(data1.w < param.x)
  	O.col[0] = float4(data0.xyz * (light_col_amb.xyz + data1.z * light_col_diff.xyz), 1.0);
  else
  	O.col[0] = float4(0.0, 1.0, 0.0, 0.0);
*/

#ifdef SM1_1
  O.col = float4( data0.xyz, 1.0 );
#else
  #ifdef S2_FOG
      float  depth = dot( tex2D( gradient_texture, data1.xy ).xy, float2( 1.0, 1.0 / 256.0 ) );
           depth = (depth * I.texcoord1.x - I.texcoord1.y) * I.texcoord1.z;
      float4 fog_color = tex2D( fog_texture, float2( depth, I.texcoord0.w ) );
             data0.xyz = lerp( data0.xyz, fog_color.xyz * light_col_diff.xyz, fog_color.w );
  #endif

  	O.col[0] = float4(data0.xyz, 1.0);
    O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
#ifdef PS3_IMPL
  O.colCopy=O.col[0];
#endif
#endif

	return O;
} 
