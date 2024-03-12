// terrain diffuse bump for dir-light & shadow-map

//#OptDef:SPASS_G
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
//#OptDef:SPASS_SHADOWMAP
//#OptDef:SPASS_LIGHTNING
//#OptDef:NO_SHADOWS
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:LAYER_BIT2
//#OptDef:LAYER_BIT3
//#OptDef:TERRAIN_RELAXED
//#OptDef:S2_FOG
//#OptDef:NORMALFORMAT_565
//#OptDef:ENABLE_VERTEXLIGHTING

#include "extractvalues.shader"
struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float2 texcoord   : TEXCOORD0;
	float2 data       : TEXCOORD1;
};


/////////////////////////////////////
// Shader Configuration
/////////////////////////////////////
#ifdef SM1_1
  #define PS_DUMMY
#else
  #define PS_GENERAL
#endif





/////////////////////////////////////
// Ambient Diffuse Setup
/////////////////////////////////////









/////////////////////////////////////
// Pixel Shader Setup
/////////////////////////////////////
#ifdef PS_DUMMY
struct fragout
{
  float4 col0  : COLOR0;
};
#endif

/////////////////////////////////////
// Cube Shadowmap lookup routines
/////////////////////////////////////
  #include "shadow.shader"
  #include "lighting.shader"

  struct sLayerData
  {
	  s2half3 col_amb;
	  s2half3 col_diff;
	  s2half3 col_spec;
	  s2half3 vec_normal;
  };
  struct sMaterial
  {
    sLayerData layer0;
    sLayerData layer1;
    sLayerData layer2;
    sLayerData layer3;
  };
  void layer_init(out sLayerData dst,
                  sampler2D texture0,
                  sampler2D texture1,
                  float2    texcoord,
                  s2half3   view_TS,
                  s2half3   light_TS,
                  s2half3   half_vec_TS)
  {
    s2half4 t0_diff = tex2D( texture0, texcoord.xy );
    s2half4 nrm     = decode_normal(tex2D( texture1, texcoord.xy ));

#ifdef ALT_LIGHTING_MODE
    float theta     = pow( saturate(dot(light_TS, nrm.xyz)), 2.0 );
    dst.col_diff    = t0_diff * theta;
    dst.col_amb     = t0_diff * (0.8 + 0.6 * theta);
#else
    dst.col_amb     = t0_diff * (saturate(dot(view_TS, nrm.xyz)) + 0.5);
	  dst.col_diff    = t0_diff * saturate(dot(light_TS, nrm.xyz));
#endif
	  dst.col_spec    = nrm.a * pow(saturate(dot(half_vec_TS, nrm.xyz)), 20);
	  dst.vec_normal  = nrm.xyz;
  }
  float3 layer_get_amb(sLayerData src,float4 light_col_amb)
  {
    return light_col_amb * src.col_amb;
  }
  float3 layer_get_dif(sLayerData src,float4 light_col_dif,float shadow)
  {
    return light_col_dif * shadow * (src.col_diff + src.col_spec);
  }
                      

#ifdef SPASS_G
  struct pixdata
  {
    float4 hposition  : POSITION;   
    float4 depthUV    : TEXCOORD0;  
  };
  #define VS_OUT_hposition
  #define VS_OUT_depthUV
  fragout1 mainPS(pixdata I)
  {
	  fragout1 PSO;
	  PSO.col = float4(I.depthUV.w,0,0,1);
	  return PSO;
  }
#elif SPASS_SHADOWMAP
  struct pixdata
  {
    float4 hpos_light              : POSITION; 
  };
  #define VS_OUT_hpos_light
  fragout1 mainPS(pixdata I)
  {
	  fragout1 PSO;
    PSO.col = float4( 0,0,0,1 );
	  return PSO;
  }
#elif SPASS_AMBDIF
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_view_TS
  #define VS_OUT_light_TS
  #define VS_OUT_screenCoordInTexSpace
  #define VS_OUT_depthFog
  #ifdef TERRAIN_RELAXED
    #define VS_OUT_slope
  #endif
  #ifdef ENABLE_VERTEXLIGHTING
    #define VS_OUT_vertexLightData
  #endif
  struct pixdata
  {
	  float4 hposition              : POSITION;
	  float4 texcoord               : TEXCOORD0;
	  float3 view_TS                : TEXCOORD1;
	  float3 light_TS               : TEXCOORD2;
	  float4 screenCoordInTexSpace  : TEXCOORD3;
    float2 depthFog             : TEXCOORD4;
    #ifdef TERRAIN_RELAXED
      float  slope                : TEXCOORD5;
    #endif
    #ifdef VS_OUT_vertexLightData
      float4 vlColor           : TEXCOORD6;
      float4 vlNormal          : TEXCOORD7;
    #endif
  };
  
                  
  
  fragout_2 mainPS( pixdata I,
                    PS_PARAM_BLOCK)
  {
	  fragout_2 PSO;
	  s2half3 nrm;
  #ifdef TERRAIN_RELAXED
    s2half4 alpha_mask = tex2D( texture10, I.texcoord.xy );
    s2half4 relax_limit = tex2D( texture11, I.texcoord.xy );
  #else
    s2half4 alpha_mask = tex2D( texture8, I.texcoord.xy );
  #endif



  #ifdef VS_OUT_light_TS
	  s2half3 light_TS   = normalize( I.light_TS );
  #endif

  #ifdef VS_OUT_view_TS
	  s2half3 view_TS = normalize( I.view_TS  );
  #endif
  #ifdef VS_OUT_light_TS
  #ifdef VS_OUT_view_TS
    s2half3 half_vec_TS = normalize( light_TS + view_TS );
  #endif
  #endif

  #ifndef NO_SHADOWS
    // get shadow term from shadow texture (used by ambient pass)
    float shadow = tex2Dproj( shadow_texture, I.screenCoordInTexSpace ).z;
  #else
    float shadow = 1.0;
  #endif

	  sMaterial mat;
	  layer_init(mat.layer0,texture0,texture1,I.texcoord.xy,view_TS,light_TS,half_vec_TS);
   #ifdef TERRAIN_RELAXED
    if(I.slope <= relax_limit.w)
	    layer_init(mat.layer0,texture8,texture9,I.texcoord.xy,view_TS,light_TS,half_vec_TS);
   #endif
	  layer_init(mat.layer1,texture2,texture3,I.texcoord.xy,view_TS,light_TS,half_vec_TS);
	  layer_init(mat.layer2,texture4,texture5,I.texcoord.xy,view_TS,light_TS,half_vec_TS);
	  layer_init(mat.layer3,texture6,texture7,I.texcoord.xy,view_TS,light_TS,half_vec_TS);


    float3 av_col = float3(0.0, 0.0, 0.0);
    float3 av_nrm = float3(0.0, 0.0, 0.0);

	  // calc pre-factors
	  s2half t0_f = alpha_mask.r;
	  s2half t1_f = alpha_mask.g;
	  s2half t2_f = alpha_mask.b;
	  s2half t3_f = alpha_mask.a;

	  // add all layers
    float3 finalCol = float3(0.0, 0.0, 0.0);
  #if LAYER_BIT0
    av_col   += t0_f * mat.layer0.col_amb;
    av_nrm   += t0_f * mat.layer0.vec_normal;
  #endif
  #if LAYER_BIT1
    av_col   += t1_f * mat.layer1.col_amb;
    av_nrm   += t1_f * mat.layer1.vec_normal;
  #endif
  #if LAYER_BIT2
    av_col   += t2_f * mat.layer2.col_amb;
    av_nrm   += t2_f * mat.layer2.vec_normal;
  #endif
  #if LAYER_BIT3
    av_col   += t3_f * mat.layer3.col_amb;
    av_nrm   += t3_f * mat.layer3.vec_normal;
  #endif

  #ifdef VS_OUT_vertexLightData
    light_col_amb += light_calc_heroLight(I.vlColor);
    light_col_amb += light_calc_vertexlighting(normalize(av_nrm),I.vlColor,normalize(I.vlNormal.xyz));
  #endif

  float3 t0_final_amb  = layer_get_amb(mat.layer0,light_col_amb);
  float3 t0_final_diff = layer_get_dif(mat.layer0,light_col_diff,shadow);
  float3 t1_final_amb  = layer_get_amb(mat.layer1,light_col_amb);
  float3 t1_final_diff = layer_get_dif(mat.layer1,light_col_diff,shadow);
  float3 t2_final_amb  = layer_get_amb(mat.layer2,light_col_amb);
  float3 t2_final_diff = layer_get_dif(mat.layer2,light_col_diff,shadow);
  float3 t3_final_amb  = layer_get_amb(mat.layer3,light_col_amb);
  float3 t3_final_diff = layer_get_dif(mat.layer3,light_col_diff,shadow);

  #if LAYER_BIT0
	  finalCol += t0_f * (t0_final_diff + t0_final_amb);
  #endif
  #if LAYER_BIT1
	  finalCol += t1_f * (t1_final_diff + t1_final_amb);
  #endif
  #if LAYER_BIT2
	  finalCol += t2_f * (t2_final_diff + t2_final_amb);
  #endif
  #if LAYER_BIT3
	  finalCol += t3_f * (t3_final_diff + t3_final_amb);
  #endif


	  PSO.col0 = float4(finalCol, 1.0);
	  PSO.col1 = float4(0.0, 0.0, 0.0, 0.0);


  #ifdef S2_FOG
    // calc fog
    fogDiffuse( PSO.col0.xyz, fog_texture, I.depthFog, fog_color );
  #endif

#ifdef SM2_0
	  PSO.col0 = float4(0,0,0,1);
	  PSO.col1 = float4(0,0,0,0);
#endif
    return PSO;
	}
#elif SPASS_PNT
  // VS setup
  // Outputs
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_view_TS
  #define VS_OUT_light_TS
  #define VS_OUT_depthFog
  #define VS_OUT_incident_light_WS
  #ifdef TERRAIN_RELAXED
    #define VS_OUT_slope
  #endif

  struct pixdata
  {
    float4 hposition           : POSITION;
    float4 texcoord            : TEXCOORD0;
    float3 view_TS             : TEXCOORD1;
    float3 light_TS            : TEXCOORD2;
    #ifdef TERRAIN_RELAXED
      float  slope               : TEXCOORD3;
    #endif
    float2 depthFog            : TEXCOORD4;
    float3 incident_light_WS   : TEXCOORD5;
  };
  fragout_2 mainPS(pixdata I,
                   PS_PARAM_BLOCK)
  {
	  fragout_2 PSO;
	  
	  s2half3 nrm;
  #ifdef TERRAIN_RELAXED
    s2half4 alpha_mask = tex2D( texture10, I.texcoord.xy );
    s2half4 relax_limit = tex2D( texture11, I.texcoord.xy );
  #else
    s2half4 alpha_mask = tex2D( texture8, I.texcoord.xy );
  #endif


	  s2half3 light_TS   = normalize( I.light_TS );
	  s2half3 view_TS = normalize( I.view_TS  );
    s2half3 half_vec_TS = normalize( light_TS + view_TS );

	  // calc squared distance from light to point
	  float sq_dist_to_light = dot( I.light_TS, I.light_TS );
	  // get fraction of light distance to the max light radius
	  float temp_dist = saturate( sq_dist_to_light * light_data.z * light_data.z );
    // calculate fall off
	  float intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
    //float intensity = cos( 1.5708 * temp_dist );
	  // multiply it by intensity of light source
	  intensity *= light_data.y;
  #ifdef S2_FOG
    // calc fog
    fogPnt( intensity, fog_texture, I.depthFog );
  #endif
	  sMaterial mat;
	  layer_init(mat.layer0,texture0,texture1,I.texcoord.xy,view_TS,light_TS,half_vec_TS);
  #ifdef TERRAIN_RELAXED
	  if(I.slope <= relax_limit.w)
  	  layer_init(mat.layer0,texture8,texture9,I.texcoord.xy,view_TS,light_TS,half_vec_TS);
  #endif
	  layer_init(mat.layer1,texture2,texture3,I.texcoord.xy,view_TS,light_TS,half_vec_TS);
	  layer_init(mat.layer2,texture4,texture5,I.texcoord.xy,view_TS,light_TS,half_vec_TS);
	  layer_init(mat.layer3,texture6,texture7,I.texcoord.xy,view_TS,light_TS,half_vec_TS);
	  // calc pre-factors
	  s2half t0_f = alpha_mask.r;
	  s2half t1_f = alpha_mask.g;
	  s2half t2_f = alpha_mask.b;
	  s2half t3_f = alpha_mask.a;

	  // add all layers
    float3 finalCol = float3(0.0, 0.0, 0.0);
  #if LAYER_BIT0
    finalCol += t0_f * (mat.layer0.col_diff + mat.layer0.col_spec);
  #endif
  #if LAYER_BIT1
	  finalCol += t1_f * (mat.layer1.col_diff + mat.layer1.col_spec);
  #endif
  #if LAYER_BIT2
	  finalCol += t2_f * (mat.layer2.col_diff + mat.layer2.col_spec);
  #endif
  #if LAYER_BIT3
	  finalCol += t3_f * (mat.layer3.col_diff + mat.layer3.col_spec);
  #endif

 	  float shadow = calcPntFadeShadow(textureCube, light_data.z * I.incident_light_WS.xzy,light_data.w);
    finalCol *= shadow * intensity * light_col_diff.rgb;

	  // out
	  PSO.col0 = float4(finalCol, 1.0);
	  PSO.col1 = float4(0.0, 0.0, 0.0, 0.0);
	  
#ifdef SM2_0
	  PSO.col0 = float4(0,0,0,1);
	  PSO.col1 = float4(0,0,0,0);
#endif
    return PSO;
  }
 
#elif SPASS_LIGHTNING
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_view_TS
  #define VS_OUT_light_TS
  #define VS_OUT_view_WS
  #define VS_OUT_screenCoordInTexSpace
  #define VS_OUT_matrix_TS_to_WS
  #define VS_OUT_depthFog

  struct pixdata
  {
	  float4 hposition              : POSITION;
	  float4 texcoord               : TEXCOORD0;
	  float3 view_TS                : TEXCOORD1;
    float3 light_TS               : TEXCOORD2;
    float3 view_WS                : TEXCOORD3;
    float4 screenCoordInTexSpace  : TEXCOORD4;
    float2 depthFog               : TEXCOORD5;
    float3 matrix_TS_to_WS[2]     : TEXCOORD6;
  };
  fragout_2 mainPS( pixdata I,
                    PS_PARAM_BLOCK)
  {
	  fragout_2 PSO;
	  s2half3 nrm;

    s2half4 t0_diff     = tex2D( texture0, I.texcoord.xy );
    s2half4 t0_nrm      = decode_normal(tex2D( texture1, I.texcoord.xy ));
    s2half4 trans_mask  = tex2Dproj( texture2, I.screenCoordInTexSpace );
    s2half3 view_WS     = normalize( I.view_WS );
  
	  s2half3 normal = t0_nrm;
    float3x3 TS_to_WS = { I.matrix_TS_to_WS[0], I.matrix_TS_to_WS[1], cross( I.matrix_TS_to_WS[0], I.matrix_TS_to_WS[1] ) };
    s2half3 normal_WS = mul( normal, TS_to_WS );
	  // calc to-face-lightning
	  float is2Lightning = step( 0.2, dot( normal, I.light_TS ) );
  	
	  // wet
	  float4 wet_color = saturate( normal_WS.z ) * light_col_diff.w * light_col_diff * texCUBE( textureCube, reflect( -view_WS, normal_WS ) );
  	
    // lightning
	  float4 lit_color_0 = float4( is2Lightning * light_col_amb.w * float3( 1.0, 1.0, 1.0 ), t0_diff.a );
	  float4 lit_color_1 = float4( is2Lightning * light_col_amb.w * light_col_amb.xyz, 0.0 );
  	
	  // apply shading only, where there is no transparency!!
	  PSO.col0 = ( 1.0 - trans_mask.r ) * ( wet_color + lit_color_0 );
	  PSO.col1 = ( 1.0 - trans_mask.r ) * ( lit_color_1 );

    #ifdef S2_FOG
      // calc fog
      fogGlow( PSO.col0.xyz, fog_texture, I.depthFog );
      fogGlow( PSO.col1.xyz, fog_texture, I.depthFog );
    #endif

    return PSO;
  }
#endif
#ifdef PS_DUMMY
fragout mainPS( pixdata I )
{
  fragout PSO;
  PSO.col0 = float4( 0.0, 0.0, 1.0, 0.0 );
  return PSO;
}
#endif



struct small_appdata
{
	float	height:position;
	float4	uvn:color;
};
//////////////////////////////////////////////////
// VERTEX SHADER
//////////////////////////////////////////////////
pixdata mainVS(  small_appdata sI,
               VS_PARAM_BLOCK)
{
	appdata I;
	// Do all the decompression here, compiler will optimize and remove unused calculations

	// Please do not change this code, as it has been carefully reordered to trick the optimizer
	// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
	float4 scaler = sI.uvn.xyxy * float4(weather_pos.zw * 42.5, 42.5, 42.5);	// Rescale from 0/255..6/255 to 0..1
	I.position = float3(scaler.xy + weather_pos.xy, sI.height);
	I.normal.xy = sI.uvn.zw*2-1;
	I.normal.z = sqrt(1-dot(I.normal.xy,I.normal.xy));
	// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	pixdata VSO;
	float4 pos4   = float4( I.position, 1.0 );
#ifdef VS_OUT_vertexLightData
  computeVertexLightingColorNormal( VSO.vlColor, VSO.vlNormal,pos4);
#endif


	
	I.data.xy = I.texcoord.xy = scaler.zw;	
	I.binormal = normalize(cross(float3(I.normal.z, 0, -I.normal.x), I.normal));
	I.tangent  = normalize(cross(I.normal, float3(0, I.normal.z, -I.normal.y)));



#ifdef VS_OUT_hposition
#ifdef SPASS_SHADOWMAP
  VSO.hposition = mul( float4( I.position, 1.0 ), lightMatrix );
#else
  // Pass vertex position in clip space to rasterizer
  VSO.hposition = mul( pos4, worldViewProjMatrix );

  float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
                    pos4.y*worldViewMatrix[1][2] + 
                    pos4.z*worldViewMatrix[2][2] + 
                    worldViewMatrix[3][2];

#endif
#endif

#ifdef VS_OUT_hpos_light
  VSO.hpos_light = mul( pos4, lightMatrix );
#endif


#ifdef VS_OUT_depthUV
  VSO.depthUV = float4(0,0,0,-camSpaceZ*zfrustum_data.w);
#endif

#ifdef VS_OUT_depthFog
  VSO.depthFog = getFogTCs( VSO.hposition.w, fog_data );
#endif

#ifdef VS_OUT_screenCoordInTexSpace
	// calculate vertex position in screen space and transform to texture space in PS
  VSO.screenCoordInTexSpace = calcScreenToTexCoord(VSO.hposition);
#endif

#ifdef VS_OUT_incident_light_WS
  // get vertex -> light vector in World Space
  float3 pos_WS = mul( pos4, worldMatrix );
  // store light vector in object space for Cubemap lookup in PS
  VSO.incident_light_WS = pos_WS - light_pos.xyz;
#endif

  // build object-to-tangent space matrix
  // tangent and binormal are flipped because granny stores them in this format
	float3x3 invTangentSpaceMatrix;
	invTangentSpaceMatrix[0] = - I.tangent;
	invTangentSpaceMatrix[1] = - I.binormal;
	invTangentSpaceMatrix[2] =   I.normal;
#ifdef VS_OUT_matrix_TS_to_WS
  float3x3 mattmp = mul( invTangentSpaceMatrix, worldMatrix );
  VSO.matrix_TS_to_WS[0] = mattmp[0];
  VSO.matrix_TS_to_WS[1] = mattmp[1];
  //VSO.matrix_TS_to_WS[2] = mattmp[2];
#endif
  invTangentSpaceMatrix = transpose( invTangentSpaceMatrix );

#ifdef VS_OUT_light_TS
	// light in World Space -> Object Space
  // TODO: CONSTANT, DO OUTSIDE VS!!!!!
	float3 light_OS = mul( light_pos, invWorldMatrix ).xyz;
#ifdef SPASS_PNT
  VSO.light_TS = mul( light_OS - I.position, invTangentSpaceMatrix );
#else
  // Object Space -> Tangent Space
  VSO.light_TS = mul( light_OS, invTangentSpaceMatrix );
#endif
#endif

#ifdef VS_OUT_vertexLightData
  VSO.vlNormal = float4(mul( VSO.vlNormal, invTangentSpaceMatrix ),0);
#endif


#ifdef VS_OUT_view_WS
#ifdef MINIMAPMODE
  VSO.view_WS = camera_pos.xyz;
#else
  float3 pos_WS = mul( pos4, worldMatrix );
  VSO.view_WS = camera_pos.xyz - pos_WS;
#endif
#endif

#ifdef VS_OUT_view_TS
  // camera in World Space -> Object Space
  // TODO: CONSTANT, DO OUTSIDE VS!!!!!
  float3 camera_OS = mul( camera_pos, invWorldMatrix ).xyz;
  // view vector in Object Space -> Tangent Space
#ifdef MINIMAPMODE
  VSO.view_TS = mul( camera_OS, invTangentSpaceMatrix );
#else
  VSO.view_TS = mul( camera_OS - I.position, invTangentSpaceMatrix );
#endif
#endif

#ifdef VS_OUT_texcoord
  // the textures of all visible patches are baked into one large texture per frame
  // the param values offset and scale the patch's texture coordinates into this large baked texture
  // we pass the transformed TCs in xy and the untransformed TCs in zw
	VSO.texcoord = I.texcoord.xyxy;
#endif

#ifdef VS_OUT_slope
  VSO.slope = saturate( dot( I.normal, float3( 0,0,1 ) ) );
#endif

	return VSO;
}


