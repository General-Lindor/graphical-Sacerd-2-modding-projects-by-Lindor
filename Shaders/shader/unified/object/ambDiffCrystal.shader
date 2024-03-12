//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
// metal

#define VERT_XVERTEX
#include "extractvalues.shader"


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
  #endif
  


    #include "lighting.shader"

    struct fragout {
	    float4 col[2]      : COLOR;
    };


    fragout crystalShader(s2half4     tex0,
						  s2half4     tex1,
						  s2half3     nrm,
						  float4      texccord,
						  float4      light_col_amb,
						  float4      light_col_diff,
						  float4      color_reflect,
						  s2half	  shadowIntensity,
						  s2half      backlightIntensity,
						  float3x3    tangent_to_world,
						  s2half3	  l_dir,		
						  s2half3	  c_dir_ts)
    {
	    fragout O;
	    s2half3 half_vec = normalize(c_dir_ts + l_dir);


		float4 tex0_diff = light_col_diff*tex0;
	    // calc sun diffuse
	    float4 sun_diff = tex0_diff * saturate(dot(l_dir, nrm));

	    // calc moon diffuse
	    float moon_diff_f = 0.5 + saturate(dot(c_dir_ts, nrm));
	    float3 moon_diff = light_col_amb.xyz * moon_diff_f * tex0.xyz;

	    // calc specular
	    float fact_spec = pow(saturate(dot(half_vec, nrm)), 20);
	    float4 specular = tex0_diff * fact_spec * tex1.b;
	    

	    float dot_cam_nrm      = dot(c_dir_ts, nrm);
	    float dot_cam_nrm_inv  = 1-dot_cam_nrm;
	    float fact_ice         = dot_cam_nrm*tex1.g;
	    float fact_ice_inv     = 1-fact_ice;
	    float fact_glow        = tex1.a;

	    float fact_back        = dot_cam_nrm_inv*dot_cam_nrm_inv*dot_cam_nrm_inv;
		float4 backlight       = saturate(tex0_diff*4 )* fact_back;


	    float ref_fact         = tex1.r;
	    
	    backlight             = backlight*2*shadowIntensity*tex1.b;
	    
	    float4 color_diff    = shadowIntensity*(sun_diff+specular);
	    float4 color_base    = float4(color_diff+moon_diff,1);
	    float4 color_blue    = color_base*float4(0.7,0.8,1.0,1.0);
	    float4 color_ice	 = color_blue;
	    
	    float4 final_color;
	    
	    final_color = lerp(color_ice,color_reflect,ref_fact);
	    final_color = lerp(color_base,final_color,fact_ice);
	    
	    final_color += backlight*backlightIntensity;
	    
	    O.col[0] = final_color; 
	    O.col[1] = final_color*fact_glow;

		return O;
    }

#ifdef SPASS_AMBDIF  
	#define USE_LOCAL_VS
    
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
    #ifdef VS_OUT_vertexLightData
      float4 vlColor      : COLOR0;
    #endif	    
    };
    


    fragout mainPS(pixdata I,
      uniform sampler2D   texture0,
      uniform sampler2D   texture1,
      uniform sampler2D   texture2,
      uniform sampler2D   texture4,
      uniform sampler2D   shadow_texture,
      uniform sampler2D   fog_texture,
      uniform samplerCUBE textureCube,
      uniform float4      fog_color,
      uniform float4      light_col_amb,
      uniform float4      light_col_diff)
    {
	    fragout O;
	    
    #ifdef VS_OUT_vertexLightData
        light_col_amb     += light_calc_heroLight(I.vlColor);
        light_col_amb.rgb += I.vlColor.rgb;
    #endif
	    // get texture values
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	    s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));
	    // get shadow term from shadow texture
	    s2half4 deferred_tex = tex2Dproj(shadow_texture, I.screenCoord);
	    // build matrix to tranform from tangent to world-space
	    float3x3 tangent_to_world;
	    tangent_to_world[0] = I.tan_to_wrld0.xyz;
	    tangent_to_world[1] = I.tan_to_wrld1.xyz;
	    tangent_to_world[2] = I.tan_to_wrld2.xyz;
	    // lighting
	    s2half3 l_dir    = normalize(I.lightDist.xyz);
	    s2half3 c_dir_ts = normalize(I.camDist_ts.xyz);
//	    s2half3 c_dir_ws = normalize(I.camDist_ws.xyz);
	    s2half3 c_dir_ws = mul(c_dir_ts, tangent_to_world);
	    // get normal vector from bumpmap texture
	    s2half3 nrm           = tex2; 
#ifdef SM3_0
	    s2half3 nrm_wrld      = mul(nrm, tangent_to_world);
#else
	    s2half3 nrm_wrld      = mul(float3(0,0,1), tangent_to_world);
#endif
		float4 uvoff          = float4(reflect(-c_dir_ws, nrm_wrld),0);
		uvoff                *= float4(1,0.2,0,0);
	    float4 color_reflect  = tex2Dproj(texture4, I.screenCoord+uvoff*0.4*I.screenCoord.w);

	    s2half shadow_intensity = deferred_tex.z;

	    O = crystalShader(tex0,
						  tex1,
						  nrm,
						  I.texcoord0,
						  light_col_amb, 
						  light_col_diff,
						  color_reflect,
						  shadow_intensity,
						  1,
						  tangent_to_world,
						  l_dir,
						  c_dir_ts);

#ifdef S2_FOG
      s2half fog_intensity = deferred_tex.y;
		  O.col[0].xyz  = lerp(fog_color.xyz, O.col[0], fog_intensity);
		  O.col[1]     *= fog_intensity;
#endif
	    return O;
    } 

#endif

#ifdef SPASS_PNT
	#define USE_LOCAL_VS
	#define USE_PNT_LIGHTVEC

    struct pixdata {
      float4 hposition    : POSITION;
      float4 texcoord0    : TEXCOORD0;
      float4 camDist_ts   : TEXCOORD1;
      float4 lightDist    : TEXCOORD2;
      float4 screenCoord  : TEXCOORD3;
      float4 tan_to_wrld0 : TEXCOORD4;
      float4 tan_to_wrld1 : TEXCOORD5;
      float4 tan_to_wrld2 : TEXCOORD6;
      float4 li_to_pix_w  : TEXCOORD7;
    #ifdef VS_OUT_vertexLightData
      float4 vlColor      : COLOR0;
    #endif	    
    };

    fragout mainPS(pixdata I,
      uniform sampler2D   texture0,
      uniform sampler2D   texture1,
      uniform sampler2D   texture2,
      uniform sampler2D   texture4,
      uniform sampler2D   shadow_texture,
      uniform sampler2D   fog_texture,
      uniform samplerCUBE textureCube,
      uniform float4      fog_color,
	  uniform float4      light_data,
      uniform float4      light_col_amb,
      uniform float4      light_col_diff)
    {
	    fragout O;
	    
	    // get texture values
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	    s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));
	    // get shadow term from shadow texture
	    s2half4 deferred_tex = tex2Dproj(shadow_texture, I.screenCoord);
	    // build matrix to tranform from tangent to world-space
	    float3x3 tangent_to_world;
	    tangent_to_world[0] = I.tan_to_wrld0.xyz;
	    tangent_to_world[1] = I.tan_to_wrld1.xyz;
	    tangent_to_world[2] = I.tan_to_wrld2.xyz;
	    // lighting
	    s2half3 l_dir    = normalize(I.lightDist.xyz);
	    s2half3 c_dir_ts = normalize(I.camDist_ts.xyz);
//	    s2half3 c_dir_ws = normalize(I.camDist_ws.xyz);
	    // get normal vector from bumpmap texture
	    s2half3 nrm           = tex2; 

#ifdef NO_SHADOWS
	    s2half shadow_intensity = 1;
#else
	    s2half shadow_intensity = calcPntFadeShadow(textureCube, light_data.z * I.li_to_pix_w.xzy,light_data.w);
#endif	

	    O = crystalShader(tex0,
						  tex1,
						  nrm,
						  I.texcoord0,
						  float4(0,0,0,0), 
						  light_col_diff,
						  float4(0,0,0,0),
						  shadow_intensity,
						  0,
						  tangent_to_world,
						  l_dir,
						  c_dir_ts);
		
#ifdef S2_FOG
    s2half fog_intensity    = deferred_tex.y;
		O.col[0].xyz *= fog_intensity;
		O.col[1]     *= fog_intensity;
#endif
	    return O;
    } 

#endif


#ifdef USE_LOCAL_VS
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

		#ifdef USE_PNT_LIGHTVEC
			// build vector from vertex pos to light pos
			l0_dir_obj.xyz    = l0_dir_obj.xyz - pos4.xyz;
		#endif


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

		// convert vertex-pos from object to worldspace
		float4 v_pos_w = mul(pos4, worldMatrix);

	    // convert camPosition into world-space and make it direction
//	    O.camDist_ws = camera_pos - v_pos_w;

	    // texture coords
	    O.texcoord0 = I.texcoord.xyyy;

		#ifdef USE_PNT_LIGHTVEC
			O.li_to_pix_w = v_pos_w - light_pos;
		#endif

    #ifdef S2_FOG
      // We've run out of TCs for SM 2.0 so we store our values in unused w coordinates
      float2 fog = getFogTCs( O.hposition.w, fog_data );
      O.lightDist.w  = fog.x;
      O.camDist_ts.w = fog.y;
    #endif

	    return O;
    }

  #endif
