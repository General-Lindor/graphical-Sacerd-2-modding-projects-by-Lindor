//#OptDef:S2_FOG
//#OptDef:SPASS_ITEMPREVIEW
//#OptDef:LAYER_BIT0
//#OptDef:LAYER_BIT1
//#OptDef:NORMALFORMAT_88

// glass

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
    #define ITEMPREVIEW_CFG_GLAS
    #include "itemPreviewStd.shader"

  #else //SPASS_ITEMPREVIEW

    struct pixdata {
	    float4 hposition   : POSITION;
	    float4 camDist     : TEXCOORD0;
	    float4 lightDist   : TEXCOORD1;
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
      uniform float4   fog_data
      )
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

	    // convert light direction vector from worldspace to objectspace
	    float4 l0_dir_obj = mul(light_pos, invWorldMatrix);
	    // convert light direction vector from objectspace to tangentspace
	    float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz);
	    // store light vector in texcoord3
	    O.lightDist = float4( l0_dir_tan, I.texcoord.y);

	    // convert camera direction vector from worldspace to objectspace
	    float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	    // calc direction vector from vertex position to camera-position
	    c_dir_obj -= pos4;
	    // convert camera direction vector from objectspace to tangentspace
	    float3 c_dir_tan = mul(objToTangentSpace, c_dir_obj.xyz);
	    // store camera vec in texcoord2
	    O.camDist = float4(c_dir_tan, I.texcoord.x);

	    return O;
    }

    fragout mainPS(pixdata   I,
                   float2    vPos           : VPOS,
           uniform sampler2D texture0,
           uniform sampler2D texture1,
           uniform sampler2D texture2,
           uniform sampler2D texture4,
           uniform sampler2D texture5,
           uniform sampler2D fog_texture,
           uniform float4    light_col_amb,
           uniform float4    light_col_diff)
    {
	    fragout O;
	    float surfaceZ = length(I.camDist.xyz);
	    s2half2 texcoord0 = s2half2( I.camDist.w, I.lightDist.w );
    	
	    // diffuse color & opacity from texture0
	    s2half4 tex0 = tex2D(texture0, texcoord0);
	    // specular color from texture1
	    s2half4 tex1 = tex2D(texture1, texcoord0);
    	
	    // refraction offset from bump-map
	    s2half4 nrm = decode_normal(tex2D(texture2, texcoord0));
    	
       // screenpos of this pixel, zw is refracted
      float4 scr_pos = RefractionOffsets(false, vPos.xy, surfaceZ / 2500, nrm.xy);

      // moved that to extractvalues.shader
// #ifdef XENON_IMPL       
//       float4 scr_pos = float4( tiling_data_half_tile.zw*vPos.xy,
//                                tiling_data_half_tile.zw*(vPos.xy + 2500*nrm.xy/surfaceZ) );
// #else
//       float4 scr_pos = float4( target_data.zw*vPos.xy,
//                                target_data.zw*(vPos.xy + 2500*nrm.xy/surfaceZ) );
// #endif
    	
      // transparency <-> opaque mask
      float depth = DEPTH_SAMPLE(texture5, scr_pos.zw).x;

	  // offset'ed background
	  s2half3 bgr = tex2D(texture4, (depth<surfaceZ) ? scr_pos.xy : scr_pos.zw );

      // lerp with opacity
      s2half3 amb = lerp(bgr, tex0.xyz, tex0.a);

      // lighting
	  s2half3 l_dir = normalize(I.lightDist.xyz);
	  s2half3 c_dir = normalize(I.camDist.xyz);
	  s2half3 half_vec = normalize(c_dir + l_dir);

      // calc specular
	    float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * tex1.xyz * light_col_diff.xyz;
#ifdef PS3_IMPL
      half3 final_color = amb + specular;
      half3 final_glow  = specular;
#else    	
      float3 final_color = amb + specular;
      float3 final_glow  = specular;
#endif

    #ifdef S2_FOG
//      fogDiffuse( final_color, fog_texture, I.depthFog, light_col_diff );
//      fogGlow( final_glow, fog_texture, I.depthFog );
    #endif

      // out
	    O.col[0] = float4(final_color, 1.0);
	    O.col[1] = float4(final_glow, 0.0);
    	
	    return O;
    } 
  #endif