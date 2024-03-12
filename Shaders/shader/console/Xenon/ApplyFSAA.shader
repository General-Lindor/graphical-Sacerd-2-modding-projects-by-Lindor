#include "S2Types.shader"
//--------------------------------------------------------------------------------------
// shader globals
//--------------------------------------------------------------------------------------
sampler2D CurDepthSampler : register(s0);
sampler2D OldDepthSampler : register(s1);
sampler2D CurColorSampler : register(s2);
sampler2D OldColorSampler : register(s3);

half4    g_vViewPort	: register( c0 );
float3   g_vCurCamPos   : register( c1 );
float3   g_vOldCamPos   : register( c2 );
float3   g_vCamMove     : register( c3 );
float4   g_vJitterDir   : register( c4 );
float4x4 g_mOldViewProj : register( c5 );

float3   g_vecViewTL    : register(  c10 );
float3   g_vecViewDx    : register(  c11 );
float3   g_vecViewDy    : register(  c12 );
//--------------------------------------------------------------------------------------
// Name: ScreenSpaceShaderVS()
// Desc: Pass-thru shader
//--------------------------------------------------------------------------------------
struct shader_data
{
	s2half4 vPosition  : POSITION;
	s2half3 vTexCoord : TEXCOORD0;
};

shader_data mainVS( float4 vPosition : POSITION )
{
  shader_data ret;
  ret.vPosition = float4(vPosition.xy,1,1);
  ret.vTexCoord = g_vecViewTL + vPosition.z*g_vecViewDx + vPosition.w*g_vecViewDy;
  return ret;
}

//--------------------------------------------------------------------------------------
// Name: RenderDepthPS()
// Desc: Restore Depthbuffer
//--------------------------------------------------------------------------------------
float4 mainPS( shader_data I, float2 vPos : VPOS )  : COLOR0
{
  s2half2 vTexCoord_scr  = vPos*tiling_data_half_scr.zw + tiling_data_half_scr.xy;
  s2half2 vTexCoord_tile = vPos*tiling_data_half_tile.zw + tiling_data_half_tile.xy;
//  s2half2 vTexCoord_tile = vPos*g_vViewPort.zw + g_vViewPort.xy;
  
  float4 vCurTex     = tex2D(CurColorSampler, vTexCoord_scr);

  float4 vBlurredTex = tex2D(CurColorSampler, vTexCoord_scr + g_vJitterDir.xy*float2( 0.25, 0.25));

  float4 uv;
  uv.x = tex2D( CurColorSampler, vTexCoord_scr - g_vJitterDir.xy*float2( 0, 0) ).a;
  uv.y = tex2D( CurColorSampler, vTexCoord_scr - g_vJitterDir.xy*float2( 1, 1) ).a;
  uv.z = tex2D( CurColorSampler, vTexCoord_scr - g_vJitterDir.xy*float2( 0, 1) ).a;
  uv.w = tex2D( CurColorSampler, vTexCoord_scr - g_vJitterDir.xy*float2( 1, 0) ).a;

    /*****************/
   /* calc worldpos */
  /*****************/
  float4 depth;
  depth.x = DEPTH_SAMPLE_PREC( CurDepthSampler, vTexCoord_tile - g_vJitterDir.xy*float2( 0.0, 0.0) ).x;
  depth.y = DEPTH_SAMPLE_PREC( CurDepthSampler, vTexCoord_tile - g_vJitterDir.xy*float2( 1.0, 1.0) ).x;
  depth.z = DEPTH_SAMPLE_PREC( CurDepthSampler, vTexCoord_tile - g_vJitterDir.xy*float2( 0.0, 1.0) ).x;
  depth.w = DEPTH_SAMPLE_PREC( CurDepthSampler, vTexCoord_tile - g_vJitterDir.xy*float2( 1.0, 0.0) ).x;
  depth.w = (depth.z+depth.w)*0.5f;
  depth.z = (depth.x+depth.y)*0.5f;
      
  float3 world_pos  = g_vCurCamPos + depth.x * I.vTexCoord;
    
  float4 fWorldDistCur;
  fWorldDistCur.x = length( g_vCamMove + depth.x * I.vTexCoord );
  fWorldDistCur.y = length( g_vCamMove + depth.y * I.vTexCoord );
  fWorldDistCur.z = length( g_vCamMove + depth.z * I.vTexCoord );
  fWorldDistCur.w = length( g_vCamMove + depth.w * I.vTexCoord );
  
  /////////////////////////////////////////////////////////
  // FSAA and Edge-detection
  /////////////////////////////////////////////////////////
  float4 posOldScreen = mul(float4(world_pos,1), g_mOldViewProj);
  posOldScreen.xy = (posOldScreen.xy/float2(posOldScreen.w,-posOldScreen.w))*0.5+0.5;
  posOldScreen.xy += g_vViewPort.xy;  
  float4 vOldTex = tex2D(OldColorSampler, posOldScreen);
  
  float3 vecViewOld = g_vecViewTL + posOldScreen.x*g_vecViewDx + posOldScreen.y*g_vecViewDy;
  float depth_old = DEPTH_SAMPLE_PREC( OldDepthSampler, posOldScreen.xy ).x;
  float fWorldDistOld = Z_NEAR/(Z_FAR+(Z_NEAR-Z_FAR)*depth_old);
  fWorldDistOld = length(fWorldDistOld*vecViewOld);
  
  float fFilterable = any( abs(fWorldDistCur-fWorldDistOld.xxxx)<10.f );
  fFilterable *= any( frac(vOldTex.aaaa-uv.rgba + 7.f/256.f)<(15.f/256.f) );

  fFilterable *= posOldScreen.x>0.f;
  fFilterable *= posOldScreen.x<1.f;
  fFilterable *= posOldScreen.y>0.f;
  fFilterable *= posOldScreen.y<1.f;

    /*******************/
   /*    debug out    */
  /*******************/
float3 gray = float3(0.28, 0.49, 0.13);
//return float4( vCurTex.a, vOldTex.a, fFilterable, dot(vCurTex.rgb, gray) );

    /*****************/
   /*    do FSAA    */
  /*****************/
  vCurTex = fFilterable ? (vCurTex+vOldTex)/2 : vCurTex;//float4(1.f, dot(vCurTex.rgb, gray), dot(vOldTex.rgb, gray), 1.f);
  //vCurTex = (vCurTex+vOldTex)/2;

  return float4( vCurTex.rgb, fFilterable.x );
}