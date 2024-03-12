//#OptDef:SPASS_G
//#OptDef:SPASS_PNT
//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_LIGHTNING
//#OptDef:NO_SHADOWS
//#OptDef:FLOWER_WOBBLE
//#OptDef:VS_IN_MINIVERTEX
//#OptDef:VS_IN_INSTANCED_MINIVERTEX
//#OptDef:S2_FOG
//#OptDef:ENABLE_VERTEXLIGHTING




#include "extractvalues.shader"
#include "lighting.shader"
#include "wobble.shader"
#include "shadow.shader"

/////////////////////////////////////
// SPASS_G setup
/////////////////////////////////////
#ifdef SPASS_G
#define VS_OUT_hposition
#define VS_OUT_data0
#define VS_OUT_data1
#define VS_OUT_screencoord
#ifdef ENABLE_VERTEXLIGHTING
#define VS_OUT_vertexLightData
#endif

struct pixdata {
  float4 hposition  : POSITION;
  float4 depthUV    : TEXCOORD0;
  float4 data1      : TEXCOORD1;
  float4 screenCoord: TEXCOORD2;
#ifdef VS_OUT_vertexLightData
  float4 vlColor    : COLOR0;
#endif
};

fragout1 mainPS(pixdata I,
                PS_PARAM_BLOCK)
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
  float4 vlColor    : COLOR0;
#endif
};
fragout2 mainPS(pixdata I,
                PS_PARAM_BLOCK)
{
  fragout2 O;
  // color info
  float4 tex0           = tex2D(texture0, I.data1.xy);
  // get shadow term from shadow texture

  s2half4 deferred_tex  = tex2Dproj(shadow_texture, I.screenCoord);

#ifdef VS_OUT_vertexLightData
  light_col_amb += light_calc_heroLight(I.vlColor);
  light_col_amb += I.vlColor;
#endif



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
struct pixdata {
  float4 hposition   : POSITION;
  float4 texcoord    : TEXCOORD0;
  float4 pix_to_li   : TEXCOORD1;
  float4 li_to_pix_w : TEXCOORD2;
  float2 depthFog   : TEXCOORD3;
};
#define VS_OUT_hposition
#define VS_OUT_texcoord
#define VS_OUT_pix_to_li
#define VS_OUT_li_to_pix_w
#define VS_OUT_depthFog

fragout2 mainPS(pixdata I,
                PS_PARAM_BLOCK)
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
#ifdef S2_FOG
  fogPnt( intensity, fog_texture, I.depthFog );
#endif

  // shadow
#ifdef NO_SHADOWS
  s2half shadow = 1;
#else
  s2half shadow = calcPntFadeShadow(textureCube, light_data.z * I.li_to_pix_w.xzy,light_data.w);
#endif	

  // diffuse
  float diffuse = saturate(I.pix_to_li.w);

  // set output color
  O.col[0] = diffuse * intensity * light_col_diff * shadow * tex0;
  O.col[0].a = tex0.a;
  O.col[1] = 0.1 * diffuse * intensity * light_col_diff * shadow * tex0;
  O.col[1].a = tex0.a;
  return O; 
} 
#endif


/////////////////////////////////////
// SPASS_LIGHTNING setup
/////////////////////////////////////
#ifdef SPASS_LIGHTNING
#define VS_OUT_hposition
#define VS_OUT_texcoord
#define VS_OUT_lightDir
#define VS_OUT_depthFog

struct pixdata {
  float4 hposition   : POSITION;
  float4 texcoord    : TEXCOORD0;
  float4 lightDir    : TEXCOORD1;
  float2 depthFog    : TEXCOORD2;
};
fragout2 mainPS(pixdata I,
                PS_PARAM_BLOCK)
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



DEFINE_VERTEX_DATA


pixdata mainVS(appdata I,
               uniform float4   vtx_data_array[FLOWERS_WOBBLE_CENTER_MAX],
               VS_PARAM_BLOCK)
{
  pixdata O;

  EXTRACT_VERTEX_VALUES
  

    // apply wind and calc extreme (=1.0) position
    vertex_pos.xyz += wind_weight * vtx_data2_array[wind_group];

#ifdef FLOWER_WOBBLE
  // get wobble matrix
  float3x3 rotMat = calcWobble(vtx_data_array, flower_center.xy, vertex_pos.z);
  // bend it
  vertex_pos.xyz = mul(vertex_pos.xyz, rotMat);
#endif

  // let grass grow out of ground to avoid ugly popups
  float weight = length(camera_pos.xy - (flower_center.xy) ) / camera_pos.w;
  weight = pow( weight, 7.0 );
  vertex_pos.z *= 1.0 - weight;
  vertex_pos.z -= weight * 20.0;

  // translate to final position
  vertex_pos.xyz += flower_center;


#ifdef VS_OUT_hposition
  // vertex pos
  O.hposition = mul(vertex_pos, worldViewProjMatrix);
#endif

#ifdef VS_OUT_vertexLightData
  float3 vec_light;
  computeVertexLightingColorNormal( O.vlColor, vec_light,vertex_pos);
  float mully = saturate(dot(vec_light, ground_normal.xyz));
  O.vlColor.xyz *= mully;
#endif

  float camSpaceZ = vertex_pos.x*worldViewMatrix[0][2] +  
    vertex_pos.y*worldViewMatrix[1][2] + 
    vertex_pos.z*worldViewMatrix[2][2] + 
    worldViewMatrix[3][2];
#ifdef VS_OUT_screencoord
  // vertex-position in screen space
  O.screenCoord = calcScreenToTexCoord(O.hposition);
#endif

#ifdef VS_OUT_depthFog
  O.depthFog = getFogTCs( O.hposition.w, fog_data );
#endif

#ifdef VS_OUT_posInLight
  // vertex pos in light-space
  O.posInLight = mul(vertex_pos, lightMatrix);
#endif



#ifdef VS_OUT_data0
  O.depthUV = float4(0,0,0,-camSpaceZ*zfrustum_data.w);
#endif

  // convert light direction vector from worldspace to objectspace
  float4 l_obj = mul(light_pos, invWorldMatrix);
  // convert light pos from worldspace into objectspace
  float4 l_pos_obj = mul(light_pos, invWorldMatrix);
  // convert light pos from worldspace into objectspace
  float4 l_dir_obj = mul(light_pos, invWorldMatrix);

#ifdef VS_OUT_data1
  // calc diffuse
  float diffuse = dot(l_obj.xyz, ground_normal.xyz);
  // compose data (diffuse + texcoords + minitypeID)
  O.data1 = float4(uv0.x,uv0.y, diffuse, param.z);
#endif



#ifdef VS_OUT_shadowCoord
  // vertex pos in light-space
  O.shadowCoord = mul(vertex_pos, lightMatrix);
#endif

#ifdef VS_OUT_lighting_11
  float3 worldVertPos = mul(vertex_pos, worldMatrix);
  float3 worldVertNormal = normalize(mul(ground_normal.xyz, (float3x3) worldMatrix));
  O.diffuse = calcDiffuseLightShadowed(worldVertPos, worldVertNormal, globLightData, O.mainDiffuseLight, O.lightRelPos);
#endif

#ifdef VS_OUT_texcoord
  // pass transformed & untransformed texture coords
  O.texcoord = uv0.xyyy;
#endif

  // build vector from vertex pos to light pos
  float3 pix_to_li = l_pos_obj.xyz - vertex_pos.xyz;
  float3 pix_to_li_nrm = normalize(pix_to_li);

#ifdef VS_OUT_pix_to_li
  // calc diffuse
  float diffuse = dot(pix_to_li_nrm, ground_normal.xyz) + height_scale;
  // store pix2li and diffuse in one vector
  O.pix_to_li = float4(pix_to_li, diffuse);
#endif

#ifdef VS_OUT_li_to_pix_w
  // convert vertex-pos from object to worldspace
  float4 v_pos_w = mul(vertex_pos, worldMatrix);
  // pass light-to-pixel to fragment-shader
  O.li_to_pix_w = v_pos_w - light_pos;
#endif

#ifdef VS_OUT_lightDir
  // store light vector & dot
  O.lightDir = float4(l_dir_obj.xyz, dot(ground_normal.xyz, l_dir_obj.xyz) + height_scale);
#endif


  return O;
}
