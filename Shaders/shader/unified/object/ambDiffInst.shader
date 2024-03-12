//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
//#OptDef:SPASS_FX
//#OptDef:IS_OPAQUE
//#OptDef:ENABLE_VERTEXLIGHTING

// standard
#define VERT_XVERTEX
#include "extractvalues.shader"

#include "instancing.shader"


  #include "lighting.shader"
  ////////////////////////////////////////////////////////////////
  // >SM20 code path
  ////////////////////////////////////////////////////////////////

  // standard
  struct appdata {
	float4 position_ID : POSITION;
	float4 binml_tan   : NORMAL;
    float2 texcoord    : TEXCOORD0;
	float4 sgn         : TEXCOORD1;
  };


  #ifdef SPASS_PNT
  #define S2_FOG
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
					float vFace : VFACE,
                    PS_PARAM_BLOCK)
    {
	    fragout_2 PSO;

	    sMaterialData mat;
	    sLightingData ld;
	    mat_init(mat);
	    light_init(ld,light_col_amb,light_col_diff,float4(0,0,0,0));

      light_set_falloff(ld,I.pntlight_TS,light_data);
      clip(ld.sc_light_intensity-0.01); 

      light_setup_shadow_fog_pnt(ld,textureCube,light_data,I.incident_light_WS.xzy,fog_texture,I.depthFog);
      clip(ld.sc_shadow_intensity-0.01);

      mat_decode_textures_std(mat,texture0,texture1,texture2,colvar_mask,pix_color_ramp,I.texcoord.xy);
      
      if(vFace > 0.f)
		mat.vec_normal_ts.z *= -1.f;
      
      light_setup_lightvec(ld,mat,I.view_TS,I.pntlight_TS);

#ifdef FLAT_DEBRIS
      // For flat particles, rim darkening isn't so important or desirable...
      ld.sc_theta_view = 1.5f;
#endif

      sLightingColors colors;
      light_compute(colors,ld,mat);
      
      
	    // out
#ifdef PS3_IMPL //TB:HACK!
      PSO.col0 = colors.color_final_color;
      PSO.col1 = colors.color_final_glow;
#else	    
      PSO.col0 = light_scale_fog(ld,colors.color_final_color);
      PSO.col1 = light_scale_fog(ld,colors.color_final_glow);
#endif

      
	    return PSO; 
    }
  #endif
  #ifdef SPASS_ITEMPREVIEW

    struct pixdata {
      float4 hposition   : POSITION;
      float4 texcoord   : TEXCOORD0;
      float3 tan_to_view0 : TEXCOORD5;
      float3 tan_to_view1 : TEXCOORD6;
      float3 tan_to_view2 : TEXCOORD7;
    };
    #define VS_OUT_hposition
    #define VS_OUT_texcoord
    #define VS_OUT_tan_to_view


    fragout_2 mainPS(pixdata I,
					 float vFace : VFACE,
                     PS_PARAM_BLOCK)
    {
	    fragout_2 O;
	    // get texture values
	    s2half4 tex3 = tex2D(texture3, I.texcoord.xy);
  #ifdef ITEMPREVIEW_CFG_CLIPSKIN
      // if this item is not equipped then skip drawing the skin
      if( pix_data_array.x )
  	    clip( - tex3.a );
  #endif
	    s2half4 tex0 = tex2D(texture0, I.texcoord.xy);
	    s2half4 tex1 = tex2D(texture1, I.texcoord.xy);
	    s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord.xy));
	    
		if(vFace > 0.f)
		  tex2.z *= -1.f;
	    
  #ifdef IS_OPAQUE
      tex0.a = 1;
  #endif
  #ifdef ITEMPREVIEW_CFG_GLAS
    #ifdef LAYER_BIT0
      tex0.a = 1;
    #endif
    #ifdef LAYER_BIT1
      tex0.a = 1;
    #endif
  #endif
      clip(tex0.a-0.1);
      O.col0 = calcItemPreviewColor(I.tan_to_view0,I.tan_to_view1,I.tan_to_view2,
                                      tex0,tex1,tex2);
      O.col1 = float4(0,0,0,1);
	    return O;
    } 
  
  #endif

  #ifdef SPASS_AMBDIF
    #define VS_OUT_hposition
    #define VS_OUT_texcoord
    #define VS_OUT_view_TS
    #define VS_OUT_light_TS
    #define VS_OUT_screenCoordInTexSpace
    #define VS_OUT_depthFog
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
        float4 vlColor           : COLOR0;
        float4 vlNormal          : TEXCOORD5;
      #endif
    };

    fragout_2 mainPS(pixdata I,
					float vFace : VFACE,
                    PS_PARAM_BLOCK)
    {
      fragout_2 PSO;
      
      sMaterialData mat;
      sLightingData ld;
      mat_init(mat);
      light_init(ld,light_col_amb,light_col_diff,float4(fog_color.xyz,0));
	     
      mat_decode_textures_std(mat,texture0,texture1,texture2,colvar_mask,pix_color_ramp,I.texcoord.xy);
      
      if(vFace > 0.f)
		mat.vec_normal_ts *= -1.f;
      
      light_setup_shadow_fog_deferred(ld,shadow_texture,I.screenCoordInTexSpace,fog_texture,I.depthFog);
      light_setup_lightvec(ld,mat,I.view_TS,I.light_TS);
    #ifdef VS_OUT_vertexLightData
      light_setup_vertexlighting(ld,mat,I.vlColor,I.vlNormal);
    #endif  
    
#ifdef FLAT_DEBRIS
      // For flat particles, rim darkening isn't so important or desirable...
      ld.sc_theta_view = 1.5f;
#endif
    
      sLightingColors colors;
      light_compute(colors,ld,mat);
      light_add_glow(colors);
      // out
      PSO.col0   = light_lerp_fog(ld,colors.color_final_color);
      PSO.col1   = light_scale_fog(ld,colors.color_final_glow);

	  #ifdef LAYER_BIT4
		  PSO.col0.w = 0.4*ld.sc_fog_intensity;
		  PSO.col1.w = 1.0*ld.sc_fog_intensity;
	  #endif      
      
      return PSO;
    }
  #endif  
    
  pixdata mainVS(appdata I,
                 VS_PARAM_BLOCK)
  {
	pixdata VSO;
	  
#ifdef INSTANCED_DEBRIS
	instancedata ID = extractInstanceData(I.position_ID.w, instanceTextureWH.x, instanceTextureWH.yz);
	float3 instancedPos = mul(ID.positionTransform,float4(I.position_ID.xyz, 1.0));
#else
	float3 instancedPos = I.position_ID.xyz;
#endif
	
	// Unpack/reconstruct normals
	float3 binormal;
	binormal.xy = I.binml_tan.xy;
	binormal.z = (2.f * I.sgn.g - 1.f) * sqrt(1.f - dot(binormal.xy,binormal.xy));
	
	float3 tangent;
	tangent.xy = I.binml_tan.zw;
	tangent.z = (2.f * I.sgn.b - 1.f) * sqrt(1.f - dot(tangent.xy,tangent.xy));
	
	float3 normal = (2.f * I.sgn.r - 1.f) * cross(binormal, tangent);
	
#ifdef INSTANCED_DEBRIS
	float3 instancedNml   = normalize(mul(ID.directionTransform, normal));
	float3 instancedBinml = normalize(mul(ID.directionTransform, binormal));
	float3 instancedTan   = normalize(mul(ID.directionTransform, tangent));
#else
	float3 instancedNml   = normal;
	float3 instancedBinml = binormal;
	float3 instancedTan   = tangent;
#endif
	  
    float4 pos4 = float4(instancedPos, 1.0);
    float4 nrm4 = float4(instancedNml, 0.0);

  #ifdef VS_OUT_vertexLightData
    computeVertexLightingColorNormal( VSO.vlColor, VSO.vlNormal,pos4);
  #endif

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
	  invTangentSpaceMatrix[0] = - instancedTan;
	  invTangentSpaceMatrix[1] = - instancedBinml;
	  invTangentSpaceMatrix[2] =   instancedNml;

	#ifdef VS_OUT_tan_to_view
	  float3x3 mattmp2 = mul( invTangentSpaceMatrix, lightMatrix );
    VSO.tan_to_view0 = mattmp2[0];
    VSO.tan_to_view1 = mattmp2[1];
    VSO.tan_to_view2 = mattmp2[2];
	#endif

  #ifdef VS_OUT_matrix_TS_to_WS
    float3x3 mattmp = mul( invTangentSpaceMatrix, worldMatrix );
    VSO.matrix_TS_to_WS[0] = mattmp[0];
    VSO.matrix_TS_to_WS[1] = mattmp[1];
    VSO.matrix_TS_to_WS[2] = mattmp[2];
  #endif
    invTangentSpaceMatrix = transpose( invTangentSpaceMatrix );

  #ifdef VS_OUT_vertexLightData
    VSO.vlNormal = float4(mul( VSO.vlNormal, invTangentSpaceMatrix ),0);
  #endif

  #ifdef VS_OUT_lpntlight_TS
	  float3 pntlight_OS = mul( light_pos, invWorldMatrix ).xyz;
	  #ifdef PS3_IMPL
		VSO.pntlight_TS = REAL_MUL( pntlight_OS - instancedPos, invTangentSpaceMatrix );
	  #else
		VSO.pntlight_TS = mul( pntlight_OS - instancedPos, invTangentSpaceMatrix );
	  #endif
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
    #ifdef PS3_IMPL
    # ifdef MINIMAPMODE
      VSO.view_TS = REAL_MUL( camera_OS, invTangentSpaceMatrix );
    # else
      VSO.view_TS = REAL_MUL( camera_OS - instancedPos, invTangentSpaceMatrix );
    # endif
    #else
    # ifdef MINIMAPMODE
      VSO.view_TS = mul( camera_OS, invTangentSpaceMatrix );
    # else
      VSO.view_TS = mul( camera_OS - instancedPos, invTangentSpaceMatrix );
    # endif
    #endif
  #endif

  #ifdef VS_OUT_texcoord
	#ifdef INSTANCED_DEBRIS
	  VSO.texcoord = I.texcoord.xyxy + ID.variationUVOffset.xyxy;
	#else
	  VSO.texcoord = I.texcoord.xyxy;
	#endif
  #endif
	  return VSO;
  }

