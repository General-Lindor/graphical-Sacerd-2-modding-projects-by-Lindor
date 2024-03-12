// speedTree tree z
#include "lighting.shader"


/////////////////////////////////////
// SPASS_G setup
/////////////////////////////////////
#ifdef SPASS_G
  #if defined(SM1_1)
    #define PS_SPASS_G_11
  #else
    #define PS_SPASS_G_20 
  #endif
#endif
/////////////////////////////////////
// SPASS_SHADOWMAP setup
/////////////////////////////////////
#ifdef SPASS_SHADOWMAP
  #define PS_SPASS_SHADOWMAP
#endif
/////////////////////////////////////
// SPASS_CUBESHADOWMAP setup
/////////////////////////////////////
#ifdef SPASS_CUBESHADOWMAP
  #if defined(SM1_1)
    #define PS_DUMMY_11
  #else
    #define PS_SPASS_CUBESHADOWMAP_20
  #endif
#endif

#ifdef LAYER_BIT1
  #define USE_TENERGY
#endif


//Inputs:
//vpos screen space position  (-1 till 1)
//param  x=opacity, y=horz-shift
float calcHoleAlpha(float4 vpos,float4 param)
{
  float opacity   = param.x;
  float horz_disp = param.y;
  vpos /= vpos.w;
  vpos.x -= horz_disp;
  float fact = vpos.x*vpos.x+vpos.y*vpos.y;
  fact = fact*fact*fact*fact;
  return fact + opacity;
}

////////////////////////////////////////////////////////////////
//SPASS_G pixel shader (>=SM2_0)
////////////////////////////////////////////////////////////////
#ifdef PS_SPASS_G_20
  struct pixdata {
    float4 hposition  : POSITION;
    float4 texcoord0  : TEXCOORD0;
    float4 depthUV    : TEXCOORD1;
  };
  #define VS_OUT_depthUV
  #define VS_OUT_hposition

  fragout1 mainPS(pixdata I,
                  float2 vPos : VPOS,
                  uniform sampler2D texture0,
                  uniform sampler2D shadow_map,
                  uniform sampler3D textureVolume,
                  uniform int anzIterations,
                  uniform float4 shadow_data,
                  uniform sampler2D gradient_texture)
  {
	  fragout1 O;
#ifndef IS_OPAQUE
    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
    clip(tex0.a-0.5f);
#endif
  	O.col        = float4(I.depthUV.w,0,0,1);
	  return O;
  } 
#endif

////////////////////////////////////////////////////////////////
//SPASS_G pixel shader (SM1_1)
////////////////////////////////////////////////////////////////
#ifdef PS_SPASS_G_11
  struct pixdata {
    float4 hposition  : POSITION;
    float4 texcoord0  : TEXCOORD0;
    float4 depthUV    : TEXCOORD1;
    float4 posInLight : TEXCOORD2;
    float fog        : FOG;
  };
  #define VS_OUT_lowendFog
  #define VS_OUT_depthUV
  #define VS_OUT_posInLight
  #define VS_OUT_hposition


  fragout1 mainPS(pixdata I,
                  uniform sampler2D texture0,
                  uniform sampler2D shadow_map,
                  uniform sampler3D textureVolume,
                  uniform int anzIterations,
                  uniform float4 shadow_data,
                  uniform sampler2D gradient_texture)
  {
    fragout1 O;
  #ifdef IS_OPAQUE 
    O.col = float4( 0,0,0,1 );
  #else
    O.col = tex2D(texture0, I.texcoord0.xy);
  #endif
    return O;
  } 
#endif


////////////////////////////////////////////////////////////////
//SPASS_SHADOWMAP pixel shader (unified)
////////////////////////////////////////////////////////////////
#ifdef PS_SPASS_SHADOWMAP
  struct pixdata {
    float4 posInLight : POSITION;
    float4 texcoord0  : TEXCOORD0;
  };
  #define VS_OUT_posInLight

  fragout1 mainPS(pixdata I,
                  uniform sampler2D texture0,
                  uniform float4 shadow_data)
  {
    fragout1 O;
#if defined(SM1_1)
    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
    O.col.rgb = shadow_data.zzz;
    O.col.a = tex0.a;
#else
  #ifdef IS_OPAQUE 
    O.col = float4( 0,0,0,1 );
  #else
    O.col = tex2D(texture0, I.texcoord0.xy);
    clip(O.col.a-0.5f);
  #endif
#endif
    return O;
  } 
#endif

////////////////////////////////////////////////////////////////
//SPASS_CUBEMAPSHADOW pixel shader (>=SM2_0)
////////////////////////////////////////////////////////////////
#ifdef PS_SPASS_CUBESHADOWMAP_20
  struct pixdata {
    float4 posInLight  : POSITION;
    float4 texcoord0   : TEXCOORD0;
	  float4 li_to_pix_w : TEXCOORD1;
  };
  #define VS_OUT_li_to_pix_w
  #define VS_OUT_posInLight

  fragout1 mainPS(pixdata I,
                  uniform sampler2D texture0,
                  uniform float4    light_data)
  {
	  fragout1 O;
	  // need opacity-channel, since this is shadowmapping!
	  float4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  // square distance of scaled
	  float3 li_to_pix_w_s = light_data.z * I.li_to_pix_w.xyz;
	  float sq_dist = saturate(dot(li_to_pix_w_s, li_to_pix_w_s));
	  // endcode it in rgb!!
	  float3 depth_encoded = sq_dist * float3(1.0, 256.f, 256.f * 256.f);
	  // do not put the .x component through the frac, this gives 0.0 for 1.0 -> ERRORs
	  depth_encoded.yz = frac(depth_encoded.yz);
	  // pass it to texture
	  O.col = float4(depth_encoded, tex0.a);
	  return O;
  } 
#endif



/////////////////////////////////////////////////
//SPASS_AMBDIF pixel shader (SM1_1)
/////////////////////////////////////////////////
#ifdef PS_SPASS_AMBDIF_NONORMAL_11
  struct pixdata {
    float4 hposition   : POSITION;
    float4 diffuse     : COLOR0;
    float4 specular    : COLOR1;
    float4 texcoord0   : TEXCOORD0;
    float fog           : FOG;
  };
  #define VS_OUT_lowendFog
  #define VS_OUT_hposition
  #define VS_OUT_SM1_LIGHTING

  fragout1 mainPS(pixdata I,
      uniform sampler2D texture0)
  {
	  fragout1 O;

	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

	  O.col.rgb = tex0.rgb * I.diffuse.rgb;
	  O.col.a = tex0.a;
  #if LAYER_BIT0
      //O.col.a = tex0.a * calcHoleAlpha(I.hpos);
  #endif  

	  return O;
  } 
#endif//


    //#ifdef PS_SIMPLESHADOW
    //  s2half shadow = calcShadowSimple(shadow_map, textureVolume, I.posInLight, vPos, shadow_data.y, shadow_data.x);
    //#else
    //  s2half shadow = calcShadow(shadow_map, textureVolume, I.posInLight, vPos, shadow_data.y, shadow_data.x, anzIterations);
    //#endif
/////////////////////////////////////////////////
//SPASS_AMBDIF pixel shader (>=SM2_0)
/////////////////////////////////////////////////
#ifdef PS_SPASS_AMBDIF_NONORMAL_20 
  #define VS_OUT_hposition
  #define VS_OUT_diffuse
  #define VS_OUT_hpos
  #define VS_OUT_screenCoord
  #define VS_OUT_depthFog
  #ifdef ENABLE_VERTEXLIGHTING
    #define VS_OUT_vertexLightData_nonrm
  #endif

  struct pixdata {
    float4 hposition   : POSITION;
    float4 diffuse     : COLOR0;
    float4 texcoord0   : TEXCOORD0;
    float4 hpos        : TEXCOORD1;
    float4 screenCoord : TEXCOORD2;
    float2 depthFog    : TEXCOORD3;
    #ifdef VS_OUT_vertexLightData_nonrm
      float4 vlColor           : COLOR1;
    #endif
    
  };

  fragout2 mainPS(pixdata I,
                  uniform sampler2D texture0,
                  uniform sampler2D shadow_map,
                  uniform sampler3D textureVolume,
                  uniform sampler2D shadow_texture,
                  uniform sampler2D fog_texture,
                  uniform int       anzIterations,
                  uniform float4    shadow_data,
                  uniform float4    fog_color,
                  uniform float4    light_col_amb,
                  uniform float4    light_col_diff,
                  uniform float4    param)
                  
  {
	  fragout2 O;
	  // get texture values
	  s2half4 tex0  = tex2D(texture0, I.texcoord0.xy);
	    
  #ifdef VS_OUT_vertexLightData
    light_col_amb     += light_calc_heroLight(I.vlColor);
  #endif
  #ifdef VS_OUT_vertexLightData_nonrm
    light_col_amb.rgb += I.vlColor.rgb;
  #endif

    float4 deferred_tex     = tex2Dproj(shadow_texture, I.screenCoord);
    // calc sun diffuse
    float3 sun_diff = I.diffuse.xyz * light_col_diff.xyz * tex0.xyz;

    // calc ambient
    float3 amb = light_col_amb.xyz * tex0.xyz;

/*
  #ifndef NO_SHADOWS
    #ifdef PS_SIMPLESHADOW
      s2half shadow = calcShadowSimple(shadow_map, textureVolume, I.posInLight, vPos, shadow_data.y, shadow_data.x);
    #else
      s2half shadow = calcShadow(shadow_map, textureVolume, I.posInLight, vPos, shadow_data.y, shadow_data.x, anzIterations);
    #endif
    sun_diff *= shadow;
  #endif
*/
  #ifndef NO_SHADOWS
    sun_diff *= deferred_tex.z;
  #endif 

    float3 new_color = amb + sun_diff; 

  #ifdef S2_FOG
    // calc fog
    fogDiffuse( new_color, fog_texture, I.depthFog, fog_color );
  #endif

	  // calc only diffuse
	  O.col[0].xyz = new_color;
	  O.col[0].a = tex0.a;
  #if TREE_HOLE
      O.col[0].a = calcHoleAlpha(I.hpos,param);
  #endif  
	  O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
#ifdef SIMPLECOLOR
	  O.col[0] = tex0;
	  O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
#endif
	  return O;
  } 
#endif


/////////////////////////////////////////////////
//SPASS_PNT pixel shader (>=SM2_0)
/////////////////////////////////////////////////
#ifdef PS_SPASS_PNT_NONORMAL_20
  struct pixdata {
    float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float4 pix_to_li   : TEXCOORD1;
    float4 normal      : TEXCOORD2;
    float4 hpos        : TEXCOORD3;
    float2 depthFog    : TEXCOORD4;
  };
  #define VS_OUT_hposition
  #define VS_OUT_pix_to_li
  #define VS_OUT_NORMAL
  #define VS_OUT_hpos
  #define VS_OUT_depthFog

  fragout2 mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D fog_texture,
      uniform float4 light_col_diff,
      uniform float4 light_data,
      uniform float4    param)
  {
	  fragout2 O;

	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

	  // get normal vector from bumpmap texture
	  s2half3 nrm = normalize(I.normal.xyz);

	  // calc diffuse
	  s2half3 l0_dir = normalize(I.pix_to_li.xyz);
	  float4 diffuse = saturate(dot(l0_dir, nrm)) * light_col_diff;

	  // calc distance of light
	  float dist_to_light = dot(I.pix_to_li.xyz, I.pix_to_li.xyz);
	  // build intensity from distance to light using light radius
	  float temp_dist = saturate(dist_to_light  * light_data.z * light_data.z);
	  float intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
	  // multiply it by intensity of ight source
	  intensity *= light_data.y;
  #ifdef S2_FOG
    // attenuate by fog
    fogPnt( intensity, fog_texture, I.depthFog );
    //intensity *= (1.0 - tex2D( fog_texture, I.depthFog ).w);
  #endif

  #if TREE_HOLE
	  intensity *= calcHoleAlpha(I.hpos,param);
  #endif
	  O.col[0] = intensity * diffuse * tex0;
	  O.col[0].a = tex0.a;
	  O.col[1] = float4(0.0, 0.0, 0.0, 0.0);

	  return O;
  } 
#endif


/////////////////////////////////////////////////
//PS_SPASS_LIGHTNING pixel shader (>=SM2_0)
/////////////////////////////////////////////////
#ifdef PS_SPASS_LIGHTNING_NONORMAL_20
  struct pixdata {
    float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float4 lightDist   : TEXCOORD1;
    float2 depthFog    : TEXCOORD2;
  };
  #define VS_OUT_hposition
  #define VS_OUT_lightDist
  #define VS_OUT_depthFog

  fragout2 mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D fog_texture,
      uniform float4    light_col_amb,
      uniform float4    system_data)
  {
	  fragout2 O;

	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
  	
	  // calc to-face-lightning
	  float is2Lightning = step(0.2, I.lightDist.w);
  	
	  O.col[0] = float4(is2Lightning * light_col_amb.w * float3(1.0, 1.0, 1.0), tex0.a);
	  O.col[1] = float4(is2Lightning * light_col_amb.w * light_col_amb.xyz, 0.0);

    #ifdef S2_FOG
      // calc fog
      fogGlow( O.col[0].xyz, fog_texture, I.depthFog );
      fogGlow( O.col[1].xyz, fog_texture, I.depthFog );
    #endif

	  return O;
  } 
#endif

/////////////////////////////////////////////////
//PS_DUMMY_11 pixel shader (SM1_1)
/////////////////////////////////////////////////
#ifdef PS_DUMMY_11
  struct pixdata {
    float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
  };
  #define VS_OUT_hposition

  fragout1 mainPS(pixdata I,
		              uniform sampler2D texture0)
  {
	  fragout1 O;
 	  O.col = tex2D(texture0, I.texcoord.xy);
	  return O;
  } 
#endif
/////////////////////////////////////////////////
//PS_NULL_11 pixel shader (SM1_1)
/////////////////////////////////////////////////
#ifdef PS_NULL_11
  struct pixdata {
    float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
  };
  #define VS_OUT_hposition

  fragout1 mainPS(pixdata I)
  {
	  fragout1 O;
 	  O.col = float4(0,0,0,0);
	  return O;
  } 
#endif
/////////////////////////////////////////////////
//PS_NULL_20 pixel shader (SM2_0)
/////////////////////////////////////////////////
#ifdef PS_NULL_20
  struct pixdata {
    float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
  };
  #define VS_OUT_hposition

  fragout2 mainPS(pixdata I)
  {
	  fragout2 O;
 	  O.col[0] = float4(0,0,0,0);
 	  O.col[1] = float4(0,0,0,0);
	  return O;
  } 
#endif


/////////////////////////////////////////////////
//PASS_AMBDIF pixel shader (>=SM2_0)
/////////////////////////////////////////////////
#ifdef PS_TRUNK_SPASS_AMBDIF_20
  #define VS_OUT_hposition
  #define VS_OUT_screenCoord
  #define VS_OUT_hpos
  #define VS_OUT_camDist
  #define VS_OUT_lightDist
  #define VS_OUT_posInLight
  #define VS_OUT_depthFog
  #ifdef ENABLE_VERTEXLIGHTING
    #define VS_OUT_vertexLightData
  #endif

  struct pixdata {
    float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float4 camDist     : TEXCOORD1;
    float4 lightDist   : TEXCOORD2;
    float4 screenCoord : TEXCOORD3;
    float4 hpos        : TEXCOORD4;
    float4 posInLight  : TEXCOORD5;
    float2 depthFog    : TEXCOORD6;
    #ifdef VS_OUT_vertexLightData
      float4 vlColor           : COLOR0;
      float4 vlNormal          : TEXCOORD7;
    #endif
  };

  fragout2 mainPS(pixdata I,
                  float2 vPos : VPOS,
                  uniform sampler2D texture0,
                  uniform sampler2D texture1,
                  uniform sampler2D texture2,
                  uniform sampler2D texture3,
                  uniform sampler2D shadow_texture,
                  uniform sampler3D textureVolume,
                  uniform sampler2D fog_texture,
                  uniform sampler2D shadow_map,
                  uniform sampler3D noise_map,
                  uniform float4    shadow_data,
                  uniform float4    fog_color,
                  uniform float4    system_data,
                  uniform float4    light_col_amb,
                  uniform float4    light_col_diff,
                  uniform float4    param)
  {
	  fragout2 O;
	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  s2half4 tex1 = decode_normal(tex2D(texture1, I.texcoord0.xy));
	  s2half3 nrm  = tex1.xyz;
	  // get normal vector from bumpmap texture
//	  s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
//	  s2half3 nrm = normalize(tex1.xyz - s2half3(0.5, 0.5, 0.5));
  #ifdef VS_OUT_vertexLightData
    light_col_amb += light_calc_heroLight(I.vlColor);
    light_col_amb += light_calc_vertexlighting(nrm,I.vlColor,normalize(I.vlNormal.xyz));
  #endif

	  // get shadow term from shadow texture
#ifdef NO_SHADOWS
    s2half4 shadow = 1.0f;
#else  
    #ifdef TREE_HOLE
      s2half4 shadow = calcShadowSimple(shadow_map, textureVolume, I.posInLight, vPos, shadow_data.y, shadow_data.x);
    #else
	    s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);
    #endif
#endif
 
    // lighting
	  s2half3 l_dir = normalize(I.lightDist.xyz);
	  s2half3 c_dir = normalize(I.camDist.xyz);
	  s2half3 half_vec = normalize(c_dir + l_dir);


	  // calc sun diffuse
	  float3 sun_diff = light_col_diff.xyz * tex0.xyz * saturate(dot(l_dir, nrm));

    // calc moon diffuse
    float3 moon_diff = light_col_amb.xyz * tex0.xyz * (saturate(dot(c_dir, nrm)) + 0.5);

	  // calc specular
	  float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * tex1.w * light_col_diff.xyz;

    float3 new_color = moon_diff + shadow.z * (sun_diff + specular);

    sTEnergy tenergy;
    calc_tenergy(tenergy,noise_map,texture2,texture3,I.texcoord0.xy,-I.texcoord0.y,system_data.x);




  #ifdef S2_FOG
    // calc fog
    fogDiffuse( new_color, fog_texture, I.depthFog, fog_color );
  #endif

    // set output color
	  O.col[0].rgb = new_color;
    O.col[0].a = 1;
  #if TREE_HOLE
      O.col[0].a = calcHoleAlpha(I.hpos,param.x);
  #endif  
	  O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
	  
  #ifdef USE_TENERGY
//    float tescale = pow(tex0.a,3);
    float tescale = tex0.a * tex0.a;
    O.col[0].xyz += tenergy.color0*tescale;
    O.col[1].xyz += tenergy.color1*tescale;
  #endif
	  
#ifdef SPASS_LIGHTNING
	  // calc to-face-lightning
	  float is2Lightning = step(0.2, dot(nrm, I.lightDist.xyz));
	  O.col[0] = float4(is2Lightning * light_col_amb.w * float3(1.0, 1.0, 1.0), 1.0);
	  O.col[1] = float4(is2Lightning * light_col_amb.w * light_col_amb.xyz, 0.0);
#endif
#ifdef SIMPLECOLOR
	  O.col[0] = float4(1,1,1,1);
#endif

	  return O; 
  } 
#endif


/////////////////////////////////////////////////
//PASS_PNT pixel shader (>=SM2_0)
/////////////////////////////////////////////////
#ifdef PS_TRUNK_SPASS_PNT_20
  struct pixdata {
    float4 hposition    : POSITION;
    float4 texcoord0    : TEXCOORD0;
    float4 pix_to_li_t  : TEXCOORD1;
    float4 pix_to_c     : TEXCOORD2;
    float4 pix_to_li_o  : TEXCOORD3;
    float2 depthFog     : TEXCOORD4;
  };
  #define VS_OUT_hposition
  #define VS_OUT_pix_to_li_T
  #define VS_OUT_pix_to_li_O
  #define VS_OUT_PIX_TO_C
  #define VS_OUT_depthFog

  fragout2 mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D texture1,
      uniform sampler2D fog_texture,
      uniform float4 light_col_diff,
      uniform float4 light_data)
  {
	  fragout2 O;

	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	  // get normal vector from bumpmap texture
	  s2half3 nrm = normalize(tex1.xyz - s2half3(0.5, 0.5, 0.5));

	  // calc diffuse
	  s2half3 l0_dir = normalize(I.pix_to_li_t.xyz);
	  float4 diffuse = saturate(dot(l0_dir, nrm)) * light_col_diff;

	  // calc specular
	  s2half3 c_dir = normalize(I.pix_to_c.xyz);
	  s2half3 half_vec = normalize(l0_dir + c_dir);
	  float4 specular =  pow(saturate(dot(half_vec, nrm)), 20.0) * tex1.w * light_col_diff;

	  // calc distance of light
	  float dist_to_light = dot(I.pix_to_li_o.xyz, I.pix_to_li_o.xyz);
	  // build intensity from distance to light using light radius
	  float temp_dist = saturate(dist_to_light  * light_data.z * light_data.z);
	  float intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
	  // multiply it by intensity of ight source
	  intensity *= light_data.y;
  #ifdef S2_FOG
    // fog
    fogPnt( intensity, fog_texture, I.depthFog );
  #endif

	  O.col[0] = intensity * ((diffuse * tex0) + specular);
	  O.col[0].a = tex0.a;
	  O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
	  return O;
  } 
#endif 



DEFINE_VERTEX_DATA 


////////////////////////////////////////////////////////////////
//Unified Vertex shader used for all shader models
////////////////////////////////////////////////////////////////
pixdata mainVS(appdata I,
               uniform float4   vtx_data_array[32],
               uniform float4x4 vtx_matrix_array[4],
               VS_PARAM_BLOCK)
{
	pixdata O;
	EXTRACT_VERTEX_VALUES

	// apply wind and calc extreme (=1.0) position
	float4 wind_pos4 = mul(pos4, vtx_matrix_array[windidx]);
	// now interpolate between org pos and extr pos
	pos4 = lerp(pos4, wind_pos4, windLerpFact);
	

#ifdef VS_IN_TREELEAFVERTEX
	float leaf_scale = param.z;
	// get vertex billboard offset from array and scale it by size
	float4 offs4 = data2.y * vtx_data_array[data2.x] * leaf_scale;
	// transform this offset backwards with inv objmat, so it is "billboarded" after next transform
	pos4 += mul(offs4, invWorldMatrix);
#endif


  #ifdef VS_OUT_vertexLightData_nonrm
    O.vlColor = computeVertexLightingColor(pos4,nrm4);
  #endif
  #ifdef VS_OUT_vertexLightData
    computeVertexLightingColorNormal( O.vlColor, O.vlNormal,pos4);
  #endif


	// convert vertex pos from objspace to screen space
  float4 wvp_pos = mul(pos4, worldViewProjMatrix);

  float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
                    pos4.y*worldViewMatrix[1][2] + 
                    pos4.z*worldViewMatrix[2][2] + 
                    worldViewMatrix[3][2];
	// convert vertex pos from objspace to worldspace
	float4 worldVertPos    = mul(pos4, worldMatrix);
	float3 worldVertNormal = normalize(mul(nrm4.xyz, (float3x3) worldMatrix));

	O.texcoord0 = uv0;

#ifdef VS_OUT_depthFog
  O.depthFog = getFogTCs( wvp_pos.w, fog_data );
  //O.depthFog.x = saturate( (wvp_pos.w - fog_data.x) * zfrustum_data.z );
  //O.depthFog.y = fog_data.w;
#endif

#ifdef VS_OUT_hposition
	// vertex pos
	O.hposition = wvp_pos;
#endif

#ifdef VS_OUT_SM1_TEXCOORD1
	O.texcoord1 = uv0;
#endif

#ifdef VS_OUT_depthUV
    O.depthUV = float4(0,0,0,-camSpaceZ*zfrustum_data.w);
#endif
#ifdef VS_OUT_posInLight
	// vertex pos in light-space
	O.posInLight = mul(pos4, lightMatrix);
#endif
#ifdef VS_OUT_li_to_pix_w
	// pass light-to-pixel to fragment shader
	O.li_to_pix_w = worldVertPos - light_pos;
#endif


	// convert light pos from worldspace into objectspace
	float4 l_pos_obj = mul(light_pos, invWorldMatrix);
	// build vector from vertex pos to light pos
	float3 vertex_to_light = l_pos_obj.xyz - pos4.xyz;
	// convert cam pos from worldspace into objectspace
	float4 c_pos_obj = mul(camera_pos, invWorldMatrix);
	// build vector from vertex pos to cam pos
#ifdef MINIMAPMODE
  float3 vertex_to_cam = c_pos_obj;
#else
	float3 vertex_to_cam = c_pos_obj.xyz - pos4.xyz;
#endif
	// convert light direction vector from worldspace to objectspace
	float4 l0_dir_obj = mul(light_pos, invWorldMatrix);
	// convert camera direction vector from worldspace to objectspace
	float4 c_dir_obj = mul(camera_pos, invWorldMatrix);

#ifdef VERT_TREEVERTEX

	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * tan3;
	objToTangentSpace[1] = -1.0 * bin3;
	objToTangentSpace[2] = nrm4.xyz;

  // convert vertex_to_light from objectspace to tangentspace
  float3 vertex_to_light_tan = mul(objToTangentSpace, vertex_to_light);
	// convert vertex_to_cam from objectspace to tangentspace
	float3 vertex_to_cam_tan = mul(objToTangentSpace, vertex_to_cam);

	// convert light direction vector from objectspace to tangentspace
	float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz);

	// calc direction vector from vertex position to camera-position
	c_dir_obj -= pos4;
	// convert camera direction vector from objectspace to tangentspace
	float3 c_dir_tan = mul(objToTangentSpace, c_dir_obj.xyz);

  #ifdef VS_OUT_lightDist
	  // store light vector
	  O.lightDist = float4(l0_dir_tan, 0.0);
  #endif
#else
  #ifdef VS_OUT_lightDist
	  // store light vector & dot
	  O.lightDist = float4(l0_dir_obj.xyz, dot(nrm4.xyz, l0_dir_obj.xyz));
  #endif
#endif 

  #ifdef VS_OUT_vertexLightData
    O.vlNormal.xyz = mul(objToTangentSpace, O.vlNormal.xyz);
  #endif


#ifdef VS_OUT_camDist
	// store camera vec in texcoord2
	O.camDist = float4(c_dir_tan, 0.0);
#endif
#ifdef VS_OUT_hpos
	// pass screenpos to fragment shader
	O.hpos     = O.hposition;
	O.hpos.xy *= param.xy;
#endif

#ifdef VS_OUT_NORMAL
	// norma
	O.normal = nrm4;
#endif

#ifdef VS_OUT_screenCoord
	// vertex-position in screen space
  O.screenCoord = calcScreenToTexCoord(O.hposition);
#endif


#ifdef VS_OUT_SM1_LIGHTING
	O.diffuse = calcLight(worldVertPos, worldVertNormal, camera_pos, globLightData, O.specular);
#endif 
#ifdef VS_OUT_diffuse
	// convert light direction vector from worldspace to objectspace
	float4 l0_dir = mul(light_pos, invWorldMatrix);
	float  diffuse = saturate(dot(nrm4, l0_dir));
	// prepare color
	O.diffuse = float4(diffuse, diffuse, diffuse, 1.0);
#endif 


#ifdef VS_OUT_lowendFog
	O.fog = calcFog(O.hposition, fog_data);
#endif


	// pass vertex to light to pixelshader, so it becomes pixel to light
#ifdef VS_OUT_pix_to_li_T
	O.pix_to_li_t = float4(vertex_to_light_tan, 0.0);
#endif
#ifdef VS_OUT_pix_to_li_O
	O.pix_to_li_o = float4(vertex_to_light, 0.0);
#endif
#ifdef VS_OUT_pix_to_li
	// pass vertex to light to pixelshader, so it becomes pixel to light
	O.pix_to_li = float4(vertex_to_light, 0.0);
#endif
#ifdef VS_OUT_PIX_TO_C
	// pass vertex to cam to pixelshader, so it becomes pixel to cam
	O.pix_to_c = float4(vertex_to_cam_tan, 0.0);
#endif

	return O;
}
