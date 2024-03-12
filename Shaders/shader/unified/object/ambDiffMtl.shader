//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88

// metal

#define VERT_XVERTEX
#include "extractvalues.shader"


#ifdef SM1_1




  DEFINE_VERTEX_DATA


  struct pixdata {
	  float4 hposition    : POSITION;
	  float4 diffuse      : COLOR0;
	  float4 specular     : COLOR1;
	  float2 texcoord0    : TEXCOORD0;
	  float2 texcoord1    : TEXCOORD1;
    float fog    : FOG;
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

    O.fog = calcFog(O.hposition, fog_data);

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
    #include "itemPreviewStd.shader"
  #else //SPASS_ITEMPREVIEW

    #include "lighting.shader"
    #ifdef ENABLE_VERTEXLIGHTING
      #define VS_OUT_vertexLightData
    #endif

    struct pixdata {
      float4 hposition    : POSITION;
      float4 texcoord0    : TEXCOORD0;
      float4 camDist_ts   : TEXCOORD1;
      float4 lightDist    : TEXCOORD2;
      float4 screenCoord  : TEXCOORD3;
      float4 tan_to_wrld0 : TEXCOORD4;
      float4 tan_to_wrld1 : TEXCOORD5;
      float4 tan_to_wrld2 : TEXCOORD6;
      float4 camDist_ws   : TEXCOORD7;
    #ifdef VS_OUT_vertexLightData
      float4 vlColor      : COLOR0;
    #endif	    
    };

    struct fragout {
	    float4 col[2]      : COLOR;
    };

    pixdata mainVS(appdata I,
                   VS_PARAM_BLOCK)
    {
	    pixdata O;
    	
	    float4 pos4 = float4(I.position, 1.0);
	    float4 nrm4 = float4(I.normal, 0.0);

    #ifdef VS_OUT_vertexLightData
      O.vlColor = computeVertexLightingColor(pos4,nrm4);
    #endif 

	    // vertex pos
	    O.hposition = mul(pos4, worldViewProjMatrix);

	    // vertex-position in screen space
      O.screenCoord = calcScreenToTexCoord(O.hposition);

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
	    O.lightDist = float4(l0_dir_tan, 0.0);

	    // convert camera direction vector from worldspace to objectspace
	    float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	    // calc direction vector from vertex position to camera-position
	    c_dir_obj -= pos4;
	    // convert camera direction vector from objectspace to tangentspace
	    float3 c_dir_tan = mul(objToTangentSpace, c_dir_obj.xyz);
	    // store camera vec in texcoord2
	    O.camDist_ts = float4(c_dir_tan, 0.0);

	    // convert camPosition into world-space and make it direction
	    O.camDist_ws = camera_pos - mul(pos4, worldMatrix);

	    // texture coords
	    O.texcoord0 = I.texcoord.xyyy;

    #ifdef S2_FOG
      // We've run out of TCs for SM 2.0 so we store our values in unused w coordinates
      float2 fog = getFogTCs( O.hposition.w, fog_data );
      O.lightDist.w  = fog.x;
      O.camDist_ts.w = fog.y;
    #endif

	    return O;
    }

    fragout mainPS(pixdata I,
      uniform sampler2D   texture0,
      uniform sampler2D   texture1,
      uniform sampler2D   texture2,
      uniform sampler2D   shadow_texture,
      uniform sampler2D   fog_texture,
      uniform samplerCUBE textureCube,
      uniform float4      fog_color,
      uniform float4      light_col_amb,
      uniform float4      light_col_diff)
    {
	    fragout O;

	    // get texture values
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	    s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));

	    // get normal vector from bumpmap texture
    //	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	    s2half3 nrm      = tex2; 

    #ifdef VS_OUT_vertexLightData
      light_col_amb     += light_calc_heroLight(I.vlColor);
      light_col_amb.rgb += I.vlColor.rgb;
    #endif
	    // get shadow term from shadow texture
	    s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

	    // build matrix to tranform from tangent to world-space
	    float3x3 tangent_to_world;
	    tangent_to_world[0] = I.tan_to_wrld0.xyz;
	    tangent_to_world[1] = I.tan_to_wrld1.xyz;
	    tangent_to_world[2] = I.tan_to_wrld2.xyz;

	    s2half3 nrm_wrld = mul(nrm, tangent_to_world);

	    // lighting
	    s2half3 l_dir = normalize(I.lightDist.xyz);
	    s2half3 c_dir_ts = normalize(I.camDist_ts.xyz);
	    s2half3 c_dir_ws = normalize(I.camDist_ws.xyz);
	    s2half3 half_vec = normalize(c_dir_ts + l_dir);

	    // calc reflection
	    s2half3 env_color = saturate(light_col_diff.xyz + light_col_amb.xyz) * tex1.xyz * texCUBE(textureCube, reflect(-c_dir_ws, nrm_wrld));

	    // calc sun diffuse
	    float3 sun_diff = light_col_diff.xyz * tex0.rgb * saturate(dot(l_dir, nrm));

	    // calc moon diffuse
	    s2half moon_diff_f = 0.5 + saturate(dot(c_dir_ts, nrm));
	    float3 moon_diff = light_col_amb.xyz * moon_diff_f * tex0.xyz;
        
	    // calc glow
	    float3 glow_amb = tex1.a * tex0;

	    // calc specular
	    float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * tex1.xyz * light_col_diff.xyz;

	    // metal strength
	    s2half metal = tex2.a;

      float3 final_color = moon_diff + glow_amb + env_color + shadow.z * (sun_diff + specular);
      float3 final_glow  = 2.5 * metal * (glow_amb + shadow.z * specular);


    #ifdef S2_FOG
      float2 fog_tmp = { I.lightDist.w, I.camDist_ts.w };
      fogDiffuse( final_color, fog_texture, fog_tmp, fog_color );
      fogGlow( final_glow, fog_texture, fog_tmp );
    #endif

	    // set output color
	    O.col[0].rgb = final_color;
	    O.col[0].a = tex0.a;
	    O.col[1].rgb = final_glow;
	    O.col[1].a = tex0.a;

	    return O;
    } 
  #endif
#endif