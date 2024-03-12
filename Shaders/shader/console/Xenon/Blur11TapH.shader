#include "S2Types.shader"

//--------------------------------------------------------------------------------------
// Vertex shader globals
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Pixel  shader globals
//--------------------------------------------------------------------------------------

sampler2D Sampler0          : register(s0); // Shadow map texture for downsample pixel shader.
float4    g_vViewPort      	: register(c0);

//--------------------------------------------------------------------------------------
// Name: ScreenSpaceShaderVS()
// Desc: Pass-thru shader
//--------------------------------------------------------------------------------------
float4 mainVS( float4 vPosition : POSITION ) : POSITION
{
  return float4(vPosition.xy,1,1);
}

//--------------------------------------------------------------------------------------
// Name: HorizontalBlurDepthToVariancePS()
// Desc: Copy depth to variance and perform the horizontal portion of a two-pass
//       separable 11x11 Gaussian blur
//--------------------------------------------------------------------------------------
float4 mainPS( float2 vPos : VPOS ) : COLOR0
{
#ifdef Ps3_IMPL
	float2 vTexCoord = vPos*g_vViewPort.zw;
#else
	float2 vTexCoord = vPos*g_vViewPort.zw + g_vViewPort.xy;
#endif

    // 11-tap gaussian blur
    float4 ds0 = tex2D( Sampler0, vTexCoord - float2( g_vViewPort.z *  45.f/ 11.f, 0 ) );
    float4 ds1 = tex2D( Sampler0, vTexCoord - float2( g_vViewPort.z * 375.f/165.f, 0 ) );
    float4 ds2 = tex2D( Sampler0, vTexCoord - float2( g_vViewPort.z * 210.f/336.f, 0 ) );
    float4 ds3 = tex2D( Sampler0, vTexCoord + float2( g_vViewPort.z * 210.f/336.f, 0 ) );
    float4 ds4 = tex2D( Sampler0, vTexCoord + float2( g_vViewPort.z * 375.f/165.f, 0 ) );
    float4 ds5 = tex2D( Sampler0, vTexCoord + float2( g_vViewPort.z *  45.f/ 11.f, 0 ) );
    
    return ( ds0*11.f + ds1*165.f + ds2*336.f + ds3*336.f + ds4*165.f + ds5*11.f )/1024.f;
}