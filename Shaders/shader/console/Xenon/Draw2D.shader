#include "S2Types.shader"

//--------------------------------------------------------------------------------------
// Texture samplers
//--------------------------------------------------------------------------------------
sampler Sampler0  : register(s0);

//--------------------------------------------------------------------------------------
// Vertex shaders
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Name: ScreenSpaceShaderVS()
// Desc: Pass-thru shader
//--------------------------------------------------------------------------------------
float4 mainVS( float4 vPosition : POSITION ) : POSITION
{
  return float4(vPosition.xy,1,1);
}

//--------------------------------------------------------------------------------------
// Pixel shaders
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Name: CopyTexturePS()
// Desc: Copies a texture. Scaling is controlled by the render target size.
//--------------------------------------------------------------------------------------
struct fragout {
	float4 col     : COLOR;
};

fragout mainPS( float2 vPos : VPOS )
{
  fragout ret;
#ifdef XENON_IMPL  
  s2half2 vTexCoord = vPos*tiling_data_half_scr.zw + tiling_data_half_scr.xy;
#else
  s2half2 vTexCoord = (vPos+float2(0.5h,0.5h))*target_data.zw;
#endif
  ret.col = tex2D( Sampler0, vTexCoord );
  return ret;
}
