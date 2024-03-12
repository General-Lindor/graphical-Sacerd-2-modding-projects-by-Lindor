#ifndef SHADOW_XENON_SHADER
#define SHADOW_XENON_SHADER
float PCSS_Shadow ( sampler2D shadowMap, float3 coords )
{
  float2 poissonDisk[16] = {
    float2( -0.94201624,-0.39906216 ),
    float2(  0.94558609,-0.76890725 ),
    float2( -0.09418410,-0.92938870 ),
    float2(  0.34495938, 0.29387760 ),
    float2( -0.91588581, 0.45771432 ),
    float2( -0.81544232,-0.87912464 ),
    float2( -0.38277543, 0.27676845 ),
    float2(  0.97484398, 0.75648379 ),
    float2(  0.44323325,-0.97511554 ),
    float2(  0.53742981,-0.47373420 ),
    float2( -0.26496911,-0.41893023 ),
    float2(  0.79197514, 0.19090188 ),
    float2( -0.24188840, 0.99706507 ),
    float2( -0.81409955, 0.91437590 ),
    float2(  0.19984126, 0.78641367 ),
    float2(  0.14383161,-0.14100790 )
  };

  // STEP 1: blocker search
  float4 smDepth;
  smDepth.x  = DEPTH_SAMPLE_RAW( shadowMap, coords.xy + 0.010f * poissonDisk[0] ).x;
  smDepth.y  = DEPTH_SAMPLE_RAW( shadowMap, coords.xy + 0.010f * poissonDisk[1] ).x;
  smDepth.z  = DEPTH_SAMPLE_RAW( shadowMap, coords.xy + 0.010f * poissonDisk[2] ).x;
  smDepth.w  = DEPTH_SAMPLE_RAW( shadowMap, coords.xy + 0.010f * poissonDisk[3] ).x;
  float4 smFactor = saturate( (coords.z-smDepth)*200 );
  float numBlockers = dot( smFactor, 1 );
  float avgBlockerDepth = dot( smDepth*smFactor, 1.f/numBlockers );

  //There are no occluders so early out (this saves filtering)
  // 4 Samples are not enough and will result in bad artefacts
//  if( numBlockers/4 < 0.001 ) return 1; // There are no occluders
//  if( numBlockers/4 > 0.999 ) return 0; // Probably full occlusion

  // STEP 2: penumbra size
  float filterRadiusUV = lerp( 0.001f, 0.010f, saturate( (coords.z - avgBlockerDepth) * 7.5f ) );

  // STEP 3: filtering  
  smFactor = 0;
  for( int i = 0; i<4; ++i )
  {
    smDepth.x = DEPTH_SAMPLE_RAW( shadowMap, coords.xy + filterRadiusUV * poissonDisk[4*i+0] ).x;
    smDepth.y = DEPTH_SAMPLE_RAW( shadowMap, coords.xy + filterRadiusUV * poissonDisk[4*i+1] ).x;
    smDepth.z = DEPTH_SAMPLE_RAW( shadowMap, coords.xy + filterRadiusUV * poissonDisk[4*i+2] ).x;
    smDepth.w = DEPTH_SAMPLE_RAW( shadowMap, coords.xy + filterRadiusUV * poissonDisk[4*i+3] ).x;
    smFactor += saturate( (smDepth-coords.z)*200.f + 1 );
  }
  return dot( smFactor, 1/16.f );
}

float VSM_Shadow ( sampler2D shadowMap, float3 coords )
{
  float2 poissonDisk[16] = {
    float2( -0.94201624,-0.39906216 ),
    float2(  0.94558609,-0.76890725 ),
    float2( -0.09418410,-0.92938870 ),
    float2(  0.34495938, 0.29387760 ),
    float2( -0.91588581, 0.45771432 ),
    float2( -0.81544232,-0.87912464 ),
    float2( -0.38277543, 0.27676845 ),
    float2(  0.97484398, 0.75648379 ),
    float2(  0.44323325,-0.97511554 ),
    float2(  0.53742981,-0.47373420 ),
    float2( -0.26496911,-0.41893023 ),
    float2(  0.79197514, 0.19090188 ),
    float2( -0.24188840, 0.99706507 ),
    float2( -0.81409955, 0.91437590 ),
    float2(  0.19984126, 0.78641367 ),
    float2(  0.14383161,-0.14100790 )
  };
    
  float4 vVSM, vVSM2;

/*
  vVSM.x  = SHADOWMAP_SAMPLE( shadowMap, coords.xy ).x;
  vVSM2.x = SHADOWMAP_SAMPLE( shadowMap, coords.xy ).y;
  float fEpsilon = 0.01f;
  float variance = saturate( vVSM2 - (vVSM * vVSM) )+ fEpsilon;
  float m_d = saturate(coords.z - vVSM);
  float p_max = variance/(variance + m_d*m_d );
  return pow( p_max, 25 );
  
/*/  
  vVSM.x  = SHADOWMAP_SAMPLE( shadowMap, coords.xy+0.0005*poissonDisk[0] ).x;
  vVSM2.x = SHADOWMAP_SAMPLE( shadowMap, coords.xy+0.0005*poissonDisk[0] ).y;
  vVSM.y  = SHADOWMAP_SAMPLE( shadowMap, coords.xy+0.0005*poissonDisk[1] ).x;
  vVSM2.y = SHADOWMAP_SAMPLE( shadowMap, coords.xy+0.0005*poissonDisk[1] ).y;
  vVSM.z  = SHADOWMAP_SAMPLE( shadowMap, coords.xy+0.0005*poissonDisk[2] ).x;
  vVSM2.z = SHADOWMAP_SAMPLE( shadowMap, coords.xy+0.0005*poissonDisk[2] ).y;
  vVSM.w  = SHADOWMAP_SAMPLE( shadowMap, coords.xy+0.0005*poissonDisk[3] ).x;
  vVSM2.w = SHADOWMAP_SAMPLE( shadowMap, coords.xy+0.0005*poissonDisk[3] ).y;
  
  float fEpsilon = 0.002f;
  float4 variance = saturate( vVSM2 - (vVSM * vVSM) )+fEpsilon;
  float4 m_d = saturate(coords.zzzz - vVSM);
  float4 p_max = saturate(variance/(variance + m_d*m_d));
  
  // To combat light-bleeding, experiment with raising p_max to some power
  // (Try values from 0.1 to 100.0, if you like.)
  return  pow(dot(p_max,0.25), 25);
//*/  
}

float PCF_Shadow(sampler2D shadowMap, float3 smCoord )
{
  float4 smDepth;
  smDepth.x = DEPTH_SAMPLE_RAW( shadowMap, smCoord.xy + float2( -0.001f, -0.001f ) ).x;
  smDepth.y = DEPTH_SAMPLE_RAW( shadowMap, smCoord.xy + float2(  0.001f, -0.001f ) ).x;
  smDepth.z = DEPTH_SAMPLE_RAW( shadowMap, smCoord.xy + float2( -0.001f,  0.001f ) ).x;
  smDepth.w = DEPTH_SAMPLE_RAW( shadowMap, smCoord.xy + float2(  0.001f,  0.001f ) ).x;
  return dot( saturate( (smDepth-smCoord.z)*200+1 ), 0.25 );
}

float Pnt_Shadow(sampler2D shadowMap, float3 smCoord)
{
  float smDepth = DEPTH_SAMPLE_RAW(shadowMap, smCoord).x;
  return saturate( (smDepth-smCoord.z)*200+1 );
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// main function for rendering with shadows with shader 3.0
float calcShadow( sampler2D shadowMap, float4 smPos )
{
#ifdef XENON_IMPL
  return VSM_Shadow( shadowMap, smPos.xyz/smPos.w );
#else	
  return VSM_Shadow( shadowMap, smPos.xyz/smPos.w );
#endif
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// secondary function for rendering very simple shadows
float calcShadowSimple( sampler2D shadowMap, float4 smPos )
{
#ifdef XENON_IMPL
  return VSM_Shadow( shadowMap, smPos.xyz/smPos.w );
#else	
  return PCF_Shadow( shadowMap, smPos.xyz/smPos.w );
#endif
}

#if defined(CONSOLE_IMPL) 
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // main function for rendering point light shadows
  float calcPntFadeShadow(samplerCUBE depthCubeMap, float3 dir, float dist, float fade )
  {
  /*
	float vVSM = texCUBE( depthCubeMap, dir ).r;
	float vVSM2 = texCUBE( depthCubeMap, dir ).g;
  
    float fEpsilon = 0.001f;
	float variance = saturate( vVSM2 - (vVSM * vVSM) )+ fEpsilon;
	float m_d = saturate(dist - vVSM);
	float p_max = variance/(variance + m_d*m_d );
  
	// To combat light-bleeding, experiment with raising p_max to some power
	// (Try values from 0.1 to 100.0, if you like.)
	return pow( p_max, 50 );
  /*/
    // Soft VSM
    float2 vVSM = texCUBE( depthCubeMap, dir ).rg;

    // experiment with offset (+ 0.00f + (0.5f*variance)) to minimize pointshadow artefacts
    float variance = abs( ( vVSM.g ) - ( vVSM.r * vVSM.r ) );
    float val = fade * saturate( (dist - vVSM.r + 0.00f + (0.5f*variance) ) / (variance+0.01) );
    return 1.f - val;
  //*/    
  }
#else
  float calcPntFadeShadow(samplerCUBE depthCubeMap, s2half3 dir,float fade)
  {
  #ifndef SM1_1
    // get length of ray vector
    s2half sq_len = dot(dir, dir);
    // get encoded depth info
    s2half4 d = texCUBE(depthCubeMap, dir);
    // decode depth
    s2half sq_depth = dot(d.xyz, float3(1.0, 1.0 / 256.0, 1.0 / (256.0 * 256.0)));
    // is deeper / in Shadow?
    return (sq_len <= sq_depth) ? 1.0 : fade;
  #else
    return 1.0;
  #endif
  }
#endif
#endif //include guard