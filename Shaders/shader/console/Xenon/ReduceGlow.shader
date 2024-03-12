#include "S2Types.shader"

sampler Sampler0    : register(s0);
half4   g_vViewPort	: register(c0);

//--------------------------------------------------------------------------------------
// Vertex shaders
//--------------------------------------------------------------------------------------
float4 mainVS( float4 vPosition : POSITION ) : POSITION
{
  return float4(vPosition.xy,1,1);
}

//--------------------------------------------------------------------------------------
// Pixel shaders
//--------------------------------------------------------------------------------------
float4 mainPS( float2 vPos : VPOS ) : COLOR0
{
#ifdef XENON_IMPL
  s2half2 vTexCoord = vPos*tiling_data_half_tile.zw + tiling_data_half_tile.xy;

  s2half2 vTexCoord0 = vTexCoord*g_vViewPort.xy + g_vViewPort.zw*float2(-1,-1);
  s2half2 vTexCoord1 = vTexCoord*g_vViewPort.xy + g_vViewPort.zw*float2( 1,-1);
  s2half2 vTexCoord2 = vTexCoord*g_vViewPort.xy + g_vViewPort.zw*float2(-1, 1);
  s2half2 vTexCoord3 = vTexCoord*g_vViewPort.xy + g_vViewPort.zw*float2( 1, 1);
  float4 tex0 = tex2D( Sampler0, vTexCoord0 );
  float4 tex1 = tex2D( Sampler0, vTexCoord1 );
  float4 tex2 = tex2D( Sampler0, vTexCoord2 );
  float4 tex3 = tex2D( Sampler0, vTexCoord3 );
  return (tex0+tex1+tex2+tex3)*0.25;
#else
  s2half2 vTexCoord = (vPos+float2(0.5h,0.5h))*target_data.zw;
  return tex2D( Sampler0, vTexCoord*g_vViewPort );
#endif
}