//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88

// cloth & latex
#define VERT_XVERTEX
#include "extractvalues.shader"


#ifdef SM1_1

  struct appdata {
	  float3 position     : POSITION;
	  float3 normal       : NORMAL;
	  float3 tangent      : TANGENT;
	  float3 binormal     : BINORMAL;
	  float2 texcoord     : TEXCOORD0;
	  float2 data         : TEXCOORD1;
  };

  struct pixdata {
    float4 hposition    : POSITION;
    float4 diffuse     : COLOR0;
    float4 specular    : COLOR1;
    float2 texcoord0    : TEXCOORD0;
    float2 texcoord1    : TEXCOORD1;
    //float4 shadowUV    : TEXCOORD2;
    //float3 lightRelPos : TEXCOORD3;
  #ifdef S2_FOG
    float fog    : FOG;
  #endif
  };
  struct fragout {
	  float4 col         : COLOR;
  };




  pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldMatrix,
    uniform float4x4 invWorldMatrix,
    uniform lightData globLightData,
    uniform float4   camera_pos,
    uniform float4   fog_data )
  {
	  pixdata O;
  	
	  float4 pos4 = float4(I.position, 1.0);
	  float4 nrm4 = float4(I.normal, 0.0);

	  // vertex pos
	  O.hposition = mul(pos4, worldViewProjMatrix);

    float3 worldVertPos = mul(pos4, worldMatrix);
    float3 worldVertNormal = normalize(mul(nrm4.xyz, (float3x3) worldMatrix));

    O.diffuse = calcLight(worldVertPos, worldVertNormal, camera_pos, globLightData, O.specular);

    O.texcoord0 = O.texcoord1 = I.texcoord;

  #ifdef S2_FOG
    O.fog = calcFog(O.hposition, fog_data);
  #endif
	  return O;
  }


  fragout mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D texture1,
      uniform sampler2D texture2,
      uniform sampler2D texture3,
      uniform sampler2D shadow_texture,
      uniform sampler2D fog_texture,
      uniform samplerCUBE textureCube,
      uniform float4    light_col_amb,
      uniform float4    light_col_diff,
      uniform float4    pix_data_array )
  {
	  fragout O;

    s2half4 tex3 = tex2D(texture3, I.texcoord0.xy);
    // Clip the skin if the item is not equipped but lying on the ground
    if( pix_data_array.x )
      clip( -tex3.a );


  	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  s2half4 tex1 = tex2D(texture1, I.texcoord1.xy);

	  float3 glow_amb = tex1.a * tex0.rgb;
	  //float3 diffuse = tex0.rgb * I.diffuse.rgb;
	  //float3 spec = tex1.rgb * I.specular.rgb;
    float3 diffuse = tex0.rgb;
	  float3 spec = tex1.rgb;

	  //O.col.rgb = glow_amb + diffuse + spec;
	  O.col.rgb = diffuse;
	  O.col.a = tex0.a;
	  return O;
  } 

#else //SM1_1
  ////////////////////////////////////////////////////////////////
  // >SM20 code path
  ////////////////////////////////////////////////////////////////

  struct appdata {
	  float3 position     : POSITION;
	  float3 normal       : NORMAL;
	  float3 tangent      : TANGENT;
	  float3 binormal     : BINORMAL;
	  float2 texcoord     : TEXCOORD0;
	  float2 data         : TEXCOORD1;
  };


  #ifdef SPASS_ITEMPREVIEW
    //use the shared itempreview shader
    //setup shader config:
    #define ITEMPREVIEW_CFG_CLIPSKIN
    #include "itemPreviewStd.shader"
  #else
    struct pixdata {
      float4 hposition    : POSITION;
      float4 texcoord0    : TEXCOORD0;
      float4 camDist_ts   : TEXCOORD1;
      float4 lightDist_ts : TEXCOORD2;
      float4 screenCoord  : TEXCOORD3;
      float4 tan_to_wrld0 : TEXCOORD4;
      float4 tan_to_wrld1 : TEXCOORD5;
      float4 tan_to_wrld2 : TEXCOORD6;
      float4 camDist_ws   : TEXCOORD7;
    };
    struct fragout {
	    float4 col[2]      : COLOR;
    };

    pixdata mainVS(appdata I,
      uniform float4x4 worldViewProjMatrix,
      uniform float4x4 worldMatrix,
      uniform float4x4 invWorldMatrix,
      uniform float4   light_pos,
      uniform float4   camera_pos,
      uniform float4   zfrustum_data,
      uniform float4   fog_data )
    {
	    pixdata O;
    	
	    float4 pos4 = float4(I.position, 1.0);
	    float4 nrm4 = float4(I.normal, 0.0);

	    // vertex pos
	    O.hposition = mul(pos4, worldViewProjMatrix);


	    // vertex-position in screen space
	    O.screenCoord.x = O.hposition.w + O.hposition.x;
	    O.screenCoord.y = O.hposition.w - O.hposition.y;
	    O.screenCoord.z = 0.0;
	    O.screenCoord.w = 2.0 * O.hposition.w;
	    O.screenCoord.xy *= target_data.xy;

	    // build object-to-tangent space matrix
	    float3x3 objToTangentSpace;
	    objToTangentSpace[0] = -1.0 * I.tangent;
	    objToTangentSpace[1] = -1.0 * I.binormal;
	    objToTangentSpace[2] = I.normal;

	    // need matrix to convert from tangentspace to worldspace
	    float3x3 tangent_to_world;
	    tangent_to_world = mul(objToTangentSpace, worldMatrix);
    	
	    // pass to fragment
	    O.tan_to_wrld0 = float4(tangent_to_world[0], 0.0);
	    O.tan_to_wrld1 = float4(tangent_to_world[1], 0.0);
	    O.tan_to_wrld2 = float4(tangent_to_world[2], 0.0);

	    // convert light direction vector from worldspace to objectspace
	    float4 l0_dir_obj = mul(light_pos, invWorldMatrix);
	    // convert light direction vector from objectspace to tangentspace
	    float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz);
	    // store light vector in texcoord3
	    O.lightDist_ts = float4(l0_dir_tan, 0.0);

	    // convert camera direction vector from worldspace to objectspace
	    float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	    // calc direction vector from vertex position to camera-position
	    c_dir_obj -= pos4;
	    // convert camera direction vector from objectspace to tangentspace
	    float3 c_dir_tan = mul(objToTangentSpace, c_dir_obj.xyz);
	    // store camera vec in texcoord2
	    O.camDist_ts = float4(c_dir_tan, 0.0);
    	
	    // convert camPosition into world-space and make it direction
	    O.camDist_ws = normalize( camera_pos - mul(pos4, worldMatrix) );
    	
	    // texture coords
	    O.texcoord0 = I.texcoord.xyyy;

    #ifdef S2_FOG
      // We've run out of TCs for SM 2.0 so we store our values in unused w coordinates
      float2 fog = getFogTCs( O.hposition.w, fog_data );
      O.lightDist_ts.w = fog.x;
      O.camDist_ts.w   = fog.y;
    #endif

	    return O;
    }

    fragout mainPS(pixdata  I,
        uniform sampler2D   texture0,
        uniform sampler2D   texture1,
        uniform sampler2D   texture2,
        uniform sampler2D   texture3,
        uniform sampler2D   shadow_texture,
        uniform sampler2D   fog_texture,
        uniform samplerCUBE textureCube,
        uniform float4      fog_color,
        uniform float4      light_col_amb,
        uniform float4      light_col_diff,
        uniform float4      pix_data_array[2] )
    {
	    fragout O;

      s2half4 tex3 = tex2D(texture3, I.texcoord0.xy);
      // Clip the skin if the item is not equipped but lying on the ground
      if( pix_data_array[0].x )
        clip( -tex3.a );

	    // get texture values
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	    s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));

      // adjust skin color
      //tex0.rgb = lerp( tex0.rgb, pix_data_array[1].rgb, tex3.a );
      tex0.rgb += pix_data_array[1].rgb * tex3.a;

	    // get shadow term from shadow texture
	    s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);
    	
	    // build matrix to tranform from tangent to world-space
	    float3x3 tangent_to_world;
	    tangent_to_world[0] = I.tan_to_wrld0.xyz;
	    tangent_to_world[1] = I.tan_to_wrld1.xyz;
	    tangent_to_world[2] = I.tan_to_wrld2.xyz;

	    // get normal vector from bumpmap texture
    //	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	    s2half3 nrm      = tex2;
	    s2half3 nrm_wrld = mul(nrm, tangent_to_world);

	    // lighting
	    s2half3 l_dir_ts = normalize(I.lightDist_ts.xyz);
	    s2half3 c_dir_ts = normalize(I.camDist_ts.xyz);
    #ifdef SM3_0
	      s2half3 c_dir_ws = normalize(I.camDist_ws.xyz);
    #else // we're short on instructions in SM2
        s2half3 c_dir_ws = I.camDist_ws.xyz;
    #endif

	    s2half3 half_vec_ts = normalize(c_dir_ts + l_dir_ts);

      // calc standard vars
	    s2half dot_l_n = dot(l_dir_ts, nrm);
	    s2half dot_c_n = dot(c_dir_ts, nrm);
	    s2half dot_hv_n = dot(half_vec_ts, nrm);
	    s2half dot_l_c = dot(l_dir_ts, c_dir_ts);

      // base shading
	    // calc sun diffuse
	    float3 diffuse = light_col_diff.xyz * tex0.rgb * saturate(dot_l_n);
      // calc moon diffuse
      float3 moon_diff = light_col_amb.xyz * tex0.rgb * (0.5 + saturate(dot_c_n));
      // calc glow
      float3 glow_amb = tex1.a * tex0;
	    // calc specular
	    float3 specular = light_col_diff.xyz * tex1.xyz * pow(saturate(dot_hv_n), 20);

      // skin shading
	    // calc sub-surface
	    s2half sublamb = smoothstep(-0.4, 1.0, dot_l_n) - smoothstep(0.0, 1.0, dot_l_n);
	    float3 subsurface = light_col_diff.xyz * tex3.xyz * tex0.xyz * saturate(sublamb);

      // compose base and skin shading
      float3 skin_color = glow_amb + moon_diff + shadow.z * subsurface;
      
      // ltx shading
	    s2half3 ltx_color = saturate(light_col_diff.xyz + light_col_amb.xyz) * tex1.xyz * texCUBE(textureCube, reflect(-c_dir_ws, nrm_wrld));
      

      float3 final_color = shadow.z * (diffuse + specular) + lerp(ltx_color, skin_color, tex3.a);
      float3 final_glow  = glow_amb;

    #ifdef S2_FOG
      float2 fog_tmp = { I.lightDist_ts.w, I.camDist_ts.w };
      fogDiffuse( final_color, fog_texture, fog_tmp, fog_color );
      fogGlow( final_glow, fog_texture, fog_tmp );
    #endif 

	    // compose color
	    O.col[0].xyz =  final_color;
	    O.col[0].a = tex0.a;
	    O.col[1] = float4(final_glow, tex0.a);
	    return O;
    } 
  #endif
#endif