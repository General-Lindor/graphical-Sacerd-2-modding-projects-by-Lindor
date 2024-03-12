#include "S2Types.shader"

//--------------------------------------------------------------------------------------
// Vertex shader globals
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Pixel  shader globals
//--------------------------------------------------------------------------------------

sampler2D Sampler0      : register(s0); // Shadow map texture for downsample pixel shader.
sampler2D Sampler1      : register(s1); // Shadow map texture for downsample pixel shader.
sampler2D Sampler2      : register(s2); // Shadow map texture for downsample pixel shader.
sampler2D Sampler3      : register(s3); // Shadow map texture for downsample pixel shader.

half4     g_vViewPort	: register(c0);

//--------------------------------------------------------------------------------------
// Name: ScreenSpaceShaderVS()
// Desc: Pass-thru shader
//--------------------------------------------------------------------------------------
float4 mainVS( float4 vPosition : POSITION ) : POSITION
{
  return float4(vPosition.xy,1,1);
}

//--------------------------------------------------------------------------------------
// Name: DepthToVariancePS()
//--------------------------------------------------------------------------------------

float4 mainPS( float2 vPos : VPOS ) : COLOR
{
  float2 vTexCoord = vPos*g_vViewPort.zw + g_vViewPort.xy;

  float4 DepthSamples = float4( tex2D(Sampler0, vTexCoord ).x,
								tex2D(Sampler1, vTexCoord ).x,
								tex2D(Sampler2, vTexCoord ).x,
								tex2D(Sampler3, vTexCoord ).x );

#ifdef ORC_USE_D24FS8 // reversed ZBuffer  
  DepthSamples = 1-DepthSamples;
#endif

  float4 MinMax;
  MinMax.xy  = min(DepthSamples.xy, DepthSamples.zw);
  MinMax.zw  = max(DepthSamples.xy, DepthSamples.zw);
  float fMin = min(MinMax.x, MinMax.y);
  float fMax = max(MinMax.z, MinMax.w);
  
  // VSM
  float fAvg  = dot(DepthSamples, 0.25f);
  float fAvg2 = dot(DepthSamples*DepthSamples, 0.25f);

  return float4( fAvg, fAvg2, 0, 0 ); // VSM
  return float4( fMin, fAvg,  0, 0 );
  return float4( fMin, fMax,  0, 0 );
}