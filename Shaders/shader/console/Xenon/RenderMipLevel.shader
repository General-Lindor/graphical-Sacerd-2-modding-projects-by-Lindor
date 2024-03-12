#include "S2Types.shader"

//--------------------------------------------------------------------------------------
// Vertex shader globals
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Pixel  shader globals
//--------------------------------------------------------------------------------------
sampler2D Sampler0      : register(s0); // Z-Buffer
sampler2D Sampler1      : register(s1); // ShadowMap

float4x4 g_mInvViewProj	: register(c0 );
float4x4 g_mLightMatrix	: register(c4 );
float4x4 g_mScreen2Light	: register(c8 );
float4   g_vShadowData	: register(c12);

	
//--------------------------------------------------------------------------------------
// Name: ScreenSpaceShaderVS()
// Desc: Pass-thru shader
//--------------------------------------------------------------------------------------
struct pixdata
{
	float4 hposition  : POSITION;
	float2 vTexCoord  : TEXCOORD0;
};

pixdata mainVS( float4 vPosition : POSITION )
{
    pixdata O;
    O.hposition  = float4( vPosition.x, vPosition.y, 1.0f, 1.0f );
    
    vPosition *= g_vShadowData/(g_vShadowData+1);
    O.vTexCoord.xy = (float2( vPosition.x, vPosition.y ) + 1.0f) * 0.5f;
    O.vTexCoord.y = 1-O.vTexCoord.y;

    return O;
}

//--------------------------------------------------------------------------------------
// Name: DeferredShadow()
// Desc: calculate Depth from D24S8 Z-Buffer (write in red/green) 
//       and compute shadow-intensity (write in blue)
//--------------------------------------------------------------------------------------
struct fragout {
	float4 col     : COLOR;
};

half calcMipLevel(sampler2D DepthTex, half4 vLightSpacePos, half4 shadow_data )
{
	// Compute projected xyz.
	vLightSpacePos.xyz = vLightSpacePos.xyz / vLightSpacePos.w;
	half ObjDepth = vLightSpacePos.z;
	vLightSpacePos.w = 0;
	
  float4 Weights;
  float4 tex0;
  asm
  {
    setTexLOD vLightSpacePos.w
    tfetch2D tex0.x___, vLightSpacePos, DepthTex, OffsetX =-0.5, OffsetY =-0.5, UseComputedLOD=false, UseRegisterLOD=true, MagFilter=point, MinFilter=point
    tfetch2D tex0._x__, vLightSpacePos, DepthTex, OffsetX = 0.5, OffsetY =-0.5, UseComputedLOD=false, UseRegisterLOD=true, MagFilter=point, MinFilter=point
    tfetch2D tex0.__x_, vLightSpacePos, DepthTex, OffsetX =-0.5, OffsetY = 0.5, UseComputedLOD=false, UseRegisterLOD=true, MagFilter=point, MinFilter=point
    tfetch2D tex0.___x, vLightSpacePos, DepthTex, OffsetX = 0.5, OffsetY = 0.5, UseComputedLOD=false, UseRegisterLOD=true, MagFilter=point, MinFilter=point
    
 		getWeights2D Weights, vLightSpacePos.xy, DepthTex, MagFilter=linear, MinFilter=linear, UseComputedLOD=false, UseRegisterLOD=true
  };
	Weights = float4( (1-Weights.x)*(1-Weights.y), 
				               Weights.x *(1-Weights.y), 
				            (1-Weights.x)*   Weights.y , 
				               Weights.x *   Weights.y );
    
  float4 ret = (5.f * saturate(ObjDepth.xxxx - tex0)) - 0.1f;

  return dot( ret, Weights );
}

fragout mainPS( pixdata I, 
                float2 vPos : VPOS )
{
	fragout ret;
	float4 ZBuffer_Sample;
	float2 vTexCoord = I.vTexCoord;
	asm
	{
    tfetch2D ZBuffer_Sample,      vTexCoord, Sampler0, OffsetX = 0.5, OffsetY = 0.5, MinFilter=point, MagFilter=point
  };

	// compute z value from sampled z-buffer
  float z_world = (2*Z_FAR*Z_NEAR) / ((Z_FAR+Z_NEAR) - (2*ZBuffer_Sample.r-1)*(Z_FAR-Z_NEAR));
  float z_scaled = (z_world/(Z_FAR - Z_NEAR)) - (Z_NEAR/(Z_FAR - Z_NEAR));
	g_vShadowData.z = z_world;

	// calculate lightmap coords
	vPos += 0.5f;
	vPos *= float2( 2.f/g_vShadowData.x, -2.f/g_vShadowData.y );
	vPos += float2( -1, 1 );

  float4 posScreen  = float4( vPos.xy, ZBuffer_Sample.r, 1.f ) * z_world;
  float4 posInLight = mul( posScreen,  g_mScreen2Light );
  
  ret.col = calcMipLevel(Sampler1, posInLight, g_vShadowData );
  return ret;
}