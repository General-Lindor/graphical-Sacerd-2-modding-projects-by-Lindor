//#OptDef:LAYER_BIT0

#include "extractvalues.shader"

struct appdata
{
  float3 pos : POSITION;
  float2 uv0 : TEXCOORD0;
  float2 uv1 : TEXCOORD1;
};


struct pixdata
{
  float4 hpos: POSITION;
  float2 uv0 : TEXCOORD0;
  float2 uv1 : TEXCOORD1;
  float4 ssc : TEXCOORD2;
};


void mainVS( in  appdata I,
             out pixdata VSOUT,
             uniform float4x4 worldViewProjMatrix )
{
  float4 hpos = mul( float4( I.pos, 1.0 ), worldViewProjMatrix );

  VSOUT.hpos = hpos;
  VSOUT.uv0  = I.uv0;  
  VSOUT.uv1  = I.uv0;
  VSOUT.uv1.y *= 5.0;
  VSOUT.ssc  = calcScreenToTexCoord( hpos );
}

fragout_2 mainPS( in pixdata I,
                uniform sampler2D texture0,
                uniform sampler2D texture1,
                uniform sampler3D textureVolume,
                uniform float4    pix_data_array[2] )
{
  float tex_scroll = pix_data_array[0].x;
  float u          = I.uv0.x;
  float v          = I.uv0.y;
  float w          = ((pix_data_array[0].z - 0.2) * 1.5);
  float offset     = tex_scroll + 1.0;
  float intensity  = pix_data_array[0].w;
  float reach      = pix_data_array[1].x;

  float2 tcs = I.uv0;
  // squash the texture coordinates towards the character (triangle look)
  tcs.x = tcs.x / (1.1 - tcs.y);
  tcs.x = tcs.x * 0.5 + 0.5;

  // scroll the texture
#ifdef LAYER_BIT0
  tcs.y = (tcs.y + tex_scroll * 3.0);
  tcs.y += sin( abs( u ) * S2_PI * 0.5 ) * 0.8 * v;
  float4 tex0 = tex2D( texture1, tcs );
#else
  tcs.y = (tcs.y + tex_scroll) * 3.0;
  // towards the end of the effect we distort the texture to fake a dissolve effect
  float2 distortion = tex2D( texture0, tcs ).rg;
  float4 tex0 = tex3D( textureVolume, float3( tcs + distortion * saturate( (tex_scroll + reach) ) * 0.8, w ) );
  tex0.rgb = dot( tex0.rgb, float3( 0.3, 0.59, 0.11 ) ) * 2.0;
#endif

  // global fade parameters
  float global_fade = pix_data_array[0].y;
  float fade_in, fade_out;
  sincos( I.uv0.y * S2_PI * 0.5, fade_out, fade_in );
  fade_in = pow( fade_in, 0.5 );
  global_fade *= fade_in * fade_out;
  tex0.a *= global_fade;

#ifdef LAYER_BIT0
  tex0.a   *= 1.0 - abs( u );
#else
  // the stronger the effect, the more the color drifts into yellow (aspect color)
  tex0.rgb += float3( 0.05, 0.05, 0.1 ) * float3( intensity * 8.0, intensity * 8.0, intensity * 1.0 );
#endif
  // write the output color
  fragout_2 O;
#ifdef LAYER_BIT0
  O.col0 = tex0;
  O.col1 = tex0;
#else
  O.col0 = tex0 * 2.0;
  O.col1 = tex0 * saturate(intensity+0.5);
#endif
  return O;
}