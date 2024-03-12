// terrain diffuse bump for dir-light & sc_shadow_intensity-map

//#OptDef:SPASS_G
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
//#OptDef:SPASS_SHADOWMAP
//#OptDef:SPASS_LIGHTNING
//#OptDef:NO_SHADOWS
//#OptDef:LAYER_BIT0
//#OptDef:S2_FOG
//#OptDef:HW_SM
//#OptDef:LAYER_BIT0
//#OptDef:SMOOTH_SHADOWS
//#OptDef:ENABLE_VERTEXLIGHTING

#include "extractvalues.shader"
#include "lighting.shader" 

struct appdata { 
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float2 texcoord   : TEXCOORD0;
	float2 data       : TEXCOORD1;
};

struct small_appdata
{
	float	height:position;
	float4	uvn:color;
};



/////////////////////////////////////
// Cube Shadowmap lookup routines
/////////////////////////////////////
#include "shadow.shader"



  void mat_decode_textures(inout sMaterialData mat,
                           sampler2D           texture0,
                           sampler2D           texture1,
                           float2              uvset)

  {
    mat.color_diffuse     = tex2D( texture0, uvset );
#ifdef NORMALFORMAT_PLAIN
    mat.vec_normal_ts     = float3( 0,0,1 );
    mat.color_spec        = float3( 0,0,0 );
#else
    float4  tmp_norm      = tex2D( texture1, uvset );
    s2half2 enc_normal    = (2.0 * tmp_norm.xy) - float2( 1,1 );
    mat.color_spec        = float3(tmp_norm.z,tmp_norm.z,tmp_norm.z);
    // decode the normal from the normal map (move range from [0;1] to [-0.5;0.5] and normalize)
	  mat.vec_normal_ts = float3( enc_normal, sqrt( 1.0 - dot( enc_normal, enc_normal ) ) );
    mat.vec_normal_ts = normalize( mat.vec_normal_ts );
#endif
#ifdef LAYER_BIT0
    mat.color_diffuse.a   = 0;
    mat.vec_normal_ts     = float3(0,0,1);
    mat.color_spec        = float3(0,0,0);
#endif
  }
  void add_caustics(inout sLightingColors colors,
                    in    sLightingData ld,
                    sampler2D           tex12,
                    sampler2D           tex13,
                    float4              screenCoordInTexSpace,
                    float4              caustic_tcs)
  {
      // calculate caustics
    float depth = tex2Dproj( tex12, screenCoordInTexSpace ).g;

    float3 caustic  = { 1,1,1 };
    float3 caustic2 = { 1,1,1 };
    if( depth > 0.0 )
    {
      colors.color_diffuse_out *= 1.0 - depth;
      //caustic *= step( tex2D( texture13, I.texcoord.zw ).rgb, float3( 0.8, 0.8, 0.8 ) );// * depth;
      caustic  *= tex2D( tex13, caustic_tcs.xy ).rgb * depth;
      caustic2 *= tex2D( tex13, caustic_tcs.wz ).rgb * depth;
      //new_color += new_color * caustic * caustic2 + caustic * caustic2;
      colors.color_diffuse_out.rgb += saturate( ld.color_diffuse.rgb * pow( caustic * caustic2 * 1.0, 2.0 ) * 30.0 );
    }
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
#endif

#ifdef SPASS_SHADOWMAP
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
#endif


                              

#ifdef SPASS_AMBDIF
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_view_TS
  #define VS_OUT_light_TS
  #define VS_OUT_screenCoordInTexSpace
  #define VS_OUT_depthFog
  #ifdef USE_CAUSTICS
    #define VS_OUT_caustic_tcs
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
    float2 depthFog               : TEXCOORD4;  
    #ifdef VS_OUT_vertexLightData
      float4 vlColor           : TEXCOORD5;
      float4 vlNormal          : TEXCOORD6;
    #endif
    #ifdef VS_OUT_caustic_tcs
      float4 caustic_tcs          : TEXCOORD7;
    #endif
  };

  fragout_2 mainPS(pixdata I,
                  PS_PARAM_BLOCK)
  {
	  fragout_2 PSO;
	  
	  sMaterialData mat;
	  sLightingData ld;
	  mat_init(mat);
	  light_init(ld,light_col_amb,light_col_diff,fog_color);

	  mat_decode_textures(mat,texture0,texture1,I.texcoord.xy);
	  light_setup_shadow_fog_deferred(ld,shadow_texture,I.screenCoordInTexSpace,fog_texture,I.depthFog);
    light_setup_lightvec(ld,mat,I.view_TS,I.light_TS);
  #ifdef VS_OUT_vertexLightData
    light_setup_vertexlighting(ld,mat,I.vlColor,I.vlNormal);
  #endif
    sLightingColors colors;
    light_compute(colors,ld,mat);
  #ifdef VS_OUT_caustic_tcs
    add_caustics(colors,tex2Dproj( texture12,texture13,I.screenCoordInTexSpace);
  #endif
    light_add_glow(colors);
    PSO.col0 =  light_lerp_fog(ld,colors.color_final_color);
    PSO.col1 =  float4(0,0,0,0);
//      PSO.col0 =  colors.color_final_color;
  

	  return PSO;
  }
#endif




#ifdef SPASS_PNT
  struct pixdata
  {
    float4 hposition           : POSITION;   
    float4 texcoord            : TEXCOORD0;  
    float3 view_TS             : TEXCOORD1;  
    float3 pntlight_TS         : TEXCOORD2;  
    float2 depthFog            : TEXCOORD3;  
    float3 incident_light_WS   : TEXCOORD4;  
  };
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_view_TS
  #define VS_OUT_lpntlight_TS
  #define VS_OUT_depthFog
  #define VS_OUT_incident_light_WS
  
  fragout_2 mainPS(pixdata I,
                  PS_PARAM_BLOCK)
  {
	  fragout_2 PSO;

	  sMaterialData mat;
	  sLightingData ld;
	  mat_init(mat);
	  light_init(ld,float4(0,0,0,0),light_col_diff,float4(0,0,0,0));

    light_set_falloff(ld,I.pntlight_TS,light_data);
    clip(ld.sc_light_intensity-0.01); 

    light_setup_shadow_fog_pnt(ld,textureCube,light_data,I.incident_light_WS.xzy,fog_texture,I.depthFog);
    clip(ld.sc_shadow_intensity-0.01);

	  mat_decode_textures(mat,texture0,texture1,I.texcoord.xy);
    light_setup_lightvec(ld,mat,I.view_TS,I.pntlight_TS);
    sLightingColors colors;
    light_compute(colors,ld,mat);

    PSO.col0 =  light_scale_fog(ld,colors.color_final_color);
//    PSO.col1 =  light_scale_fog(ld,colors.color_final_glow);
    PSO.col1 =  float4(0,0,0,0);
	  return PSO; 
  }
#endif //PS_SPASS_PNT

#ifdef SPASS_LIGHTNING
  struct pixdata
  {
    float4 hposition              : POSITION;
    float4 texcoord               : TEXCOORD0;
    float3 view_TS                : TEXCOORD1;
    float3 light_TS               : TEXCOORD2;
    float3 view_WS                : TEXCOORD3;
    float4 screenCoordInTexSpace  : TEXCOORD4;
    float3 matrix_TS_to_WS[3]     : TEXCOORD5;
  };
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_view_TS
  #define VS_OUT_light_TS
  #define VS_OUT_view_WS
  #define VS_OUT_screenCoordInTexSpace
  #define VS_OUT_matrix_TS_to_WS

  fragout_2 mainPS(pixdata I,
                  PS_PARAM_BLOCK)
  {
	  fragout_2 PSO;
	  sMaterialData mat;
	  mat_init(mat);
	  mat_decode_textures(mat,texture0,texture1,I.texcoord.xy);
    s2half4 trans_mask  = tex2Dproj( texture2, I.screenCoordInTexSpace );
    s2half fogIntensity = tex2Dproj( shadow_texture, I.screenCoordInTexSpace ).y;

    float3x3 TS_to_WS = { I.matrix_TS_to_WS[0], I.matrix_TS_to_WS[1], cross( I.matrix_TS_to_WS[0], I.matrix_TS_to_WS[1] ) };
    s2half3 normal_WS = mul( mat.vec_normal_ts, TS_to_WS );
  
    s2half3 view_WS = normalize( I.view_WS );


	  // calc to-face-lightning
	  float is2Lightning = step( 0.2, dot( mat.vec_normal_ts, I.light_TS ) );
  	
	  // wet
	  float4 wet_color = saturate( normal_WS.z ) * light_col_diff.w * light_col_diff * texCUBE( textureCube, reflect( -view_WS, normal_WS ) );
  	
    #ifdef S2_FOG
      // calc fog
      fogGlowI( wet_color.xyz, fogIntensity );
    #endif

    // lightning
	  float4 lit_color_0 = float4( is2Lightning * light_col_amb.w * float3( 1.0, 1.0, 1.0 ), mat.color_diffuse.a );
	  float4 lit_color_1 = float4( is2Lightning * light_col_amb.w * light_col_amb.xyz, 0.0 );
  	
    #ifdef S2_FOG
      fogIntensity = saturate(fogIntensity+0.2);
      lit_color_0 *= fogIntensity;
      lit_color_1 *= fogIntensity;
    #endif


	  // apply shading only, where there is no transparency!!
	  PSO.col0 = ( 1.0 - trans_mask.r ) * ( wet_color + lit_color_0 );
	  PSO.col1 = ( 1.0 - trans_mask.r ) * ( lit_color_1 );
	  return PSO;
  }

#endif //PS_SPASS_LIGHTNING



pixdata mainVS(small_appdata sI,
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
	
	pixdata VSO;
	float4 pos4   = float4( I.position, 1.0 );
#ifdef VS_OUT_vertexLightData
  computeVertexLightingColorNormal( VSO.vlColor, VSO.vlNormal,pos4);
#endif
	I.data.xy = I.texcoord.xy = scaler.zw;	
	I.binormal = normalize(cross(float3(I.normal.z, 0, -I.normal.x), I.normal));
	I.tangent  = normalize(cross(I.normal, float3(0, I.normal.z, -I.normal.y)));

#ifdef VS_OUT_hposition
  VSO.hposition = mul( pos4, worldViewProjMatrix );
#endif

#ifdef VS_OUT_hpos_light
  VSO.hpos_light = mul( pos4, lightMatrix );
#endif

#ifdef VS_OUT_worldpos
  VSO.worldPos = mul( pos4, worldMatrix );
#endif

#ifdef VS_OUT_posInLight
  VSO.posInLight = mul( pos4, lightMatrix );
#endif



#ifdef VS_OUT_depthUV
  float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
                    pos4.y*worldViewMatrix[1][2] + 
                    pos4.z*worldViewMatrix[2][2] + 
                    worldViewMatrix[3][2];
  VSO.depthUV = float4(0,0,0,-camSpaceZ*zfrustum_data.w);
#endif

#ifdef VS_OUT_depthFog
  // fog_data contains the character distance to camera, z far and 1 / (zfar - char_dist)
  VSO.depthFog = getFogTCs( VSO.hposition.w, fog_data );
#endif

#ifdef VS_OUT_screenCoordInTexSpace
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
#endif
  invTangentSpaceMatrix = transpose( invTangentSpaceMatrix );

#ifdef VS_OUT_vertexLightData
  VSO.vlNormal = float4(mul( VSO.vlNormal, invTangentSpaceMatrix ),0);
#endif

#ifdef VS_OUT_lpntlight_TS
	float3 pntlight_OS = mul( light_pos, invWorldMatrix ).xyz;
  VSO.pntlight_TS = mul( pntlight_OS - I.position, invTangentSpaceMatrix );
#endif

#ifdef VS_OUT_light_TS
	float3 light_OS = mul( light_pos, invWorldMatrix ).xyz;
  VSO.light_TS = mul( light_OS, invTangentSpaceMatrix );
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
	VSO.texcoord.x = VSO.texcoord.x * param.z + param.x;
  VSO.texcoord.y = VSO.texcoord.y * param.w + param.y;
  VSO.texcoord.zw = 0;
#endif

#ifdef VS_OUT_caustic_tcs
  float2 caust = mul( float4( I.position, 1.0 ), worldMatrix ).xy * 0.007;
  VSO.caustic_tcs.x = caust.x + weather_data.w * 0.1;// + sin( weather_data.w ) * 0.5;
  VSO.caustic_tcs.y = caust.y;// + weather_data.w * 1.2;
  VSO.caustic_tcs.z = caust.x;// + weather_data.w * 0.2;// + sin( weather_data.w ) * 0.5;
  VSO.caustic_tcs.w = caust.y + weather_data.w * 0.07;
#endif
	return VSO;
}


