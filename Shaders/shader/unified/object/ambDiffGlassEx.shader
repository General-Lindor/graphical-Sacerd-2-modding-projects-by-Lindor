//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88

// glass

#define VERT_XVERTEX
#include "extractvalues.shader"

#ifdef SM1_1

  // glass
  DEFINE_VERTEX_DATA


  struct pixdata {
	  float4 hposition   : POSITION;
	  float4 diffuse     : COLOR0;
	  float4 specular    : COLOR1;
	  float2 texcoord0   : TEXCOORD0;
	  float2 texcoord1   : TEXCOORD1;
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
	  O.texcoord0 = uv0;
	  O.texcoord1 = uv0;

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
	  O.col.rgb = diffuse;
	  O.col.a = tex0.a;

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
    #define ITEMPREVIEW_CFG_GLAS
    #include "itemPreviewStd.shader"

  #else //SPASS_ITEMPREVIEW

    struct pixdata {
	    float4 hposition   :  POSITION;
	    float4 texcoord0   :  TEXCOORD0;
	    float4 screenCoord :  TEXCOORD1;
	    float4 camDist_ts  :  TEXCOORD2;
	    float4 camDist_ws  :  TEXCOORD3;
	    float4 lightDist   :  TEXCOORD4;
	    float4 tan_to_wrld0 : TEXCOORD5;
	    float4 tan_to_wrld1 : TEXCOORD6;
	    float4 tan_to_wrld2 : TEXCOORD7;
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
    	
	    // vertex pos
	    O.hposition = mul(pos4, worldViewProjMatrix);
    	
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
    	
	    // vertex-position in screen space
      O.screenCoord = calcScreenToTexCoord(O.hposition);

	    // convert light direction vector from worldspace to objectspace
	    float4 l0_dir_obj = mul(light_pos, invWorldMatrix);
	    // convert light direction vector from objectspace to tangentspace
	    float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz);
	    // store light vector in texcoord3
    #ifdef SM2_0
	    O.lightDist = float4(normalize(l0_dir_tan), 0.0);
    #else // SM3 normalizes in pixel shader
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
	    O.camDist_ts = float4(normalize(c_dir_tan), 0.0);
    #else // SM3 normalizes in pixel shader
      O.camDist_ts = float4(c_dir_tan, 0.0);
    #endif
    	
	    // convert camPosition into world-space and make it direction
	    O.camDist_ws = camera_pos - mul(pos4, worldMatrix);
    	
      // calc "horizon" per-vertex
      float horizon_strength = 1.0 - abs(dot(normalize(c_dir_obj.xyz), I.normal));
    	
	    // pass texture coords
	    O.texcoord0 = float4(I.texcoord.xy, horizon_strength, 0.0);

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
      uniform sampler2D   texture4,
      uniform sampler2D   texture5,
      uniform sampler2D   fog_texture,
      uniform samplerCUBE textureCube,
      uniform float4      fog_color,
      uniform float4      light_col_amb,
      uniform float4      light_col_diff)
    {
	    fragout O;
    	
	    // diffuse color & opacity from texture0
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    // specular color from texture1
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
    	
	    // build matrix to tranform from tangent to world-space
	    float3x3 tangent_to_world;
	    tangent_to_world[0] = I.tan_to_wrld0.xyz;
	    tangent_to_world[1] = I.tan_to_wrld1.xyz;
	    tangent_to_world[2] = I.tan_to_wrld2.xyz;
    	
	    // refraction offset from bump-map
	    s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));
	    // get out of half-space to -1..1
    //	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	    s2half3 nrm = tex2.xyz;
	    // need another "abgeschwaechte" normal! Abschwaechung comes from normalmap alpha
	    s2half3 nrm_redu = normalize(lerp(s2half3(0.0, 0.0, 1.0), nrm, tex2.a));
	    // convert from tangent to world
	    s2half3 nrm_redu_wrld = mul(nrm_redu, tangent_to_world);
    	
      // lighting
    #ifdef SM3_0
      s2half3 l_dir    = normalize(I.lightDist.xyz);
	    s2half3 c_dir_ts = normalize(I.camDist_ts.xyz);
    #else // keep arithmetic instructions below 64 instructions
      s2half3 l_dir    = I.lightDist.xyz;
	    s2half3 c_dir_ts = I.camDist_ts.xyz;
    #endif

	    s2half3 half_vec = normalize(c_dir_ts + l_dir);
      s2half3 c_dir_ws = normalize(I.camDist_ws.xyz);

	    // offset
	    float2 scr_offset = (I.screenCoord.z / I.screenCoord.w) * target_data.zw * nrm.xy;
	    // screenpos of this pixel
	    float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;
	    // offset due to refraction and distance!
	    float2 offs_scr_pos = scr_pos + 20.0 * scr_offset;
    	
	    // transparency <-> opaque mask
	    s2half4 t_mask = tex2D(texture5, offs_scr_pos);
    	
	    // offset'ed background
	    s2half4 offs_bgr = tex2D(texture4, offs_scr_pos);
	    // non-offset'ed background
	    s2half4 nonoffs_bgr = tex2D(texture4, scr_pos);
    	
	    // lerp with mask
	    s2half4 bgr = lerp(nonoffs_bgr, offs_bgr, t_mask.x);

      // lerp with opacity
      float3 ambdiff = light_col_amb.xyz + light_col_diff.xyz * saturate(dot(l_dir, nrm_redu));
      float3 final_color = lerp(bgr.xyz, tex0.xyz * ambdiff, saturate(tex0.a + pow(I.texcoord0.z, 2.0)));
      
	    // calc env reflection
	    s2half3 env_color = saturate(light_col_diff.xyz + light_col_amb.xyz) * tex1.xyz * texCUBE(textureCube, reflect(-c_dir_ws, nrm_redu_wrld));
	    // reduce env reflection
	    env_color *= 0.3;

      // calc specular
	    float3 specular = pow(saturate(dot(half_vec, nrm_redu)), 20) * tex1.xyz * light_col_diff.xyz;
    	
      float3 fin_color = env_color + final_color + specular;
      float3 final_glow  = specular;

    #ifdef S2_FOG
      float2 fog_tmp = { I.lightDist.w, I.camDist_ts.w };
      fogDiffuse( fin_color, fog_texture, fog_tmp, fog_color );
      fogGlow( final_glow, fog_texture, fog_tmp );
    #endif

      // out
	    O.col[0] = float4(fin_color, 1.0);
	    O.col[1] = float4(final_glow , 0.0);
    	
	    return O;
    } 
  #endif  
#endif
  