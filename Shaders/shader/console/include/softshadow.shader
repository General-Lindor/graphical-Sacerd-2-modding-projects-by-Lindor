#ifdef CONSOLE_IMPL
/*
half sampleSoftShadow( sampler2D DepthTex, half4 vLightSpacePos, half ObjDepth )
{  
  float4 Weights;
  float4 tex0, tex1;
  asm
  {
    setTexLOD vLightSpacePos.w
    tfetch2D tex0.xy__, vLightSpacePos, DepthTex, OffsetX =-0.5, OffsetY =-0.5, UseComputedLOD=false, UseRegisterLOD=true, MagFilter=point, MinFilter=point//, MipFilter=point
    tfetch2D tex0.__xy, vLightSpacePos, DepthTex, OffsetX = 0.5, OffsetY =-0.5, UseComputedLOD=false, UseRegisterLOD=true, MagFilter=point, MinFilter=point//, MipFilter=point
    tfetch2D tex1.xy__, vLightSpacePos, DepthTex, OffsetX =-0.5, OffsetY = 0.5, UseComputedLOD=false, UseRegisterLOD=true, MagFilter=point, MinFilter=point//, MipFilter=point
    tfetch2D tex1.__xy, vLightSpacePos, DepthTex, OffsetX = 0.5, OffsetY = 0.5, UseComputedLOD=false, UseRegisterLOD=true, MagFilter=point, MinFilter=point//, MipFilter=point
		
		getWeights2D Weights, vLightSpacePos.xy, DepthTex, MagFilter=linear, MinFilter=linear, UseComputedLOD=false, UseRegisterLOD=true
  };
	Weights = float4( (1-Weights.x)*(1-Weights.y), 
				               Weights.x *(1-Weights.y), 
				            (1-Weights.x)*   Weights.y , 
				               Weights.x *   Weights.y );
  
  float4 _min = float4(tex0.xz, tex1.xz);
  float4 _max = float4(tex0.yw, tex1.yw);
  
  float4 ret = saturate( (_max - ObjDepth.xxxx) / (_max - _min) );
  ret =  _max <  ObjDepth.xxxx-0.001 ? 0 : ret;
  ret =  _min >= ObjDepth.xxxx-0.001 ? 1 : ret;
  
    
  return dot( ret, Weights );
}
/*/
half sampleSoftShadow( sampler2D DepthTex, half4 vLightSpacePos, half ObjDepth )
{
	float4 vVSM   = tex2D( DepthTex, vLightSpacePos );
	float  fAvgZ  = vVSM.x; // Filtered z
	float  fAvgZ2 = vVSM.y; // Filtered z-squared
	{		
		if( ObjDepth <= fAvgZ )	return 1.0f;

		// Use variance shadow mapping to compute the maximum probability that the
		// pixel is in shadow
		float variance = ( fAvgZ2 ) - ( fAvgZ * fAvgZ );
		variance       = min( 1.0f, max( 0.0f, variance + 0.0025f ) );

		float d        = ObjDepth - fAvgZ;
		float p_max    = variance / ( variance + d*d );

    p_max*=p_max; p_max*=p_max; p_max*=p_max;
		return p_max;
	}
}
//*/

// returns 1 for light, 0 for shadow
float calcSoftShadow( sampler2D DepthTex, float4 vLightSpacePos, float zWorld )
{
	float fSoft = 0;
			
	// Compute projected xyz.
	vLightSpacePos.xyz = vLightSpacePos.xyz / vLightSpacePos.w;
	float ObjDepth = vLightSpacePos.z;
  
  fSoft = sampleSoftShadow( DepthTex, vLightSpacePos, ObjDepth );

  float shadow_min = clamp( (zWorld-1250.f)/250.f, 0, 1 );
	fSoft = clamp( fSoft.x, shadow_min, 1 );
	
	return fSoft;
}

////////////////////////////////////
//        sacred interface        //
////////////////////////////////////

half calcShadow(sampler2D shadowMap, half4 smPos, half4 shadow_data )
{
    return 1;
}
half calcShadowSimple(sampler2D shadowMap, half4 smPos, half4 shadow_data )
{
    return 1; 
}
half calcPntShadow(samplerCUBE depthCubeMap, s2half3 dir)
{
  // G16R16
  s2half len = length(dir);

  // Soft VSM
  half2 vVSM = texCUBE( depthCubeMap, dir ).rg;

  half variance = abs( ( vVSM.g ) - ( vVSM.r * vVSM.r ) )+0.1;
  half val = (len - vVSM.r)/variance;
  return saturate( 1.f - val );
}

#endif
