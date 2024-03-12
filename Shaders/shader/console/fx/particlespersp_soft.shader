// soft-particles
/*
fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D texture1 )
{
	fragout O;

    // greyscale sprite
    float4 tex0 = tex2D(texture0, I.texcoord0.xy);

	O.col[0] = (I.color + I.color.a * I.brightness) * tex0;
	O.col[1] = float4(0.0, 0.0, 0.0, 0.0);

	float depthMap = dot(tex2D(texture1, I.ScreenPos.xy).xy, float2(1.0, 1.0 / 256.0) );
	depthMap = Z_NEAR + (depthMap * (Z_FAR - Z_NEAR));
	
	float depthParticle = (depthMap - I.ScreenPos.z) / 10.f;
    
    //O.col[0].a *= pow( saturate(depthParticle), 2 );
    O.col[0].a *= saturate(depthParticle);
   
	return O;
} 
*/

//#OptDef:LAYER_BIT0

#ifdef LAYER_BIT0
  #define STREAK_SHADER
#endif

// particles
#include "extractvalues.shader"
struct appdata {
	float3 position   : POSITION;
	float  size       : TEXCOORD0;
	float4 color      : COLOR0;	// Brightness premultiplied
	float4 data       : COLOR1;	// volatile data per quad vertex {w,x,y,z} = {RotAngle, u, v, BlendMode/Index}
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
	float2 toBlend    : TEXCOORD1;
  float4 color      : COLOR0;
//	float4 brightness : COLOR1;
};



pixdata mainVS( appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldViewMatrix,
    uniform float4x4 worldMatrix,
    uniform float4x4 lightMatrix,
    uniform float4   vtx_data_array[4] )
 )
{
	pixdata O;
	
	float4 pos4 = float4(I.position.xyz, 1.0);

	// transform center of particle into view-space
  // we need two separate matrices as streaks are already in world space
	pos4 = mul( pos4, worldViewMatrix );

	float index;
	float blend = modf(I.data.z * 4, index);
	float extraRot = modf(blend * 4, blend);

	// offset to this vertex to get billboard
	float4 offset = I.size * vtx_data_array[index];

	// rotate this offset to get rotated particles
	float2x2 screenRotation;
	float rotpi = (I.data.w/16 + extraRot) * 2 * 3.141592653589f;
	screenRotation[0] = float2(cos(rotpi), sin(rotpi));
	screenRotation[1] = float2(-sin(rotpi), cos(rotpi));
	offset.xz = mul(offset.xz, screenRotation);

	offset = mul(offset, lightMatrix);

	// offset! vertex
	pos4 += offset;

	// transform into proj-space
	O.hposition = mul(pos4, worldViewProjMatrix);

	// pass texture coords & color & brightness
	O.texcoord0 = I.data.xyyy;
	O.color = I.color;

	O.toBlend.x = blend<0.3?0:1;

//	O.color = I.color;
//  O.brightness = I.data.yyyy;

  // vertex-depth
	O.toBlend.y = O.hposition.w;
	
	return O;
}

#ifdef CONSOLE_IMPL
/*
    Add constant table to correct wposition. 
    
    FSAA Texture Layout     2xH Texture Layout
     0,  1,  2,  3,		         4,  5,  0,  1,
     4,  5,  6,  7,	    =>	  12, 13,  8,  9,
     8,  9, 10, 11,	    <=	   6,  7,  2,  3,
    12, 13, 14, 15,		        14, 15, 10, 11,
*/ 
void SwizzleVPos( inout half2 ScreenPos )
{
  int2 pos_frac = frac(ScreenPos/4.0)*4.0;
  ScreenPos -= pos_frac;

  const half2 swizzle[16] = 
  {
    half2( 2.5, 0.5 ), half2( 3.5, 0.5 ), half2( 2.5, 2.5 ), half2( 3.5, 2.5 ), 
    half2( 0.5, 0.5 ), half2( 1.5, 0.5 ), half2( 0.5, 2.5 ), half2( 1.5, 2.5 ), 
    half2( 2.5, 1.5 ), half2( 3.5, 1.5 ), half2( 2.5, 3.5 ), half2( 3.5, 3.5 ), 
    half2( 0.5, 1.5 ), half2( 1.5, 1.5 ), half2( 0.5, 3.5 ), half2( 1.5, 3.5 )
  };
  
  ScreenPos += swizzle[pos_frac.x+4*pos_frac.y];
}
#endif

float calcRelDepthDist( float2 z_world, float2 w )
{
  return saturate(z_world-w) / ((z_world.x>w.x)+(z_world.y>w.y));
}

fragout_t mainPS(pixdata I,
                 uniform sampler2D texture0,
                 uniform sampler2D texture1,
                 half2   vPos_rel : VPOS )
{
  fragout_t O;
  // greyscale sprite
  float4 tex0 = tex2D(texture0, I.texcoord0.xy);
//  float4 final_col = (I.color + I.color.a * I.brightness) * tex0;
  float4 final_col = (I.color * float4(2,2,2,1)) * tex0;

  float4 blended = float4(final_col.rgb * final_col.a, final_col.a);
  float4 added = float4(final_col.rgb, 0 );

  set_out_color( I.toBlend.x < 0.3? blended:added );
//  set_out_color( I.texcoord0.xyyy );
  set_out_glow(float4(0.0, 0.0, 0.0, 0.0));
  
  // softparticle code !
#ifdef CONSOLE_IMPL
  vPos_rel *= half2( 1.f, 2.f );
  SwizzleVPos( vPos_rel );
  vPos_rel /= half2( 1280, 512 );
#endif
  
  float2 vPos = vPos_rel;

  float2 depthMap;
  depthMap.x = DEPTH_SAMPLE(texture1, vPos                         ).x;
  depthMap.y = DEPTH_SAMPLE(texture1, vPos - half2( 2.f/1280.f, 0) ).x;  
  O.col0 *= calcRelDepthDist( depthMap, I.toBlend.yy );
  
  return O;
}