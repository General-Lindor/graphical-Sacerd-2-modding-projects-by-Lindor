
// post render blit
#include "shadow.shader"
#include "extractvalues.shader"

struct appdata {
	float3 position   : POSITION;
	float2 texcoord0  : TEXCOORD0;
	float2 texcoord1  : TEXCOORD1;
};

struct pixdata {
	float4 hposition    : POSITION;
	float4 texcoord     : TEXCOORD0;
	float4 frustumEdge  : TEXCOORD1;
	float4 camPos       : TEXCOORD2;
};

struct fragout {
	float4 col        : COLOR;
};


pixdata mainVS(appdata I,
               uniform float4   vtx_data_array[8])
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = float4(I.position.xy, 0.0, 1.0);
	// pass texture coord
	O.texcoord    = I.texcoord0.xyyy;
	O.texcoord.xy = (O.texcoord.xy-viewport_data.xy)*viewport_data.zw;
	
	int index     = I.texcoord1.x;
	O.frustumEdge = vtx_data_array[index];
	O.camPos      = vtx_data_array[index+4];
  

	return O;
}

 
fragout mainPS(pixdata I,
               float2             vPos : VPOS,
               uniform sampler2D depth_map,
               uniform sampler2D shadow_map,
               uniform sampler3D textureVolume,
               uniform sampler2D fog_texture,
               uniform float4    fog_color,
               uniform float4    fog_data,
               uniform float4    shadow_data,
               uniform float4x4  std_matrix,
               uniform int       anzIterations,
               uniform float4    zfrustum_data) 
{
	fragout O;
  // get original color
	float  depth_val = tex2D(depth_map, I.texcoord.xy).x;
  float4 wpos      = I.frustumEdge*depth_val+I.camPos;
  float4 ls_pos    = mul( wpos, std_matrix ); 
	float  shadow    = calcShadow( shadow_map, textureVolume, ls_pos, vPos, shadow_data.y, shadow_data.x, anzIterations );
         shadow    = lerp( 1.0, shadow, shadow_settings.x );
#ifdef CALC_DEFERRED_FOG
	float2 fog_tc    = float2(depth_val*fog_data.x-fog_data.y,fog_data.w);
	float  fog_val   = tex2D(fog_texture,fog_tc).a;
#else
	float  fog_val   = 0;
#endif
  O.col            = float4(0,fog_val,shadow,0);

  return O;
} 

