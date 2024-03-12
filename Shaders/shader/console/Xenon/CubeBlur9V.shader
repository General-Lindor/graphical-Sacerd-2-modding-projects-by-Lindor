#include "S2Types.shader"

//--------------------------------------------------------------------------------------
// VarianceShadowMaps.hlsl
//
// Shadow mapping sample comparing variance shadow maps to traditional shadow maps.
//
// Xbox Advanced Technology Group.
// Copyright (C) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Vertex shader globals
//--------------------------------------------------------------------------------------
float3x3 g_CubeRot : register(c0);
float3	 g_fOffset : register(c3);

//--------------------------------------------------------------------------------------
// Pixel  shader globals
//--------------------------------------------------------------------------------------
samplerCUBE Sampler0 : register(s0); // Shadow map texture for downsample pixel shader.

//--------------------------------------------------------------------------------------
// Name: ScreenSpaceShaderVS()
// Desc: Pass-thru shader
//--------------------------------------------------------------------------------------
struct PASSTHRU_VERTEX
{
    float4 Position   : POSITION;
    float3 TexCoords  : TEXCOORD0;
    float3 TexOffset  : TEXCOORD1;
};

PASSTHRU_VERTEX mainVS( float4 vPosition : POSITION )
{
    PASSTHRU_VERTEX Output;
    Output.Position  = float4( vPosition.x, vPosition.y, 1.0f, 1.0f );
    Output.TexCoords = float3( 1, vPosition.y, -vPosition.x );
    Output.TexCoords = mul( Output.TexCoords, g_CubeRot );
    
    Output.TexOffset = mul( g_fOffset.xzy, g_CubeRot );
    return Output;
}

//--------------------------------------------------------------------------------------
// Name: VerticalBlurDepthToVariancePS()
// Desc: Vertical portion of a two-pass separable 9x9 Gaussian blur for variance
//       shadow maps
//--------------------------------------------------------------------------------------
struct fragout {
	float4 col     : COLOR;
};
#ifdef CONSOLE_IMPL
  // R16G16
  fragout mainPS( in float3 vTexCoord : TEXCOORD0, 
				          in float3 vTexOffset : TEXCOORD1 )
  {
    // Note that this pass of the separable filter can use filtered fetches
    // Fetch 5 samples which filter across a column of 9 pixels from the VSM
    float4 t01, t23, t4_;

	  // 9 tap
	  float weight1 = 3.0 +  1.0/ 9.0;
	  float weight2 = 1.0 + 28.0/84.0;
	  t01.rg = texCUBE( Sampler0, vTexCoord-weight1*vTexOffset ).rg;
    t01.ba = texCUBE( Sampler0, vTexCoord-weight2*vTexOffset ).rg;
    t23.rg = texCUBE( Sampler0, vTexCoord ).rg;
    t23.ba = texCUBE( Sampler0, vTexCoord+weight2*vTexOffset ).rg;
    t4_.rg = texCUBE( Sampler0, vTexCoord+weight1*vTexOffset ).rg;

    float4 z  = float4( t01.rb, t23.rb );
    float4 z2 = float4( t01.ga, t23.ga );
    
    // Sum results with Gaussian weights
    z.x  = dot( z,  float4( 9.0/256.0, 84.0/256.0, 70.0/256.0, 84.0/256.0 ) ) + t4_.r*( 9.0/256.0 );
    z2.x = dot( z2, float4( 9.0/256.0, 84.0/256.0, 70.0/256.0, 84.0/256.0 ) ) + t4_.g*( 9.0/256.0 );

    fragout O;
    O.col = float4( z.x, z2.x, 0, 1 );
    return O;
  }
#else
  fragout mainPS( in float3 vTexCoord : TEXCOORD0, 
				  in float3 vTexOffset : TEXCOORD1 )
  {
      //A8R8G8B8
      // Note that this second pass of the separable filter can use filtered fetches
      // Fetch 4 samples which filter across a column of 5 pixels from the VSM
      float4 t0, t1, t2, t3, t4;

	  // sample the points exactly since we haven't calculated z-squared yet
      t0 = texCUBE( Sampler0, vTexCoord-2.0*vTexOffset );
      t1 = texCUBE( Sampler0, vTexCoord-1.0*vTexOffset );
      t2 = texCUBE( Sampler0, vTexCoord+0.0*vTexOffset );
      t3 = texCUBE( Sampler0, vTexCoord+1.0*vTexOffset );
      t4 = texCUBE( Sampler0, vTexCoord+2.0*vTexOffset );
      
      float4 z0, z1, z01;
      z0.x  = dot( t0.rgb, float3(255.0/256, 255.0/(256*256), 1.0/(256*256)) );
      z0.y  = dot( t1.rgb, float3(255.0/256, 255.0/(256*256), 1.0/(256*256)) );
      z0.z  = dot( t2.rgb, float3(255.0/256, 255.0/(256*256), 1.0/(256*256)) );
      z0.w  = dot( t3.rgb, float3(255.0/256, 255.0/(256*256), 1.0/(256*256)) );
      z01.r = dot( t4.rgb, float3(255.0/256, 255.0/(256*256), 1.0/(256*256)) );
      
      z1.x  = z0.x *z0.x;
      z1.y  = z0.y *z0.y;
      z1.z  = z0.z *z0.z;
      z1.w  = z0.w *z0.w;
      z01.g = z01.r*z01.r;
    
      // Sum results with Gaussian weights
      float z  = dot( z0, float4( 1.0/16, 4.0/16, 6.0/16, 4.0/16 ) ) + z01.r * ( 1.0 / 16 );
      float z2 = dot( z1, float4( 1.0/16, 4.0/16, 6.0/16, 4.0/16 ) ) + z01.g * ( 1.0 / 16 );
      
      fragout O;
      O.col.r = ((int)(z *255.999))/256.0; z  = (z -O.col.r)*256;
	  O.col.g = ((int)(z2*255.999))/256.0; z2 = (z2-O.col.g)*256;
	  O.col.b = z;
	  O.col.a = z2;
	  O.col.rg *= (256.0/255);
      return O;
  }
#endif