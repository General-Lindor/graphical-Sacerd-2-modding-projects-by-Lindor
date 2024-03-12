//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88
//#OptDef:COLORVARIATIONS
//#OptDef:VERTEXLIGHTING_TEST

// cloth

#define VERT_XVERTEX
#include "extractvalues.shader"

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
      float2 stripeCoord   : TEXCOORD5;
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
 
		float2 xySin = float2(pos4.x, pos4.y);
		float xyLen = length(xySin);
		O.stripeCoord.x = xyLen / 30.0;
		O.stripeCoord.y = pos4.z / 5.0;
		float sinDef = sin(50.0 * param.x + (O.stripeCoord.y * 50.0)) * .25;

		float errorSin = param.y * 300.0;
		if((errorSin ) > pos4.z && (errorSin - param.z * 3.0 ) < pos4.z)
		 sinDef = -sinDef * 5.5 + 1.0;

		pos4.xy = xySin + float2(sinDef, sinDef);
	    // vertex pos
	    O.hposition = mul(pos4, worldViewProjMatrix);


      O.depthFog = getFogTCs( O.hposition.w, fog_data );

	    // vertex-position in screen space
	    // vertex-position in screen space
      O.screenCoord = calcScreenToTexCoord(O.hposition);

	    // build object-to-tangent space matrix
	    float3x3 objToTangentSpace;
	    objToTangentSpace[0] = -1.0 * I.tangent;
	    objToTangentSpace[1] = -1.0 * I.binormal;
	    objToTangentSpace[2] = I.normal;


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
        uniform sampler2D colvar_mask,
        uniform float4    pix_color_ramp[8],
        uniform float4    fog_color,
        uniform float4    light_col_amb,
        uniform float4    light_col_diff,
        uniform float4   param)
    {
	    fragout O;
	    float shimmer = abs(sin(param.x * 132.0)) / 4.0f + 0.45;
	    // get texture values
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	    s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));
	    s2half4 stripes = tex2D(texture3, I.stripeCoord.xy - s2half2(0, param.x / 5.0));
	    s2half noise = tex2D(texture3, I.texcoord0.xy * s2half2(5.0,  5.0) + s2half2(0.0 , param.y )).a / 3.5;

	    // get shadow term from shadow texture
	    float4 deferred_tex = tex2Dproj(shadow_texture, I.screenCoord);
	    s2half4 shadow      = deferred_tex.z;
	    float fog_intensity = deferred_tex.y;

	    // get normal vector from bumpmap texture
    //	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	    s2half3 nrm = tex2;

	    // lighting
	    s2half3 to_light = normalize(I.lightDist.xyz);
	    s2half3 to_cam = normalize(I.camDist.xyz);
    	
      // calc standard vars
	    s2half3 half_vec = normalize(to_light + to_cam);
	    s2half dot_l_n = dot(to_light, nrm);
	    s2half dot_c_n = dot(to_cam, nrm);
	    s2half dot_hv_n = dot(half_vec, nrm);
	    s2half dot_l_c = dot(to_light, to_cam);

	    // specular
	    float3 specular = tex1.xyz * light_col_diff.xyz * pow(saturate(dot_hv_n), 20);

      // ambient
      float3 glow_amb = light_col_amb.xyz * tex0.xyz + tex1.a * tex0.xyz;

      
	    // calc sun diffuse
	    float3 diffuse = light_col_diff.xyz * tex0.xyz * saturate(dot_l_n);


      float3 final_color = glow_amb + shadow.z * (0.5 * diffuse +  specular.xyz);


	    // compose color
	    half4 swCol = (final_color.x + final_color.z + final_color.y) * 3.4 + float4(0.0,0.0,0.15,0.0);
	    O.col[0].xyz = swCol * (stripes.x + 0.6) + noise;
	    O.col[0].a = shimmer;
	    O.col[1] = 0.17;//float4(final_glow, tex0.a);

	    return O;
    } 
  #endif
  