//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:SPASS_AMBDIF

// glass for displays!

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
	    float4 hposition   : POSITION;
	    float4 texcoord0   : TEXCOORD0;
	    float4 screenCoord : TEXCOORD1;
	    float4 camDist     : TEXCOORD2;
	    float4 lightDist   : TEXCOORD3;
    #ifdef S2_FOG
      float2 depthFog    : TEXCOORD4;
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
    	
	    // vertex pos
	    O.hposition = mul(pos4, worldViewProjMatrix);
    	
    #ifdef S2_FOG 
      O.depthFog = getFogTCs( O.hposition.w, fog_data );
    #endif

	    // build object-to-tangent space matrix
	    float3x3 objToTangentSpace;
	    objToTangentSpace[0] = -1.0 * I.tangent;
	    objToTangentSpace[1] = -1.0 * I.binormal;
	    objToTangentSpace[2] = I.normal;
    	
	    // vertex-position in screen space
      O.screenCoord = calcScreenToTexCoord(O.hposition);

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
	    O.camDist = float4(c_dir_tan, 0.0);
    	
	    // pass texture coords
	    O.texcoord0 = I.texcoord.xyyy;

	    return O;
    }

    fragout mainPS(pixdata I,
      uniform sampler2D   texture0,
      uniform sampler2D   texture1,
      uniform sampler2D   texture2,
      uniform sampler2D   texture4,
      uniform sampler2D   fog_texture,
      uniform float4      fog_color,
      uniform float4      system_data,
      uniform float4      light_col_amb,
      uniform float4      light_col_diff)
    {
	    fragout O;
    	
	    // give usefull names
	    float time = system_data.x;
    	
	    // diffuse color & opacity from texture0
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    // specular color from texture1
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	    
	    // uv-shifted "overlay" texture
	    s2half4 tex2 = tex2D(texture2, 3.0 * I.texcoord0.xy + 0.4 * float2(0.0, time));
	    
	    // normal is always sonst
	    s2half3 nrm = s2half3(0.0, 0.0, 1.0);
    	
	    // screenpos of this pixel
	    float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;
    	
	    // background
	    s2half4 bgr = tex2D(texture4, scr_pos);
    	
      // lerp with opacity
      float3 amb = lerp(bgr.xyz, tex0.xyz, tex0.a);
      
      // calc "overlay" part
      float3 overlay = tex1.xyz * tex2.xyz;

      // lighting
	    s2half3 l_dir = normalize(I.lightDist.xyz);
	    s2half3 c_dir = normalize(I.camDist.xyz);
	    s2half3 half_vec = normalize(c_dir + l_dir);

      // calc specular
	    float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * light_col_diff.xyz;
    	
      float3 final_color = amb + specular + overlay;
      float3 final_glow  = 100.0 * overlay;

    #ifdef S2_FOG
        fogDiffuse( final_color, fog_texture, I.depthFog, fog_color );
        fogGlow( final_glow, fog_texture, I.depthFog );
    #endif

      // out
	    O.col[0] = float4(final_color, 1.0);
	    O.col[1] = float4(final_glow, 0.0);
    	
	    return O;
    } 
  #endif  
#endif