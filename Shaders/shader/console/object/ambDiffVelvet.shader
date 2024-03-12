//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88

// velvet wihtout bump
#define VERT_XVERTEX
#include "extractvalues.shader"


#ifdef SM1_1

  DEFINE_VERTEX_DATA


  struct pixdata {
	  float4 hposition   : POSITION;
	  float4 diffuse     : COLOR0;
	  float4 specular    : COLOR1;
	  float4 texcoord0   : TEXCOORD0;
	  float4 texcoord1   : TEXCOORD1;
	  float4 normal      : TEXCOORD2;
	  //float4 lightDir    : TEXCOORD3;
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

  /*	// convert light direction vector from worldspace to objectspace
	  O.lightDir = mul(light_pos, invWorldMatrix);

	  // convert camera direction vector from worldspace to objectspace
	  float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	  // calc direction vector from vertex position to camera-position
	  c_dir_obj -= pos4;
	  // store camera vec in texcoord2
	  O.camDir = float4(c_dir_obj.xyz, 0.0);*/

	  // normal
	  O.normal = nrm4;

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
      uniform sampler2D texture1)
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
    #include "itemPreviewStd.shader"

  #else //SPASS_ITEMPREVIEW

    struct pixdata {
	    float4 hposition   : POSITION;
	    float4 texcoord0   : TEXCOORD0;
	    float4 camDir      : TEXCOORD1;
	    float4 lightDir    : TEXCOORD2;
	    float4 screenCoord : TEXCOORD3;
	    float4 normal      : TEXCOORD4;
    #ifdef S2_FOG
      float2 depthFog    : TEXCOORD5;
    #endif
    };

    struct fragout {
	    float4 col[2]      : COLOR;
    };

    pixdata mainVS(appdata I,
      uniform float4x4 worldViewProjMatrix,
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

    #ifdef S2_FOG
      O.depthFog = getFogTCs( O.hposition.w, fog_data );
    #endif

	    // vertex-position in screen space
	    O.screenCoord.x = O.hposition.w + O.hposition.x;
	    O.screenCoord.y = O.hposition.w - O.hposition.y;
	    O.screenCoord.z = 0.0;
	    O.screenCoord.w = 2.0 * O.hposition.w;
	    O.screenCoord.xy *= target_data.xy;

	    // convert light direction vector from worldspace to objectspace
	    O.lightDir = mul(light_pos, invWorldMatrix);

	    // convert camera direction vector from worldspace to objectspace
	    float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	    // calc direction vector from vertex position to camera-position
	    c_dir_obj -= pos4;
	    // store camera vec in texcoord2
	    O.camDir = float4(c_dir_obj.xyz, 0.0);

	    // normal
	    O.normal = nrm4;

	    // texture coords
	    O.texcoord0 = I.texcoord.xyyy;

	    return O;
    }

    fragout mainPS(pixdata I,
        float vFace : VFACE,
        uniform sampler2D texture0,
        uniform sampler2D texture1,
        uniform sampler2D shadow_texture,
        uniform sampler2D fog_texture,
        uniform float4    fog_color,
        uniform float4    light_col_amb,
        uniform float4    light_col_diff)
    {
	    fragout O;

	    // get texture values
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);

	    // get shadow term from shadow texture
	    s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

	    // lighting
	    s2half3 to_light = normalize(I.lightDir.xyz);
	    s2half3 to_cam = normalize(I.camDir.xyz);
	    s2half3 sf_nrm = normalize(I.normal.xyz);
    #ifdef SM3_0
	    if(vFace > 0.0)
		    sf_nrm *= -1.0;
    #endif

	    // retro-reflective lobe
	    s2half cosine = saturate(dot(to_light, to_cam));
	    float3 shiny = pow(cosine, 7.0) * 0.3 * light_col_diff.xyz * tex0;

	    // horizon scattering
	    cosine = saturate(dot(sf_nrm, to_cam));
	    s2half sine = sqrt(1.0 - cosine * cosine);
	    shiny += pow(sine, 5.0) * saturate(dot(to_light, sf_nrm)) * light_col_diff.xyz * tex0;

	    // specular
	    s2half3 half_vec = normalize(to_light + to_cam);
	    s2half3 specular = tex1.xyz * light_col_diff.xyz * pow(saturate(dot(half_vec, sf_nrm)), 10);

      // ambient
      s2half3 glow_amb = light_col_amb.xyz * tex0.xyz + tex1.a * tex0.xyz;

      s2half3 final_color = glow_amb + /*shadow.z * */(shiny + specular.xyz); // shadows not working: extreme acne thin polys!
      s2half3 final_glow  = tex1.a * tex0.xyz;

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
  