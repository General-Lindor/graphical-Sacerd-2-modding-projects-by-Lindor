#include "S2Types.shader"

//--------------------------------------------------------------------------------------
// Vertex shader globals
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Pixel  shader globals
//--------------------------------------------------------------------------------------

sampler2D Sampler0      : register(s0); // Shadow map texture for downsample pixel shader.
sampler2D Sampler1      : register(s1); // Shadow map texture for downsample pixel shader.

half4    g_vShadowData	: register(c0);  
half4    g_vViewPort  	: register(c1);
//--------------------------------------------------------------------------------------
// Name: ScreenSpaceShaderVS()
// Desc: Pass-thru shader
//--------------------------------------------------------------------------------------
struct PASSTHRU_VERTEX
{
    float4 Position   : POSITION;
    float2 TexCoords  : TEXCOORD0;
};

PASSTHRU_VERTEX mainVS( float4 vPosition : POSITION )
{
    PASSTHRU_VERTEX Output;
    half2 vPos = vPosition.xy;
    vPos = (vPos + 1.0f) * 0.5f;
    vPos = lerp(g_vViewPort.xy, g_vViewPort.zw, vPos);
    vPos = (vPos * 2.0f) - 1.0f;
    
    Output.Position  = float4( vPos.x, -vPos.y, 1.0f, 1.0f );
    Output.TexCoords = (vPosition.xy+1)*0.5 * g_vShadowData.zw/g_vShadowData.xy;
    
    return Output;
}

//--------------------------------------------------------------------------------------
// Name: RenderDepthPS()
// Desc: Restore Depthbuffer
//--------------------------------------------------------------------------------------
struct fragout {
	float4  Color0 : COLOR0;
	float4  Color1 : COLOR1;
};

fragout mainPS( in float2 vTexCoord : TEXCOORD0 )
{
  float4 DiffSamples;
  float4 GlowSamples;
  asm
  {
      tfetch2D DiffSamples,      vTexCoord, Sampler0, MinFilter=point, MagFilter=point
      tfetch2D GlowSamples,      vTexCoord, Sampler1, MinFilter=point, MagFilter=point
  };

  fragout ret;
  ret.Color0 = DiffSamples;
  ret.Color1 = GlowSamples;
  return ret;
}