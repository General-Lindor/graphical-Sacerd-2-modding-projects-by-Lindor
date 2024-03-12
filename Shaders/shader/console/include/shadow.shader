#ifdef SM2_0
  //No zramp -> fogging in SM20!
  //#define NO_ZRAMP
#endif

#ifdef CONSOLE_IMPL
  #include "shadow_xenon.shader"
#else
  #ifdef NO_SHADOWS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // main function for rendering with shadows, when shadows are diabled!!!
    float calcShadow(sampler2D shadowMap, sampler3D jitterTex, float4 smPos, float2 scrPos, float penSize, float texScale, int n)
    {
	    return 1.0;
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // secondary function for rendering simple shadows
    float calcShadowSimple(sampler2D shadowMap, sampler3D jitterTex, float4 smPos, float2 scrPos, float penSize, float texScale)
    {
	    return 1.0;
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // main function for rendering point light shadows
    float calcPntShadow(samplerCUBE depthCubeMap, s2half3 dir)
    {
	    return 1.0;
    }
  #else //NO_SHADOWS
    float readShadowmap(sampler2D shadowMap, float4 smCoord)
    {
      #ifdef HW_SM
        return  tex2Dlod(shadowMap, smCoord);
      #else
        float smDepth = tex2Dlod(shadowMap, smCoord).x;
        return (smDepth > smCoord.z) ? 1.0 : 0.0;
      #endif
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // main function for rendering with shadows with shader 3.0
    float calcShadow(sampler2D shadowMap, sampler3D jitterTex, float4 smPos, float2 scrPos, float penSize, float texScale, int n)
    {
	      float res;
    #if defined(SM3_0)
        float4 jitterOffset, smCoord;
        
        // accumulate via adding
        
	  // make a lot of lookups around our texel to do blur filtering
	  #ifdef USE_OLD_SHADOW
          float inhPenSize;
          res = 0.0;
          smCoord = smPos;
          inhPenSize = penSize * smPos.w;
		  int i;
		  // make a lot of lookups around our texel to do blur filtering
		  for(i = 0; i < n; i++)
		  {
			  jitterOffset = (2.0 * tex3D(jitterTex, float3(texScale * scrPos.x, texScale * scrPos.y, 1.0 / i))) - 1.0;
			  // add
			  smCoord.xy = smPos.xy + inhPenSize * jitterOffset.xy;
			  res += tex2Dlod(shadowMap, float4(smCoord.xyz / smCoord.w, 0.0));
			  smCoord.xy = smPos.xy + inhPenSize * jitterOffset.zw;
			  res += tex2Dlod(shadowMap, float4(smCoord.xyz / smCoord.w, 0.0));
		  }
		  // pcf!
		  res /= (2 * n);
	  #else
		  float4 jitterOffset2;
          res = 0.0;
          smPos.xyz /= smPos.w;
          smCoord = smPos;
		  jitterOffset = (2.0 * tex3D(jitterTex, float3(texScale * scrPos.x, texScale * scrPos.y, 0.5))) - 1.0;
		  jitterOffset *=penSize;
		  // add
		  smCoord.xy = smPos.xy + jitterOffset.xy;
		  res += readShadowmap(shadowMap, smCoord);
		  smCoord.xy = smPos.xy + jitterOffset.zw;
		  res += readShadowmap(shadowMap, smCoord);
		  smCoord.xy = smPos.xy + jitterOffset.yz;
		  res += readShadowmap(shadowMap, smCoord);
		  smCoord.xy = smPos.xy + jitterOffset.xw;
		  res += readShadowmap(shadowMap, smCoord);
		  smCoord.xy = smPos.xy + jitterOffset.yy;
		  res += readShadowmap(shadowMap, smCoord);

		  jitterOffset = (2.0 * tex3D(jitterTex, float3(texScale * scrPos.x, texScale * scrPos.y,0.25))) - 1.0;
		  jitterOffset *=penSize;
		  // add
		  smCoord.xy = smPos.xy + jitterOffset.xy;
		  res += readShadowmap(shadowMap, smCoord);
		  smCoord.xy = smPos.xy + jitterOffset.zw;
		  res += readShadowmap(shadowMap, smCoord);
		  smCoord.xy = smPos.xy + jitterOffset.yz;
		  res += readShadowmap(shadowMap, smCoord);
		  smCoord.xy = smPos.xy + jitterOffset.xw;
		  res += readShadowmap(shadowMap, smCoord);
		  smCoord.xy = smPos.xy + jitterOffset.yy;
		  res += readShadowmap(shadowMap, smCoord);
		  // pcf!
		  res /= (10.f);
      #endif
        // this is it!
        return res;
    #elif defined(SM2_0)
	      int i;
	      float4 jitterOffset;
	      float4 smCoord, smDepth;
      	
	      // accumulate via adding
	      res = 0.0;
	      smCoord = smPos;

      #ifdef HW_SM
	      res = tex2Dproj(shadowMap, smCoord);
      #else
	      smDepth = tex2Dproj(shadowMap, smCoord);
	      res = (smDepth.x > smPos.z / smPos.w) ? 1.0 : 0.0;
      #endif

    #else
        res = 1.0;
    #endif
	      // this is it!
	      return res;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // secondary function for rendering very simple shadows
    float calcShadowSimple(sampler2D shadowMap, sampler3D jitterTex, float4 smPos, float2 scrPos, float penSize, float texScale)
    {
      float res;

    #if defined(SM3_0)

      #ifdef HW_SM
        // add
        res = tex2Dlod(shadowMap, float4(smPos.xyz / smPos.w, 0.0));
      #else //HW_SM
        res = 1.0;
      #endif //HW_SM

    #elif defined(SM2_0)
      #ifdef HW_SM
        // just one lookup
        res = tex2Dproj(shadowMap, smPos);
      #else //HW_SM
        float4 smDepth = tex2Dproj(shadowMap, smPos);
        res = (smDepth.x > smPos.z / smPos.w) ? 1.0 : 0.0;
      #endif //HW_SM
    #else
      res = 1.0;
    #endif
      // this is it!
      return res;

    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // main function for rendering point light shadows
    float calcPntShadow(samplerCUBE depthCubeMap, s2half3 dir)
    {
    #ifndef SM1_1
      // get length of ray vector
      s2half sq_len = dot(dir, dir);
      // get encoded depth info
      s2half4 d = texCUBE(depthCubeMap, normalize(dir));
      // decode depth
      s2half sq_depth = dot(d.xyz, float3(1.0, 1.0 / 256.0, 1.0 / (256.0 * 256.0)));
      // is deeper / in Shadow?
      return (sq_len <= sq_depth) ? 1.0 : 0.0;
    #else
      return 1.0;
    #endif
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // main function for rendering point light shadows
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
  #endif //NO_SHADOWS
#endif