//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
//#OptDef:IS_OPAQUE
//#OptDef:VERTEXLIGHTING_TEST

// standard
#define VERT_XVERTEX
#include "extractvalues.shader"


#ifdef SM1_1

DEFINE_VERTEX_DATA


struct pixdata {
	float4 hposition   : POSITION;
	float4 diffuse     : COLOR0;
	float4 specular    : COLOR1;
	float2 texcoord0   : TEXCOORD0;
	float2 texcoord1   : TEXCOORD1;
#ifdef S2_FOG
  float fog    : FOG;
#endif
};

struct fragout {
	float4 col      : COLOR;
};

pixdata mainVS(appdata I,
  uniform float4x4  worldViewProjMatrix,
  uniform float4x4  worldMatrix,
  uniform float4    camera_pos,
  uniform lightData globLightData,
  uniform float4    fog_data)
{
	pixdata O;

	EXTRACT_VERTEX_VALUES;

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	float3 worldVertPos = mul(pos4, worldMatrix);
	float3 worldVertNormal = normalize(mul(nrm4.xyz, (float3x3) worldMatrix));

	O.diffuse = calcLight(worldVertPos, worldVertNormal, camera_pos, globLightData, O.specular);

	// texture coords
	O.texcoord0.xy = uv0.xy;
	O.texcoord1.xy = uv0.xy;
	//O.shadowUV = float4(0.0f, 0.0f, 1.0f, 1.0f);
	//O.lightRelPos.xyz = (worldVertPos - globLightData.myLightPosition[0].xyz);

#ifdef S2_FOG
  O.fog = calcFog(O.hposition, fog_data);
#endif

	return O;
}


fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D texture1,
    uniform sampler2D shadow_texture,
    uniform float4    light_col_amb)
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0);
	s2half4 tex1 = tex2D(texture1, I.texcoord1);
	//s2half4 shadow = tex2D(shadow_texture, I.shadowUV);

	//float lightDist = dot(I.lightRelPos, I.lightRelPos);

	float3 glow_amb = tex1.a * tex0.rgb;
	float3 diffuse = tex0.rgb * I.diffuse.rgb;
	float3 spec = tex1.rgb * I.specular.rgb;

	//O.col.rgb = glow_amb + diffuse + spec;
	//O.col.rgb = diffuse + spec;
	O.col.rgb = diffuse;
	O.col.a = tex0.a;

	return O;
}

 
#else //SM1_1
  #include "lighting.shader"
  ////////////////////////////////////////////////////////////////
  // >SM20 code path
  ////////////////////////////////////////////////////////////////

  // standard
  struct appdata {
    float3 position    : POSITION;
    float3 normal      : NORMAL;
    float3 tangent     : TANGENT;
    float3 binormal    : BINORMAL;
    float2 texcoord    : TEXCOORD0;
    float2 data        : TEXCOORD1;
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
      light_setup_lightvec(ld,mat,I.view_TS,I.pntlight_TS);

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
                    PS_PARAM_BLOCK)
    {
      fragout_2 PSO;
      
      sMaterialData mat;
      sLightingData ld;
      mat_init(mat);
      light_init(ld,light_col_amb,light_col_diff,fog_color);
	     
      mat_decode_textures_std(mat,texture0,texture1,texture2,colvar_mask,pix_color_ramp,I.texcoord.xy);
      light_setup_shadow_fog_deferred(ld,shadow_texture,I.screenCoordInTexSpace,fog_texture,I.depthFog);
      light_setup_lightvec(ld,mat,I.view_TS,I.light_TS);
    #ifdef VS_OUT_vertexLightData
      light_setup_vertexlighting(ld,mat,I.vlColor,I.vlNormal);
    #endif 
      sLightingColors colors;
      light_compute(colors,ld,mat);
      light_add_glow(colors);

      // out
      PSO.col0 = light_lerp_fog(ld,colors.color_final_color);
      PSO.col1 = light_scale_fog(ld,colors.color_final_glow);
      return PSO;
    }
  #endif 
    
  pixdata mainVS(appdata I,
                 VS_PARAM_BLOCK)
  {
	  pixdata VSO;
    float4 pos4 = float4(I.position, 1.0);
    float4 nrm4 = float4(I.normal, 0.0);

  #ifdef VS_OUT_vertexLightData
    computeVertexLightingColorNormal( VSO.vlColor, VSO.vlNormal,pos4,vtx_lightBlocks);
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
  #ifdef PS3_IMPL
  float camSpaceZ = pos4.x*worldViewMatrix[2][0] +  
                    pos4.y*worldViewMatrix[2][1] + 
                    pos4.z*worldViewMatrix[2][2] + 
                    worldViewMatrix[2][3];

  #else
    float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
                      pos4.y*worldViewMatrix[1][2] + 
                      pos4.z*worldViewMatrix[2][2] + 
                      worldViewMatrix[3][2];
  #endif
    VSO.depthUV = float4(0,0,0,-camSpaceZ*zfrustum_data.w);
  #endif

  #ifdef VS_OUT_depthFog
    // fog_data contains the character distance to camera, z far and 1 / (zfar - char_dist)
    VSO.depthFog = getFogTCs( VSO.hposition.w, fog_data );
  #endif

  #ifdef VS_OUT_screenCoordInTexSpace
	  // calculate vertex position in screen space and transform to texture space in PS
	  VSO.screenCoordInTexSpace.x   = VSO.hposition.w + VSO.hposition.x;
	  VSO.screenCoordInTexSpace.y   = VSO.hposition.w - VSO.hposition.y;
	  VSO.screenCoordInTexSpace.z   = 0.0;
	  VSO.screenCoordInTexSpace.w   = 2.0 * VSO.hposition.w;
	  VSO.screenCoordInTexSpace.xy *= target_data.xy;
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
		VSO.pntlight_TS = REAL_MUL( pntlight_OS - I.position, invTangentSpaceMatrix );
	  #else
		VSO.pntlight_TS = mul( pntlight_OS - I.position, invTangentSpaceMatrix );
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
      VSO.view_TS = REAL_MUL( camera_OS - I.position, invTangentSpaceMatrix );
    # endif
    #else
    # ifdef MINIMAPMODE
      VSO.view_TS = mul( camera_OS, invTangentSpaceMatrix );
    # else
      VSO.view_TS = mul( camera_OS - I.position, invTangentSpaceMatrix );
    # endif
    #endif
  #endif

  #ifdef VS_OUT_texcoord
	  VSO.texcoord = I.texcoord.xyxy;
  #endif
	  return VSO;
  }

#endif