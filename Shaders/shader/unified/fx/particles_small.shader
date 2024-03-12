//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:LAYER_BIT2

#ifdef LAYER_BIT0
  #define STREAK_SHADER
#endif

#ifdef LAYER_BIT1
  #define MEDIUM_PARTICLES
#endif

#ifdef LAYER_BIT2
  #define SOFT_PARTICLES
#endif

// particles
#include "extractvalues.shader"
struct appdata {
	float3 position   : POSITION;
	float  size       : TEXCOORD0;
	float4 color      : COLOR0;	// Brightness premultiplied
	float4 data       : COLOR1;	// volatile data per quad vertex {w,x,y,z} = {RotAngle, u, v, BlendMode/Index}
#ifdef MEDIUM_PARTICLES
  float2 str_data   : TEXCOORD1;
  float4 direction  : TEXCOORD2;
#endif
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
	float4 color      : COLOR0;
	float   toBlend : TEXCOORD1;
#ifdef SOFT_PARTICLES
  float4 screenCoordsInTexSpace : TEXCOORD2;
  float  depth                  : TEXCOORD3;
#endif
//	float4 brightness : COLOR1;
};



pixdata mainVS( appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldViewMatrix,
    uniform float4x4 worldMatrix,
    uniform float4   zfrustum_data,
    uniform float4   vtx_data_array[5] )
{
	pixdata O;
	
	float4 pos4 = float4(I.position.xyz, 1.0);

	// transform center of particle into view-space
  pos4 = mul( pos4, worldViewMatrix );

	float index;
	float blend = modf(I.data.z * 4, index);
	float extraRot = modf(blend * 4, blend);
	
	


	// offset to this vertex to get billboard
	float4 offset = I.size * vtx_data_array[index];

#ifdef MEDIUM_PARTICLES
  float4 dir_VS = float4( I.direction.xyz, 0.0 );
         //dir_VS = mul( dir_VS, mul( worldMatrix, worldViewMatrix ) );
         dir_VS = mul( dir_VS, worldViewMatrix );
	// rotate this offset to get rotated particles
  float len = length( dir_VS.xy );
  float inv_len = 1.0 / len;
  dir_VS.xy *= inv_len;
	float2x2 screenRotation;
	screenRotation[0] = float2(  dir_VS.y, -dir_VS.x );
	screenRotation[1] = float2(  dir_VS.x,  dir_VS.y );

  offset.x *= I.str_data.x;
  offset.y  = offset.z;
  offset.y *= len * I.direction.w * I.str_data.y;
  offset.y += offset.w;
	offset.xy = mul(offset.xy, screenRotation);
#else
	// rotate this offset to get rotated particles
	float2x2 screenRotation;
	float rotpi = (I.data.w + extraRot / 256.0) * 2 * 3.141592653589f;
	screenRotation[0] = float2(cos(rotpi), sin(rotpi));
	screenRotation[1] = float2(-sin(rotpi), cos(rotpi));
	offset.xy = mul(offset.xy, screenRotation);
#endif

	// offset! vertex
	pos4.xy += offset.xy;

	// transform into proj-space
	O.hposition = mul(pos4, worldViewProjMatrix);

	// pass texture coords & color & brightness
	O.texcoord0 = I.data.xyyy;
	O.texcoord0.xy *= vtx_data_array[4].xy; 
	O.color = I.color;
	

	O.toBlend = blend<0.3?0:1;

#ifdef SOFT_PARTICLES
  // vertex-position in screen space for depth texture lookup
  O.screenCoordsInTexSpace = calcScreenToTexCoord(O.hposition);
  // normalized depth of this vertex
  O.depth = - pos4.z * zfrustum_data.w;
#endif

//	O.color = I.color;
//  O.brightness = I.data.yyyy;

	return O;
}

fragout_t mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D depth_map )
{
  fragout_t O;
  // greyscale sprite
  float4 tex0 = tex2D(texture0, I.texcoord0.xy);
//  float4 final_col = (I.color + I.color.a * I.brightness) * tex0;

  float4 final_col = (I.color * float4(2,2,2,1)) * tex0;
#ifdef STREAK_SHADER  
  final_col.rgb *= I.color.a;
#endif

 float4 blended = float4(final_col.rgb * final_col.a, final_col.a);
 float4 added = float4(final_col.rgb, 0 );

#ifdef SOFT_PARTICLES
  // normalized depth value
 float bgdepth = tex2Dproj( depth_map, I.screenCoordsInTexSpace ).x;
 float delta   = saturate( ( bgdepth - I.depth ) * 500.0 );
 set_out_color( (I.toBlend < 0.5? blended:added) * delta );
#else
 set_out_color( I.toBlend < 0.5? blended:added );
#endif

 set_out_glow(float4(0.0, 0.0, 0.0, 0.0));
 return O;
} 


