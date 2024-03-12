//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88

// lava

#define VERT_XVERTEX
#include "extractvalues.shader"


#ifdef SM1_1


  DEFINE_VERTEX_DATA


  struct pixdata {
	  float4 hposition  : POSITION;
	  float4 texcoord   : TEXCOORD0;
  #ifdef S2_FOG
    float fog    : FOG;
  #endif
  };

  struct fragout {
	  float4 col      : COLOR;
  };

  pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4 fog_data)
  {
	  pixdata O;

	  // vertex pos
	  O.hposition = mul(float4(I.position, 1.0), worldViewProjMatrix);

	  // pass texture coords
	  O.texcoord = I.texcoord.xyyy;

  #ifdef S2_FOG
    O.fog = calcFog(O.hposition, fog_data);
  #endif

	  return O;
  }

  fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D texture1,
    uniform sampler2D texture2,
    uniform float4    system_data)
  {
	  fragout O;

  /*	float4 fnoise;
	  float rnd = 0.0;
	  float f = 1.0;
	  float2 coord = I.texcoord.xy + (system_data.xx * 0.015);
	  for(int i = 0; i < 4; i++)
	  {
		  fnoise = tex2D(texture2, coord * 0.2 * f);
		  fnoise -= 0.5;
		  fnoise *= 4.0;
		  rnd += fnoise.y / f;
		  f *= 4.17;	
	  }
  	    
	  coord = I.texcoord.xy - (system_data.xx * 0.015);
	  coord -= rnd * 0.02;
	  float4 tex = tex2D(texture1, coord);*/
  	
	  // lava color
	  float4 col = tex2D(texture0, I.texcoord.xy);

    // add terms to get final output
    //float3 final_col = tex.xyz * col.xyz * (rnd + 1.0) + 0.3 * col.xyz;
  	
	  // output
	  //O.col.xyz = final_col;
	  O.col.xyz = col.xyz;
	  O.col.a = 1.0;

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
	    float4 camDist     : TEXCOORD1;
	    float4 lightDist   : TEXCOORD2;
	    float4 screenCoord : TEXCOORD3;
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
      uniform float4    system_data,
      uniform float4    fog_color,
      uniform float4    light_col_amb,
      uniform float4    light_col_diff)
    {
	    fragout O;

      // get textures
	    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	    s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));

	    // get shadow term from shadow texture
	    s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

	    // get normal vector from bumpmap texture
    //	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	    s2half3 nrm = tex2;

      // lighting
	    s2half3 l_dir = normalize(I.lightDist.xyz);
	    s2half3 c_dir = normalize(I.camDist.xyz);
	    s2half3 half_vec = normalize(c_dir + l_dir);

	    // calc sun diffuse
	    s2half3 sun_diff = light_col_diff.xyz * tex0.rgb * saturate(dot(l_dir, nrm));

      // calc moon diffuse
      s2half3 moon_diff = light_col_amb.xyz * tex0.rgb * (0.5 + saturate(dot(c_dir, nrm)));

	    // calc specular
	    float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * tex1.xyz * light_col_diff.xyz;

	    // std color
      s2half4 std_color = s2half4(moon_diff + /*shadow.z * */(sun_diff + specular), tex0.a);
      s2half4 std_glow = s2half4(0.5 * /*shadow.z * */specular, 0.0);


      // calc lava
	    float fnoise;
	    float rnd = 0.0;
	    float f = 1.0;
	    float2 coord = I.texcoord0.xy + (system_data.xx * 0.015);
	    for(int i = 0; i < 4; i++)
	    {
		    fnoise = tex2D(texture3, coord * 0.2 * f).a;
		    fnoise -= 0.5;
		    fnoise *= 4.0;
		    rnd += fnoise / f;
		    f *= 4.17;	
	    }
	    coord = I.texcoord0.xy - (system_data.xx * 0.015);
	    coord -= rnd * 0.02;
	    s2half4 lava_noise = tex2D(texture3, coord);
    	
      // add terms to get final lava color
      s2half4 lava_color = s2half4(lava_noise.xyz * tex0.xyz * (rnd + 1.0) + 0.3 * tex0.xyz, tex0.a);
      s2half4 lava_glow = s2half4(saturate(lava_color - float3(0.9, 0.9, 0.9)), 0.0);
    	
      s2half4 final_color = lerp(std_color, lava_color, tex1.a);
      s2half4 final_glow  = lerp(std_glow, lava_glow, tex1.a);

    #ifdef S2_FOG
      fogDiffuse( final_color.xyz, fog_texture, I.depthFog, fog_color );
      fogGlow( final_glow.xyz, fog_texture, I.depthFog );
    #endif

	    // output
	    O.col[0] = final_color;
      O.col[1] = final_glow;

	    return O;
    } 

  #endif
#endif
  