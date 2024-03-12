//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:SPASS_AMBDIFF
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88
//#OptDef:NORMALFORMAT_565
//#OptDef:IS_OPAQUE
//#OptDef:VERTEXLIGHTING_TEST
 
// cloth

#define VERT_XVERTEX
#include "extractvalues.shader"
#define LIGHTBLOCKS 4


#ifdef SM1_1


  DEFINE_VERTEX_DATA

  struct pixdata {
	  float4 hposition   : POSITION;
	  float4 diffuse     : COLOR0;
	  float4 specular    : COLOR1;
	  float2 texcoord0   : TEXCOORD0;
	  float2 texcoord1   : TEXCOORD1;
	  float2 texcoord2   : TEXCOORD2;
	  //float4 shadowUV    : TEXCOORD2;
	  //float3 lightRelPos : TEXCOORD3;
  #ifdef S2_FOG
    float fog    : FOG;
  #endif
  };

  struct fragout {
	  float4 col      : COLOR;
  };

  pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldMatrix,
    uniform float4   camera_pos,
    uniform lightData globLightData,
    uniform float4 fog_data)
  {
	  pixdata O;
  	
	  EXTRACT_VERTEX_VALUES;

	  // vertex pos
	  O.hposition = mul(pos4, worldViewProjMatrix);

	  float3 worldVertPos = mul(pos4, worldMatrix);
	  float3 worldVertNormal = normalize(mul(nrm4.xyz, (float3x3) worldMatrix));

	  O.diffuse = calcLight(worldVertPos, worldVertNormal, camera_pos, globLightData, O.specular);

	  // texture coords
	  O.texcoord0 = uv0.xy;
	  O.texcoord1 = uv0.xy;
	  O.texcoord2 = uv0.xy;

  #ifdef S2_FOG
    O.fog = calcFog(O.hposition, fog_data);
  #endif

	  return O;
  }

  fragout mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D texture1,
      uniform sampler2D texture3,
      uniform float4    pixParam )
  {
	  fragout O;

	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  s2half4 tex1 = tex2D(texture1, I.texcoord1.xy);

	  float3 glow_amb = tex1.a * tex0.rgb;
	  float3 diffuse = tex0.rgb * I.diffuse.rgb;
	  float3 spec = tex1.rgb * I.specular.rgb;

	  //O.col.rgb = glow_amb + diffuse + spec;
	  O.col.rgb = diffuse;
	  O.col.a = (pixParam.x && tex2D(texture3, I.texcoord2.xy).a ? 0.0f : tex0.a);

	  return O;
  } 

#else //SM1_1
  ////////////////////////////////////////////////////////////////
  // >SM20 code path
  ////////////////////////////////////////////////////////////////

  struct appdata {
	  float3 position    : POSITION;
	  float3 normal      : NORMAL;
	  float3 tangent     : TANGENT;
	  float3 binormal    : BINORMAL;
	  float2 texcoord    : TEXCOORD0;
	  float2 data        : TEXCOORD1;
  };


  #ifdef SPASS_ITEMPREVIEW
    //use the shared itempreview shader
    //setup shader config:
    #define ITEMPREVIEW_CFG_CLIPSKIN
    #include "itemPreviewStd.shader"
  #else
    #include "lighting.shader"
    #ifdef ENABLE_VERTEXLIGHTING
      #define VS_OUT_vertexLightData
    #endif

    struct pixdata {
	    float4 hposition   : POSITION;
	    float4 texcoord0   : TEXCOORD0;
	    float4 camDist     : TEXCOORD1;
	    float4 lightDist   : TEXCOORD2;
	    float4 screenCoord : TEXCOORD3;
      float2 depthFog    : TEXCOORD4;
    #ifdef VS_OUT_vertexLightData
      float4 vlColor     : COLOR0;
      float4 vlNormal    : TEXCOORD5;
    #endif
    };
    struct fragout {
	    s2half4 col[2]      : COLOR;
    };

    pixdata mainVS(appdata I, 
                   VS_PARAM_BLOCK)
    {
	    pixdata O;
    	
	    float4 pos4 = float4(I.position, 1.0);
	    float4 nrm4 = float4(I.normal, 0.0);

    #ifdef VS_OUT_vertexLightData
      computeVertexLightingColorNormal(O.vlColor,O.vlNormal,pos4);
    #endif
	    // vertex pos
	    O.hposition = mul(pos4, worldViewProjMatrix);

      O.depthFog = getFogTCs( O.hposition.w, fog_data );
      
	    // vertex-position in screen space
      O.screenCoord = calcScreenToTexCoord(O.hposition);

	    // build object-to-tangent space matrix
	    float3x3 objToTangentSpace;
	    objToTangentSpace[0] = -1.0 * I.tangent;
	    objToTangentSpace[1] = -1.0 * I.binormal;
	    objToTangentSpace[2] = I.normal;

    #ifdef VS_OUT_vertexLightData
      O.vlNormal = float4(mul( objToTangentSpace,O.vlNormal ),0);
    #endif
	    // convert light direction vector from worldspace to objectspace
	    float4 l0_dir_obj = mul(light_pos, invWorldMatrix);
	    // convert light direction vector from objectspace to tangentspace
	    float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz);
	    // store light vector in texcoord3
    #ifdef SM2_0
	    O.lightDist = float4(normalize(l0_dir_tan), 0.0);
    #else // SM3_0 normalizes in pixel shader
      O.lightDist = float4(l0_dir_tan, 0.0);
    #endif

	    // convert camera direction vector from worldspace to objectspace
	    float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	    // calc direction vector from vertex position to camera-position
	    c_dir_obj -= pos4;
	    // convert camera direction vector from objectspace to tangentspace
	    float3 c_dir_tan = mul(objToTangentSpace, c_dir_obj.xyz);
	    // store camera vec in texcoord2
    #ifdef SM2_0
      O.camDist = float4(normalize( c_dir_tan ), 0.0);
    #else
	    O.camDist = float4(c_dir_tan, 0.0);
    #endif

	    // texture coords
	    O.texcoord0 = I.texcoord.xyyy;

	    return O;
    }

    fragout mainPS(pixdata I,
        uniform sampler2D texture0,
        uniform sampler2D texture1,
        uniform sampler2D texture2,
        uniform sampler2D texture3,
        uniform sampler2D shadow_texture,
        uniform sampler2D fog_texture,
        uniform float4    fog_color,
        uniform float4    light_col_amb,
        uniform float4    light_col_diff,
        uniform float4    pix_data_array[2] )
    {
	    fragout O;

	    // get texture values
	    s2half4 tex3 = tex2D(texture3, I.texcoord0.xy);
      // if this item is not equipped then skip drawing the skin
      if( pix_data_array[0].x )  
        clip( - tex3.a );
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	    s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));

	    // get normal vector from bumpmap texture
    //	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	    s2half3 nrm = tex2;



    #ifdef VS_OUT_vertexLightData
      light_col_amb += light_calc_heroLight(I.vlColor);
      light_col_amb += light_calc_vertexlighting(nrm,I.vlColor,I.vlNormal);
    #endif

      // adjust skin color
      //tex0.rgb = lerp( tex0.rgb, pix_data_array[1].rgb, tex3.a );
      tex0.rgb += pix_data_array[1].rgb * tex3.a;

	    // get shadow term from shadow texture
	    s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

	    // lighting
    #ifdef SM3_0
	    s2half3 l_dir = normalize(I.lightDist.xyz);
      s2half3 c_dir = normalize(I.camDist.xyz);
    #else // needed to keep SM2_0 instructions below 64 instructions
      s2half3 l_dir = I.lightDist.xyz;
      s2half3 c_dir = I.camDist.xyz;
    #endif
	    s2half3 half_vec = normalize(c_dir + l_dir);

      // calc standard vars
	    s2half dot_l_n = dot(l_dir, nrm);
	    s2half dot_c_n = dot(c_dir, nrm);
	    s2half dot_hv_n = dot(half_vec, nrm);
	    s2half dot_l_c = dot(l_dir, c_dir);

      // base shading
	    // calc sun diffuse
	    float3 diffuse = light_col_diff.xyz * tex0.rgb * saturate(dot_l_n);
      // calc moon diffuse
      s2half3 moon_diff = light_col_amb.xyz * tex0.rgb * (0.5 + saturate(dot_c_n));
      // calc glow
      s2half3 glow_amb = tex1.a * tex0;
	    // calc specular
	    float3 specular = light_col_diff.xyz * tex1.xyz * pow(saturate(dot_hv_n), 20);

      // skin shading
	    // calc sub-surface
    #ifdef SM3_0
	    s2half sublamb = smoothstep(-0.4, 1.0, dot_l_n) - smoothstep(0.0, 1.0, dot_l_n);
    #else
      s2half sublamb = smoothstep(-0.4, 1.0, dot_l_n);
    #endif
	    float3 subsurface = light_col_diff.xyz * tex3.xyz * tex0.xyz * saturate(sublamb);

      // cloth shading
	    // retro-reflective lobe
	    s2half cosine = saturate(dot_l_c);
	    s2half3 shiny = pow(cosine, 7.0) * 0.3 * light_col_diff.xyz * tex0;
	    // horizon scattering
	    cosine = saturate(dot_c_n);
	    s2half sine = sqrt(1.0 - cosine * cosine);
	    shiny += pow(sine, 5.0) * saturate(dot_l_n) * light_col_diff.xyz * tex0;

      // compose base and skin shading
      s2half3 skin_color = diffuse + specular + subsurface;

      // compose base and cloth shading
    #ifdef SM3_0
      s2half3 cloth_color = 0.5 * diffuse + 1.5 * shiny + specular;
    #else
      s2half3 cloth_color = diffuse + specular;
    #endif

      s2half3 final_color = glow_amb + moon_diff + shadow.z * lerp(cloth_color, skin_color, tex3.a);
      s2half3 final_glow  = glow_amb;


    #ifdef S2_FOG
      fogDiffuse( final_color, fog_texture, I.depthFog, fog_color );
      fogGlow( final_glow, fog_texture, I.depthFog );
    #endif

	    // compose color
	    O.col[0].xyz = final_color;
	    O.col[0].a = tex0.a;
	    O.col[1] = float4(final_glow, tex0.a);
    	
	    return O;
    } 
  #endif  
#endif