//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88
//#OptDef:SPASS_AMBDIF

// standard
#define VERT_XVERTEX
#include "extractvalues.shader"

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


  #ifdef SPASS_ITEMPREVIEW
    //use the shared itempreview shader
    //setup shader config:
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
    #ifdef S2_FOG
      float2 depthFog    : TEXCOORD4;
    #endif
    #ifdef VS_OUT_vertexLightData
      float4 vlColor     : COLOR0;
      float4 vlNormal    : TEXCOORD5;
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

    #ifdef VS_OUT_vertexLightData
      computeVertexLightingColorNormal(O.vlColor,O.vlNormal,pos4);
    #endif 

	    // vertex pos
	    O.hposition = mul(pos4, worldViewProjMatrix);

    #ifdef S2_FOG
      O.depthFog = getFogTCs( O.hposition.w, fog_data );
    #endif

	    // vertex-position in screen space
      O.screenCoord = calcScreenToTexCoord(O.hposition);

	    // build object-to-tangent space matrix
	    float3x3 objToTangentSpace;
	    objToTangentSpace[0] = -1.0 * I.tangent;
	    objToTangentSpace[1] = -1.0 * I.binormal;
	    objToTangentSpace[2] = I.normal;

    #ifdef VS_OUT_vertexLightData
	    O.vlNormal.xyz = mul(objToTangentSpace, O.vlNormal.xyz);
    #endif 

	    // convert light direction vector from worldspace to objectspace
	    float4 l0_dir_obj = mul(light_pos, invWorldMatrix);
	    // convert light direction vector from objectspace to tangentspace
	    float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz);
	    // store light vector in texcoord3
	    O.lightDist = float4(l0_dir_tan, 0.0);

	    // convert camera direction vector from worldspace to objectspace
	    float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
    #ifndef MINIMAPMODE
	    // calc direction vector from vertex position to camera-position
	    c_dir_obj -= pos4;
    #endif
	    // convert camera direction vector from objectspace to tangentspace
	    float3 c_dir_tan = mul(objToTangentSpace, c_dir_obj.xyz);
	    // store camera vec in texcoord2
	    O.camDist = float4(c_dir_tan, 0.0);

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
        uniform float4    system_data,
        uniform float4      fog_color,
        uniform float4    light_col_amb,
        uniform float4    light_col_diff)
    {
	    fragout O;
	    // give usefull names
	    float time = system_data.x;
    	
	    // get texture values
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	    s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));
	    s2half4 tex3 = tex2D(texture3, I.texcoord0.xy);
	    

	    // get normal vector from bumpmap texture
    //	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	    s2half3 nrm = tex2; 

    #ifdef VS_OUT_vertexLightData
      light_col_amb     += light_calc_heroLight(I.vlColor);
      light_col_amb     += light_calc_vertexlighting(nrm,I.vlColor,I.vlNormal);
    #endif


	    // get shadow term from shadow texture
	    s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);


      // lighting
	    s2half3 l0_dir = normalize(I.lightDist.xyz);
	    s2half3 c_dir = normalize(I.camDist.xyz);
	    s2half3 half_vec = normalize(c_dir + l0_dir);

	    // calc sun diffuse
	    float3 sun_diff = light_col_diff.xyz * tex0.rgb * saturate(dot(l0_dir, nrm));

      // calc moon diffuse
      float3 moon_diff = light_col_amb.xyz * tex0.rgb * (0.5 + saturate(dot(c_dir, nrm)));

      // calc glow
      float3 glow_amb = tex1.a * tex0;

	    // calc specular
	    float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * tex1.xyz * light_col_diff.xyz;
	    
	    // calc on/off value from time
	    float3 wave_desc = float3(1.0, 10.0, 10.0) * tex3.xyz;
	    float pulse_delay = wave_desc.x;
	    float pulse_length_on = wave_desc.y;
	    float pulse_length_off = wave_desc.z;
	    float on_off = step((pulse_length_on + pulse_length_off) * frac(pulse_delay + time), pulse_length_on);
	    
	    glow_amb *= on_off;

      float3 final_color = glow_amb + moon_diff + shadow.z * (sun_diff + specular);
      float3 final_glow  = 0.5 * shadow.z * specular + glow_amb;



    #ifdef S2_FOG
      fogDiffuse( final_color, fog_texture, I.depthFog, fog_color );
      fogGlow( final_glow, fog_texture, I.depthFog );
    #endif

        
      // set output color
	    O.col[0].rgb = final_color;
	    O.col[0].a = tex0.a;
	    O.col[1].rgb = final_glow;
	    O.col[1].a = tex0.a;



	    return O;
    } 

  #endif  
