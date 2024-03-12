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
// Depth Pass Setup
/////////////////////////////////////
#ifdef SPASS_G
  #define USE_SHADOWS
  // VS setup
  // Input
  #define VS_IN_worldViewProjMatrix
  #define VS_IN_worldMatrix
  #define VS_IN_lightMatrix
  #define VS_IN_zfrustum_data
  // Output
  #define VS_OUT_hposition
  #define VS_OUT_depthUV
  #define VS_OUT_posInLight

  struct pixdata
  {
	  float4 hposition  : POSITION;
	  float4 depthUV    : TEXCOORD0;
	  float4 posInLight : TEXCOORD1;
#ifdef CONSOLE_IMPL	
	  float4 posInWorld : TEXCOORD2;
#endif			  
  };

  // PS setup
  // Input
  #define PS_IN_vPos
  #define PS_IN_shadow_map
  #define PS_IN_textureVolume
  #define PS_IN_anzIterations
  #define PS_IN_shadow_data
  #define PS_IN_gradient_texture
  // Output
  #define PS_OUT_col1
#endif

/////////////////////////////////////
// Shadowmap generation pass Setup
/////////////////////////////////////
#ifdef SPASS_SHADOWMAP
  // VS setup
  #define VS_IN_lightMatrix
  #define VS_OUT_hposition

  struct pixdata
  {
	  float4 hposition              : POSITION;
  };
#endif

/////////////////////////////////////
// Ambient Diffuse Setup
/////////////////////////////////////
#ifdef SPASS_AMBDIF
  #ifndef NO_SHADOWS
    #define USE_SHADOWS
  #endif
  // VS setup
  // Inputs
  #define VS_IN_worldViewProjMatrix
  #define VS_IN_invWorldMatrix
  #define VS_IN_light_pos
  #define VS_IN_camera_pos
  #define VS_IN_target_data
  #define VS_IN_zfrustum_data
  #ifdef S2_FOG
    #define VS_IN_fog_data
  #endif
  // Outputs
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_view_TS
  #define VS_OUT_light_TS
  #define VS_OUT_screenCoordInTexSpace
  #ifdef S2_FOG
    #define VS_OUT_depthFog
  #endif
  #ifdef TERRAIN_RELAXED
    #define VS_OUT_slope
  #endif

  struct pixdata
  {
	  float4 hposition              : POSITION;
	  float4 texcoord               : TEXCOORD0;
	  float3 view_TS                : TEXCOORD1;
	  float3 light_TS               : TEXCOORD2;
	  float4 screenCoordInTexSpace  : TEXCOORD3;
    #ifdef S2_FOG
      float2 depthFog             : TEXCOORD4;
    #endif
    #ifdef TERRAIN_RELAXED
      float  slope                : TEXCOORD5;
    #endif
  };

  // PS setup
  // Inputs
  #define PS_IN_texture0         // color texture
  #define PS_IN_texture1         // normal map
  #define PS_IN_texture2         // color texture
  #define PS_IN_texture3         // normal map
  #define PS_IN_texture4         // color texture
  #define PS_IN_texture5         // normal map
  #define PS_IN_texture6         // color texture
  #define PS_IN_texture7         // normal map
  #define PS_IN_texture8         // alpha map or color map for relaxed terrain
#ifdef TERRAIN_RELAXED
  #define PS_IN_texture9         // normal map of sublayer
  #define PS_IN_texture10        // alpha map
  #define PS_IN_texture11        // mask for transition between layer and sublayer
#endif
  #define PS_IN_light_col_diff   // diffuse light color
  #define PS_IN_light_col_amb    // ambient light color used for fake spotlight in frustum
  #define PS_IN_param
  #ifdef S2_FOG
    #define PS_IN_fog_texture      // contains the intensity lookup texture for fog
  #endif
  #ifdef USE_SHADOWS
    #define PS_IN_shadow_texture // shadow map of sun
  #endif
  // Outputs
  #define PS_OUT_col1

#endif



/////////////////////////////////////
// Point lighting setup
/////////////////////////////////////
#ifdef SPASS_PNT
  #ifndef NO_SHADOWS
    #define USE_SHADOWS
  #endif
  // VS setup
  // Inputs
  #define VS_IN_worldViewProjMatrix
  #define VS_IN_invWorldMatrix
  #define VS_IN_light_pos
  #define VS_IN_camera_pos
  #define VS_IN_zfrustum_data
  #ifdef S2_FOG
    #define VS_IN_fog_data
  #endif
  #ifdef USE_SHADOWS
    #define VS_IN_worldMatrix
  #endif
  // Outputs
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_view_TS
  #define VS_OUT_light_TS
  #ifdef S2_FOG
    #define VS_OUT_depthFog
  #endif
  #ifdef USE_SHADOWS
    #define VS_OUT_incident_light_WS
  #endif
  #ifdef TERRAIN_RELAXED
    #define VS_OUT_slope

  struct pixdata
  {
	  float4 hposition           : POSITION;
	  float4 texcoord            : TEXCOORD0;
	  float3 view_TS             : TEXCOORD1;
    float3 light_TS            : TEXCOORD2;
    float  slope               : TEXCOORD3;
  #ifdef S2_FOG
    float2 depthFog            : TEXCOORD4;
  #endif
  #ifdef USE_SHADOWS
    float3 incident_light_WS   : TEXCOORD5;
  #endif
  };
#else
  struct pixdata
  {
    float4 hposition           : POSITION;
    float4 texcoord            : TEXCOORD0;
    float3 view_TS             : TEXCOORD1;
    float3 light_TS            : TEXCOORD2;
  #ifdef S2_FOG
    float2 depthFog            : TEXCOORD3;
  #endif
  #ifdef USE_SHADOWS
    float3 incident_light_WS   : TEXCOORD4;
  #endif
  };
#endif


  // PS setup
  // Input
  #define PS_IN_texture0         // color texture
  #define PS_IN_texture1         // normal map
  #define PS_IN_texture2         // color texture
  #define PS_IN_texture3         // normal map
  #define PS_IN_texture4         // color texture
  #define PS_IN_texture5         // normal map
  #define PS_IN_texture6         // color texture
  #define PS_IN_texture7         // normal map
  #define PS_IN_texture8         // alpha map
#ifdef TERRAIN_RELAXED
  #define PS_IN_texture9         // color map of sublayer
  #define PS_IN_texture10        // normal map of sublayer
  #define PS_IN_texture11        // mask for transition between layer and sublayer
#endif
  #define PS_IN_light_col_diff   // diffuse light color
  #define PS_IN_light_data       // 
  #ifdef S2_FOG
    #define PS_IN_fog_texture      // contains the intensity lookup texture for fog
  #endif
  #ifdef USE_SHADOWS
    #define PS_IN_textureCube       // cube shadow map of the point light
  #endif
  // Output
  #define PS_OUT_col1
#endif



/////////////////////////////////////
// Weather lightning setup
/////////////////////////////////////
#ifdef SPASS_LIGHTNING
  // VS setup
  // Input
  #define VS_IN_worldViewProjMatrix,
  #define VS_IN_worldMatrix
  #define VS_IN_invWorldMatrix
  #define VS_IN_light_pos
  #define VS_IN_param
  #define VS_IN_camera_pos
  #define VS_IN_target_data
  #define VS_IN_zfrustum_data
  // Output
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_view_TS
  #define VS_OUT_light_TS
  #define VS_OUT_view_WS
  #define VS_OUT_screenCoordInTexSpace
  #define VS_OUT_matrix_TS_to_WS

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

  // PS setup
  // Input
  #define PS_IN_texture0         // baked color texture
  #define PS_IN_texture1         // baked normal map
  #define PS_IN_texture2
  #define PS_IN_textureCube      // cube shadow map of the point light
  #define PS_IN_light_col_diff   // diffuse light color
  #define PS_IN_light_col_amb    // 
  // Output
  #define PS_OUT_col1

#endif


/////////////////////////////////////
// Pixel Shader Setup
/////////////////////////////////////
#ifdef PS_DUMMY
struct fragout
{
  float4 col0  : COLOR0;
};
#else
struct fragout
{
  float4 col0  : COLOR0;
#ifdef PS_OUT_col1
  float4 col1  : COLOR1;
#endif
};
#endif

/////////////////////////////////////
// Cube Shadowmap lookup routines
/////////////////////////////////////
#ifdef USE_SHADOWS
  #include "shadow.shader"
#endif


struct small_appdata
{
	float	height:position;
	float4	uvn:color;
};



//////////////////////////////////////////////////
// VERTEX SHADER
//////////////////////////////////////////////////
pixdata mainVS(  small_appdata sI
                ,uniform float4    weather_pos
#ifdef VS_IN_worldViewProjMatrix
	              ,uniform float4x4  worldViewProjMatrix
#endif
#ifdef VS_IN_invWorldMatrix
	              ,uniform float4x4  invWorldMatrix
#endif
#ifdef VS_IN_worldMatrix
                ,uniform float4x4  worldMatrix
#endif                                             
#ifdef VS_IN_light_pos
	              ,uniform float4    light_pos
#endif
#ifdef VS_IN_param
	              ,uniform float4    param
#endif
#ifdef VS_IN_camera_pos
	              ,uniform float4    camera_pos
#endif
#ifdef VS_IN_target_data
#endif
#ifdef VS_IN_lightMatrix
                ,uniform float4x4  lightMatrix
#endif
#ifdef VS_IN_zfrustum_data
                ,uniform float4    zfrustum_data
#endif
#ifdef VS_IN_fog_data
                ,uniform float4    fog_data
#endif
                )
{
	appdata I;
	// Do all the decompression here, compiler will optimize and remove unused calculations

	// Please do not change this code, as it has been carefully reordered to trick the optimizer
	// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
	float4 scaler = sI.uvn.xyxy * float4(weather_pos.zw * 42.5, 42.5, 42.5);	// Rescale from 0/255..6/255 to 0..1
	I.position = float3(scaler.xy + weather_pos.xy, sI.height);
	I.data.xy = I.texcoord.xy = scaler.zw;	
	// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	I.normal.xy = sI.uvn.zw*2-1;
	I.normal.z = sqrt(1-dot(I.normal.xy,I.normal.xy));
	
	I.binormal = normalize(cross(float3(I.normal.z, 0, -I.normal.x), I.normal));
	I.tangent  = normalize(cross(I.normal, float3(0, I.normal.z, -I.normal.y)));


	pixdata VSO;

#ifdef VS_OUT_hposition
#ifdef SPASS_SHADOWMAP
  VSO.hposition = mul( float4( I.position, 1.0 ), lightMatrix );
#else
  // Pass vertex position in clip space to rasterizer
	float4 pos4 = float4( I.position, 1.0 );
  VSO.hposition = mul( pos4, worldViewProjMatrix );
#endif
#endif

#ifdef VS_OUT_posInLight
  VSO.posInLight = mul( pos4, lightMatrix );
#endif

#ifdef VS_OUT_depthUV
  	// put (normalized!) distance
  float distance = ( VSO.hposition.w - zfrustum_data ) * zfrustum_data.z;
  // calc texturecoords for rg(b)-depth encoding
  VSO.depthUV = float4(distance * float2(1.0, 256.0), 0.0, 0.0);
#endif

#ifdef VS_OUT_depthFog
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
#ifdef VS_OUT_matrix_TS_to_WS
#ifdef PS3_IMPL
  float3x3 mattmp = mul( worldMatrix, invTangentSpaceMatrix );
#else
  float3x3 mattmp = mul( invTangentSpaceMatrix, worldMatrix );
#endif  
  VSO.matrix_TS_to_WS[0] = mattmp[0];
  VSO.matrix_TS_to_WS[1] = mattmp[1];
  VSO.matrix_TS_to_WS[2] = mattmp[2];
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

#ifdef CONSOLE_IMPL
  #ifdef SPASS_G
    VSO.posInWorld.z = VSO.hposition.w;
    VSO.posInWorld.xyw = VSO.hposition/VSO.hposition.w;
  #endif
#endif  
	return VSO;
}

#ifdef PS_GENERAL
fragout mainPS(  pixdata I
#ifdef PS_IN_vPos
                ,float2 vPos : VPOS
#endif
#ifdef PS_IN_texture0
                ,uniform sampler2D texture0         // baked color texture
#endif
#ifdef PS_IN_texture1
                ,uniform sampler2D texture1         // baked normal map
#endif
#ifdef PS_IN_texture2
                ,uniform sampler2D texture2
#endif
#ifdef PS_IN_texture3
                ,uniform sampler2D texture3
#endif
#ifdef PS_IN_texture4
                ,uniform sampler2D texture4
#endif
#ifdef PS_IN_texture5
                ,uniform sampler2D texture5
#endif
#ifdef PS_IN_texture6
                ,uniform sampler2D texture6
#endif
#ifdef PS_IN_texture7
                ,uniform sampler2D texture7
#endif
#ifdef PS_IN_texture8
                ,uniform sampler2D texture8
#endif
#ifdef PS_IN_texture9
                ,uniform sampler2D texture9
#endif
#ifdef PS_IN_texture10
                ,uniform sampler2D texture10
#endif
#ifdef PS_IN_texture11
                ,uniform sampler2D texture11
#endif
#ifdef PS_IN_shadow_map
                ,uniform sampler2D shadow_map
#endif
#ifdef PS_IN_textureVolume
                ,uniform sampler3D textureVolume
#endif
#ifdef PS_IN_anzIterations
                ,uniform int anzIterations
#endif
#ifdef PS_IN_shadow_data
                ,uniform float4 shadow_data
#endif
#ifdef PS_IN_gradient_texture
                ,uniform sampler2D gradient_texture
#endif
#ifdef PS_IN_light_col_diff
                ,uniform float4    light_col_diff   // diffuse light color
#endif
#ifdef PS_IN_light_col_amb
               ,uniform float4     light_col_amb    // ambient light color used for fake spotlight in frustum
#endif
#ifdef PS_IN_shadow_texture
               ,uniform sampler2D  shadow_texture    // shadow map of sun
#endif
#ifdef PS_IN_light_data
               ,uniform float4     light_data     // 
#endif
#ifdef PS_IN_textureCube
               ,uniform samplerCUBE textureCube     // cube shadow map of the point light
#endif
#ifdef PS_IN_fog_texture
               ,uniform sampler2D  fog_texture
#endif
                                          )
{
	fragout PSO;
	s2half3 nrm;

#ifdef SPASS_SHADOWMAP
  PSO.col0 = float4( 0,0,0,1 );
#endif

#ifdef SPASS_G
    // depthUV.x is depth * 1.0
  // depthUV.y is depth * 256.0
  // texturelookup endcodes this!!
  s2half4 ramp = tex2D( gradient_texture, I.depthUV.xy );

  // calc shadow
#if LAYER_BIT0
  s2half shadow = 1.0;
#else
	s2half shadow = calcShadow( shadow_map, textureVolume, I.posInLight, vPos, shadow_data.y, shadow_data.x, anzIterations );
#endif

  // put in two g-textures
  PSO.col0 = float4( 0.0, 0.0, 0.0, 1.0 );
  PSO.col1 = float4( ramp.xy, shadow, 1.0 );
#endif


#ifdef PS_IN_texture0
  s2half4 t0_diff = tex2D( texture0, I.texcoord.xy );
#endif
#ifdef PS_IN_texture1
  s2half4 t0_nrm  = decode_normal(tex2D( texture1, I.texcoord.xy ));
#endif
#ifdef PS_IN_texture2
#ifdef SPASS_LIGHTNING
  s2half4 trans_mask = tex2Dproj( texture2, I.screenCoordInTexSpace );
#else
  s2half4 t1_diff = tex2D( texture2, I.texcoord.xy );
#endif
#endif
#ifdef PS_IN_texture3
  s2half4 t1_nrm  = decode_normal(tex2D( texture3, I.texcoord.xy ));
#endif
#ifdef PS_IN_texture4
  s2half4 t2_diff = tex2D( texture4, I.texcoord.xy );
#endif
#ifdef PS_IN_texture5
  s2half4 t2_nrm  = decode_normal(tex2D( texture5, I.texcoord.xy ));
#endif
#ifdef PS_IN_texture6
  s2half4 t3_diff = tex2D( texture6, I.texcoord.xy );
#endif
#ifdef PS_IN_texture7
  s2half4 t3_nrm  = decode_normal(tex2D( texture7, I.texcoord.xy ));
#endif
#ifdef PS_IN_texture8
#ifdef TERRAIN_RELAXED
  s2half4 sb_diff = tex2D( texture8, I.texcoord.xy );
#else
  s2half4 alpha_mask = tex2D( texture8, I.texcoord.xy );
#endif
#endif
#ifdef PS_IN_texture9
  s2half4 sb_nrm = decode_normal(tex2D( texture9, I.texcoord.xy ));
#endif
#ifdef PS_IN_texture10
  s2half4 alpha_mask = tex2D( texture10, I.texcoord.xy );
#endif
#ifdef PS_IN_texture11
  s2half4 relax_limit = tex2D( texture11, I.texcoord.xy );
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

#ifdef VS_OUT_view_WS
  s2half3 view_WS = normalize( I.view_WS );
#endif

#ifdef SPASS_AMBDIF 
#ifdef PS_IN_shadow_texture
  // get shadow term from shadow texture (used by ambient pass)
  float shadow = tex2Dproj( shadow_texture, I.screenCoordInTexSpace ).z;
#else
  float shadow = 1.0;
#endif


#ifdef TERRAIN_RELAXED
	// calc ambient + diffuse + specular layer 0
//	nrm = normalize(t0_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t0_nrm.xyz;
	s2half4 t0_col_amb   = t0_diff * (saturate(dot(view_TS, nrm)) + 0.5);
	s2half4 t0_col_diff  = t0_diff * saturate(dot(light_TS, nrm));
	s2half4 t0_col_spec  = t0_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20);
  float4 t0_final_amb  = light_col_amb * t0_col_amb;
  float4 t0_final_diff = light_col_diff * shadow * (t0_col_diff + t0_col_spec);

	// calc ambient + diffuse + specular layer 1
//	nrm = normalize(t1_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t1_nrm.xyz;
	s2half4 t1_col_amb   = t1_diff * (saturate(dot(view_TS, nrm)) + 0.5);
	s2half4 t1_col_diff  = t1_diff * saturate(dot(light_TS, nrm));
	s2half4 t1_col_spec  = t1_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20);
  float4 t1_final_amb  = light_col_amb * t1_col_amb;
  float4 t1_final_diff = light_col_diff * shadow * (t1_col_diff + t1_col_spec);

	// calc ambient + diffuse + specular layer 2
//	nrm = normalize(t2_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t2_nrm.xyz;
	s2half4 t2_col_amb   = t2_diff * (saturate(dot(view_TS, nrm)) + 0.5);
	s2half4 t2_col_diff  = t2_diff * saturate(dot(light_TS, nrm));
	s2half4 t2_col_spec  = t2_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20);
  float4 t2_final_amb  = light_col_amb * t2_col_amb;
  float4 t2_final_diff = light_col_diff * shadow * (t2_col_diff + t2_col_spec);

	// calc ambient + diffuse + specular layer 3
//	nrm = normalize(t3_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t3_nrm.xyz;
	s2half4 t3_col_amb   = t3_diff * (saturate(dot(view_TS, nrm)) + 0.5);
	s2half4 t3_col_diff  = t3_diff * saturate(dot(light_TS, nrm));
	s2half4 t3_col_spec  = t3_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20);
  float4 t3_final_amb  = light_col_amb * t3_col_amb;
  float4 t3_final_diff = light_col_diff * shadow * (t3_col_diff + t3_col_spec);

	// calc ambient + diffuse + specular sublayer
//	nrm = normalize(sb_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = sb_nrm.xyz;
	s2half4 sb_col_amb   = sb_diff * (saturate(dot(view_TS, nrm)) + 0.5);
	s2half4 sb_col_diff  = sb_diff * saturate(dot(light_TS, nrm));
	s2half4 sb_col_spec  = sb_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20);
  float4 sb_final_amb  = light_col_amb * sb_col_amb;
  float4 sb_final_diff = light_col_diff * shadow * (sb_col_diff + sb_col_spec);

	// calc pre-factors
	s2half t0_f = alpha_mask.r;
	s2half t1_f = alpha_mask.g;
	s2half t2_f = alpha_mask.b;
	s2half t3_f = alpha_mask.a;

	// standard or sub for base layer?
	s2half4 base_col;
	if(I.slope > relax_limit.w)
		base_col = t0_final_amb + t0_final_diff;
	else
		base_col = sb_final_amb + sb_final_diff;

	// add all layers
  float4 col0 = float4(0.0, 0.0, 0.0, 0.0);
#if LAYER_BIT0
	col0 += t0_f * base_col;
#endif
#if LAYER_BIT1
	col0 += t1_f * (t1_final_amb + t1_final_diff);
#endif
#if LAYER_BIT2
	col0 += t2_f * (t2_final_amb + t2_final_diff);
#endif
#if LAYER_BIT3
	col0 += t3_f * (t3_final_amb + t3_final_diff);
#endif

#ifdef S2_FOG
  // calc fog
  fogDiffuse( col0.xyz, fog_texture, I.depthFog, light_col_diff );
#endif

	// out
  PSO.col0.xyz = col0.xyz;
	PSO.col0.a   = 1.0;
	PSO.col1     = float4(0.0, 0.0, 0.0, 0.0);

#else // non relaxed version
	// calc ambient + diffuse + specular layer 0
//	nrm = normalize(t0_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t0_nrm.xyz;
	s2half3 t0_col_amb   = t0_diff.rgb * (saturate(dot(view_TS, nrm)) + 0.5);
	s2half3 t0_col_diff  = t0_diff.rgb * saturate(dot(light_TS, nrm));
	s2half3 t0_col_spec  = t0_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20);
  float3 t0_final_amb  = light_col_amb.xyz * t0_col_amb;
  float3 t0_final_diff = light_col_diff.xyz * shadow * (t0_col_diff + t0_col_spec);

	// calc ambient + diffuse + specular layer 1
//	nrm = normalize(t1_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t1_nrm.xyz;
	s2half3 t1_col_amb   = t1_diff.rgb * (saturate(dot(view_TS, nrm)) + 0.5);
	s2half3 t1_col_diff  = t1_diff.rgb * saturate(dot(light_TS, nrm));
	s2half3 t1_col_spec  = t1_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20);
  float3 t1_final_amb  = light_col_amb.xyz * t1_col_amb;
  float3 t1_final_diff = light_col_diff.xyz * shadow * (t1_col_diff + t1_col_spec);

	// calc ambient + diffuse + specular layer 2
//	nrm = normalize(t2_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t2_nrm.xyz;
	s2half3 t2_col_amb   = t2_diff.rgb * (saturate(dot(view_TS, nrm)) + 0.5);
	s2half3 t2_col_diff  = t2_diff.rgb * saturate(dot(light_TS, nrm));
	s2half3 t2_col_spec  = t2_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20);
  float3 t2_final_amb  = light_col_amb.xyz * t2_col_amb;
  float3 t2_final_diff = light_col_diff.xyz * shadow * (t2_col_diff + t2_col_spec);

	// calc ambient + diffuse + specular layer 3
//	nrm = normalize(t3_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t3_nrm.xyz;
	s2half3 t3_col_amb   = t3_diff.rgb * (saturate(dot(view_TS, nrm)) + 0.5);
	s2half3 t3_col_diff  = t3_diff.rgb * saturate(dot(light_TS, nrm));
	s2half3 t3_col_spec  = t3_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20);
  float3 t3_final_amb  = light_col_amb.xyz * t3_col_amb;
  float3 t3_final_diff = light_col_diff.xyz * shadow * (t3_col_diff + t3_col_spec);

	// calc pre-factors
	s2half t0_f = alpha_mask.r;
	s2half t1_f = alpha_mask.g;
	s2half t2_f = alpha_mask.b;
	s2half t3_f = alpha_mask.a;

	// add all layers
  float3 finalCol = float3(0.0, 0.0, 0.0);
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

#ifdef S2_FOG
  // calc fog
  fogDiffuse( finalCol, fog_texture, I.depthFog, light_col_diff );
#endif

	// out
	PSO.col0 = float4(finalCol, 1.0);
	PSO.col1 = float4(0.0, 0.0, 0.0, 0.0);

#endif
#endif

#ifdef SPASS_PNT
	// calc squared distance from light to point
	float sq_dist_to_light = dot( I.light_TS, I.light_TS );
	// get fraction of light distance to the max light radius
	s2half temp_dist = saturate( sq_dist_to_light / ( light_data.x * light_data.x ) );
  // calculate fall off
	s2half intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
  //float intensity = cos( 1.5708 * temp_dist );
	// multiply it by intensity of light source
	intensity *= light_data.y;
#ifdef S2_FOG
  // calc fog
  fogPnt( intensity, fog_texture, I.depthFog );
#endif

#ifdef TERRAIN_RELAXED
	// calc diffuse + specular layer 0
//	nrm = normalize(t0_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t0_nrm.xyz;
	s2half4 t0_col_diff = t0_diff * saturate(dot(light_TS, nrm));
	s2half4 t0_col_spec = t0_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20.0);

	// calc diffuse + specular layer 1
//	nrm = normalize(t1_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t1_nrm.xyz;
	s2half4 t1_col_diff = t1_diff * saturate(dot(light_TS, nrm));
	s2half4 t1_col_spec = t1_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20.0);

	// calc diffuse + specular layer 2
//	nrm = normalize(t2_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t2_nrm.xyz;
	s2half4 t2_col_diff = t2_diff * saturate(dot(light_TS, nrm));
	s2half4 t2_col_spec = t2_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20.0);

	// calc diffuse + specular layer 3
//	nrm = normalize(t3_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t3_nrm.xyz;
	s2half4 t3_col_diff = t3_diff * saturate(dot(light_TS, nrm));
	s2half4 t3_col_spec = t3_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20.0);

	// calc diffuse + specular sublayer
//	nrm = normalize(sb_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = sb_nrm.xyz;
	s2half4 sb_col_diff = sb_diff * saturate(dot(light_TS, nrm));
	s2half4 sb_col_spec = sb_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20);

	// calc pre-factors
	s2half t0_f = alpha_mask.r;
	s2half t1_f = alpha_mask.g;
	s2half t2_f = alpha_mask.b;
	s2half t3_f = alpha_mask.a;
	
	s2half4 base_col;
	// standard or sub for base layer?
	if(I.slope > relax_limit.w)
		base_col = t0_col_diff + t0_col_spec;
	else
		base_col = sb_col_diff + sb_col_spec;

	// add all layers
  PSO.col0 = float4(0.0, 0.0, 0.0, 0.0);
#if LAYER_BIT0
	PSO.col0 += t0_f * base_col;
#endif
#if LAYER_BIT1
	PSO.col0 += t1_f * (t1_col_diff + t1_col_spec);
#endif
#if LAYER_BIT2
	PSO.col0 += t2_f * (t2_col_diff + t2_col_spec);
#endif
#if LAYER_BIT3
	PSO.col0 += t3_f * (t3_col_diff + t3_col_spec);
#endif

	// out
	PSO.col0  *= intensity * light_col_diff;
	PSO.col0.a = 1.0;
	PSO.col1   = float4(0.0, 0.0, 0.0, 0.0);
#else
	// calc diffuse + specular layer 0
//	nrm = normalize(t0_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t0_nrm.xyz;
	s2half3 t0_col_diff = t0_diff.rgb * saturate(dot(light_TS, nrm));
	s2half3 t0_col_spec = t0_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20.0);

	// calc diffuse + specular layer 1
//	nrm = normalize(t1_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t1_nrm.xyz;
	s2half3 t1_col_diff = t1_diff.rgb * saturate(dot(light_TS, nrm));
	s2half3 t1_col_spec = t1_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20.0);

	// calc diffuse + specular layer 2
//	nrm = normalize(t2_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t2_nrm.xyz;
	s2half3 t2_col_diff = t2_diff.rgb * saturate(dot(light_TS, nrm));
	s2half3 t2_col_spec = t2_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20.0);

	// calc diffuse + specular layer 3
//	nrm = normalize(t3_nrm.xyz - s2half3(0.5, 0.5, 0.5));
	nrm = t3_nrm.xyz;
	s2half3 t3_col_diff = t3_diff.rgb * saturate(dot(light_TS, nrm));
	s2half3 t3_col_spec = t3_nrm.a * pow(saturate(dot(half_vec_TS, nrm)), 20.0);

	// calc pre-factors
	s2half t0_f = alpha_mask.r;
	s2half t1_f = alpha_mask.g;
	s2half t2_f = alpha_mask.b;
	s2half t3_f = alpha_mask.a;

	// add all layers
  float3 finalCol = float3(0.0, 0.0, 0.0);
#if LAYER_BIT0
  finalCol += t0_f * (t0_col_diff + t0_col_spec);
#endif
#if LAYER_BIT1
	finalCol += t1_f * (t1_col_diff + t1_col_spec);
#endif
#if LAYER_BIT2
	finalCol += t2_f * (t2_col_diff + t2_col_spec);
#endif
#if LAYER_BIT3
	finalCol += t3_f * (t3_col_diff + t3_col_spec);
#endif

//Boris: NEU
#ifdef CONSOLE_IMPL

  #ifdef USE_SHADOWS
    #ifdef SPASS_G
     shadow_data.z = I.posInWorld.z;
    #endif    
    float super_shadow = calcShadow(shadow_map, I.incident_light_WS, shadow_data );
    //incident_light_WS
    //float shadow = calcPntFadeShadow(textureCube, light_data.z * I.incident_light_WS.xzy,light_data.w);
    finalCol *= shadow * intensity * light_col_diff.rgb;
  #else
    finalCol *= intensity * light_col_diff.rgb;
  #endif

	// out
//	PSO.col0 = float4(finalCol, 1.0);
	PSO.col0 = float4(1.0, 0.0, 0.0, 1.0);
	PSO.col1 = float4(0.0, 0.0, 0.0, 0.0);
	return PSO;
#else



#ifdef PS_IN_textureCube  // get shadow term from cube shadow map (used by point light pass)
 	float shadow = calcPntFadeShadow(textureCube, light_data.z * I.incident_light_WS.xzy,light_data.w);
  finalCol *= shadow * intensity * light_col_diff.rgb;
#else
  finalCol *= intensity * light_col_diff.rgb;
#endif

	// out
	PSO.col0 = float4(finalCol, 1.0);
	PSO.col1 = float4(0.0, 0.0, 0.0, 0.0);
#endif
#endif
#endif

#ifdef SPASS_LIGHTNING
	s2half3 normal = normalize(t0_nrm.xyz - s2half3(0.5, 0.5, 0.5));
  float3x3 TS_to_WS = { I.matrix_TS_to_WS[0], I.matrix_TS_to_WS[1], I.matrix_TS_to_WS[2] };
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