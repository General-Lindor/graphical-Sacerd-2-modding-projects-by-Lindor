// static mini object z

//#OptDef:SPASS_G
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
//#OptDef:SPASS_LIGHTNING
//#OptDef:NO_SHADOWS
//#OptDef:S2_FOG
//#OptDef:VERTEXLIGHTING_TEST


//Vertex shader input
struct appdata
{
	float4 position    : POSITION;
	float4 normal      : NORMAL;
	float2 texcoord    : TEXCOORD0;
	float4 color       : COLOR;
};

#include "lighting.shader"

/////////////////////////////////////
// SPASS_G setup
/////////////////////////////////////
#ifdef SPASS_G
  struct pixdata
  {
	  float4 hposition  : POSITION;
	  float4 depthUV    : TEXCOORD0;
	  float4 data1      : TEXCOORD1;
	  float4 posInLight : TEXCOORD2;
	  float4 color      : COLOR;
  };
  #define VS_OUT_hposition
  #define VS_OUT_data0
  #define VS_OUT_data1
  #define VS_OUT_posInLight
  #define VS_OUT_color

  fragout1 mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D shadow_map,
      uniform sampler3D textureVolume,
      uniform float4 shadow_data,
      uniform sampler2D gradient_texture )
  {
    fragout1 O;
    // color info
	  float4 tex0 = tex2D(texture0, I.data1.xy);
    clip(tex0.a-0.5f);
  	O.col        = float4(I.depthUV.w,0,0,1);
  	return O;
  } 
#endif
/////////////////////////////////////
// SPASS_AMBDIF setup
/////////////////////////////////////
#ifdef SPASS_AMBDIF
  #define VS_OUT_hposition
  #define VS_OUT_data0
  #define VS_OUT_data1
  #define VS_OUT_screencoord
  #define VS_OUT_depthFog
  #ifdef ENABLE_VERTEXLIGHTING
    #define VS_OUT_vertexLightData
  #endif

  struct pixdata {
	  float4 hposition  : POSITION;
	  float4 depthUV    : TEXCOORD0;
	  float4 data1      : TEXCOORD1;
    float4 screenCoord: TEXCOORD2;
    float2 depthFog   : TEXCOORD3;
  #ifdef VS_OUT_vertexLightData
    float4 vlColor           : COLOR0;
  #endif
  };

  fragout2 mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D shadow_texture,
      uniform sampler2D fog_texture,
      uniform float4    fog_color,
      uniform float4    light_col_amb,
      uniform float4    light_col_diff)
  {
    fragout2 O;
    // color info
	  float4 tex0          = tex2D(texture0, I.data1.xy);
	
    #ifdef VS_OUT_vertexLightData
      light_col_amb += light_calc_heroLight(I.vlColor);
      light_col_amb += I.vlColor;
    #endif

    s2half4 deferred_tex = tex2Dproj(shadow_texture, I.screenCoord);

    float3 final_color    = tex0.xyz * (light_col_amb.xyz + I.data1.z * deferred_tex.z * light_col_diff.xyz);

    #ifdef S2_FOG
      #ifdef CALC_DEFERRED_FOG
        fogDiffuseI( final_color, deferred_tex.y, fog_color );
      #else
        fogDiffuse( final_color, fog_texture, I.depthFog, fog_color );
      #endif
    #endif

  	O.col[0]           = float4(final_color,1);
  	O.col[1]           = float4(0,0,0,0);
  	return O;
  } 

#endif  

/////////////////////////////////////
// SPASS_PNT setup
/////////////////////////////////////
#ifdef SPASS_PNT
  #if defined(SM1_1)
    #define VS_OUT_G_11
    #define PS_G_11
  #else
    #define VS_OUT_PNT
    #define PS_PNT_20
  #endif


  struct pixdata
  {
	  float4 hposition   : POSITION;
	  float4 texcoord    : TEXCOORD0;
	  float4 pix_to_li   : TEXCOORD1;
  	float4 li_to_pix_w : TEXCOORD2;
    float2 depthFog    : TEXCOORD3;
  };
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_pix_to_li
  #define VS_OUT_li_to_pix_w
  #define VS_OUT_depthFog


  fragout2 mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform samplerCUBE textureCube,
      uniform float4    light_col_diff,
      uniform float4    light_data,
      uniform sampler2D fog_texture )
  {
	  fragout2 O;
	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord.xy);
	  // calc distance of light
	  float dist_to_light = dot(I.pix_to_li.xyz, I.pix_to_li.xyz);
	  // build intensity from distance to light using light radius
	  float temp_dist = saturate(dist_to_light  * light_data.z * light_data.z);
	  float intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
	  // multiply it by intensity of ight source
	  intensity *= light_data.y;
  	// fog
#ifdef S2_FOG
    fogPnt( intensity, fog_texture, I.depthFog );
#endif

    // shadow
#ifdef NO_SHADOWS
    s2half shadow = 1.0;
#else
  	s2half shadow = calcPntFadeShadow(textureCube, light_data.z * I.li_to_pix_w.xzy,light_data.w);
#endif

	  // diffuse
	  float diffuse = saturate(I.pix_to_li.w) * shadow;

	  // set output color
	  s2half4 col = intensity * diffuse * light_col_diff * tex0 * shadow; 
	  O.col[0].xyz = col.xyz;
	  O.col[0].a = tex0.a;
	  O.col[1].xyz = 0.1 * col.xyz;
	  O.col[1].a = tex0.a;
	  return O;
  } 

#endif
/////////////////////////////////////
// SPASS_LIGHTNING setup
/////////////////////////////////////
#ifdef SPASS_LIGHTNING

  struct pixdata
  {
	  float4 hposition   : POSITION;
	  float4 texcoord    : TEXCOORD0;
  	float4 lightDir    : TEXCOORD1;
    float2 depthFog    : TEXCOORD2;
  };
  #define VS_OUT_hposition
  #define VS_OUT_texcoord
  #define VS_OUT_lightDir
  #define VS_OUT_depthFog

  fragout2 mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D fog_texture,
      uniform float4    light_col_amb)
  {
	  fragout2 O;
	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord.xy);
	  // calc to-face-lightning
	  float is2Lightning = step(0.2, I.lightDir.w);
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


pixdata mainVS(appdata I,
               VS_PARAM_BLOCK)
{
	pixdata O;

	float4 pos4    = float4(I.position.xyz, 1.0);
  float  weight  = length( camera_pos.xy - pos4.xy ) / camera_pos.w;
         weight  = pow( weight, 7.0 );
         pos4.z -= weight * 20.0;

	float4 nrm4 = float4(I.normal.xyz * 2.0 - 1.0, 0.0);

  // convert light pos from worldspace into objectspace
  float4 l_pos_obj = mul(light_pos, invWorldMatrix);
  // build vector from vertex pos to light pos
  float3 pix_to_li     = l_pos_obj.xyz - pos4.xyz;
  float3 pix_to_li_nrm = normalize(pix_to_li);

  #ifdef VS_OUT_vertexLightData
    float4 vec_normal_os;
    computeVertexLightingColorNormal( O.vlColor, vec_normal_os,pos4);
    O.vlColor.xyz *= saturate(dot(vec_normal_os,nrm4));
  #endif


  #ifdef VS_OUT_hposition
	  // vertex pos
	  O.hposition = mul(pos4, worldViewProjMatrix);
    float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
                      pos4.y*worldViewMatrix[1][2] + 
                      pos4.z*worldViewMatrix[2][2] + 
                      worldViewMatrix[3][2];
  #endif

	#ifdef VS_OUT_screencoord
    // vertex-position in screen space
    O.screenCoord = calcScreenToTexCoord(O.hposition);
	#endif

  #ifdef VS_OUT_depthFog
    O.depthFog = getFogTCs( O.hposition.w, fog_data );
  #endif

	#ifdef VS_OUT_posInLight
	  // vertex pos in light-space
	  O.posInLight = mul(pos4, lightMatrix);
	#endif


  #ifdef VS_OUT_data0
    O.depthUV = float4(0,0,0,-camSpaceZ*zfrustum_data.w);
  #endif	

  #ifdef VS_OUT_data1
	  float diffuse = dot(light_pos.xyz, nrm4.xyz);
	  diffuse = max(0.0,diffuse);
	  diffuse = diffuse + param.x;
	  diffuse = min(diffuse, 1.0);

	  // compose data (diffuse + texcoords + minitypeID)
	  O.data1 = float4(I.texcoord.x / 2048.0, I.texcoord.y / 2048.0, diffuse, param.x);
	#endif
	
  #ifdef VS_OUT_li_to_pix_w
	  // convert vertex-pos from object to worldspace
	  float4 v_pos_w = mul(pos4, worldMatrix);
	  // pass light-to-pixel to fragment-shader
	  O.li_to_pix_w = v_pos_w - light_pos;
  #endif 

  #ifdef VS_OUT_color
	  O.color = I.color;
  #endif
  #ifdef VS_OUT_texcoord
	  // pass texture coords
	  O.texcoord = I.texcoord.xyyy / 2048.0;
  #endif
  #ifdef VS_OUT_pix_to_li
	  // calc diffuse
	  float diffuse = dot(pix_to_li_nrm, nrm4.xyz);// + bin.y;
	  // store pix2li and diffuse in one vector
	  O.pix_to_li = float4(pix_to_li, diffuse);
  #endif
  
  #ifdef VS_OUT_lightDir
	  // convert light pos from worldspace into objectspace
	  float4 l_dir_obj = mul(light_pos, invWorldMatrix);
	  // store light vector & dot
	  O.lightDir = float4(l_dir_obj.xyz, dot(nrm4.xyz, l_dir_obj.xyz));
  #endif

 	#ifdef VS_OUT_lighting_11
  	O.shadowCoord = mul(pos4, lightMatrix);

	  float3 worldVertPos = mul(pos4, worldMatrix);
	  float3 worldVertNormal = normalize(mul(nrm4.xyz, (float3x3) worldMatrix));
  	O.diffuse = calcDiffuseLightShadowed(worldVertPos, worldVertNormal, globLightData, O.mainDiffuseLight, O.lightRelPos);
 	#endif

	#ifdef VS_OUT_lowendFog
  O.fog = calcFog(O.hposition, fog_data);
	#endif

	return O;
}

