//#OptDef:S2_FOG

#include "extractvalues.shader"

// skin

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
    #define ITEMPREVIEW_CFG_CLIPSKIN
    #include "itemPreviewStd.shader"
  #else
    #include "lighting.shader"
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
  float4 vlNormal     : TEXCOORD7;
#endif
#ifdef SM3_0
	float4 camDist_ws   : TEXCOORD8;
#endif
};

struct fragout {
	float4 col[2]      : COLOR;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4x4 worldMatrix,
  uniform float4   light_pos,
  uniform float4   camera_pos,
  uniform float4   fog_data,
  uniform float4   zfrustum_data )
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

#ifdef VS_OUT_vertexLightData
  computeVertexLightingColorNormal(O.vlColor,O.vlNormal,pos4);
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

#ifdef S2_FOG
  float2 fog_tcs = getFogTCs( O.hposition.w, fog_data );
  // no interpolators left for SM2 so we have to hide our TCs in other vectors
  O.tan_to_wrld0.w = fog_tcs.x;
  O.tan_to_wrld1.w = fog_tcs.y;
#endif

#ifdef VS_OUT_vertexLightData
  O.vlNormal = float4(mul( objToTangentSpace,O.vlNormal ),0);
#endif

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
	O.camDist_ts = float4(c_dir_tan, 0.0);

#ifdef SM3_0
	// convert camPosition into world-space and make it direction
	O.camDist_ws = camera_pos - mul(pos4, worldMatrix);
#endif

	// texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D texture0,
  uniform sampler2D texture1,
  uniform sampler2D texture2,
  uniform sampler2D texture3,
  uniform sampler2D fog_texture,
  uniform sampler2D shadow_texture,
  uniform float4    fog_color,
  uniform float4    light_col_amb,
  uniform float4    light_col_diff,
  uniform float4    pix_data_array[2] )
{
  s2half4 tex3 = tex2D(texture3, I.texcoord0.xy);
  if( pix_data_array[0].x )
    clip( - tex3.a );

	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
//	s2half4 tex2 = tex2D(texture2, I.texcoord0.xy);
  s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));

  // adjust skin color
  //tex0.rgb = lerp( tex0.rgb, pix_data_array[1].rgb, tex3.a );
  tex0.rgb += pix_data_array[1].rgb * tex3.a;

	// get shadow term from shadow texture
	float4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

	// build matrix to tranform from tangent to world-space
	float3x3 tangent_to_world;
	tangent_to_world[0] = I.tan_to_wrld0.xyz;
	tangent_to_world[1] = I.tan_to_wrld1.xyz;
	tangent_to_world[2] = I.tan_to_wrld2.xyz;
	
	// get normal vector from bumpmap texture
	s2half3 nrm    = tex2.xyz;//normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	s2half3 nrm_ws = mul(nrm, tangent_to_world);

#ifdef VS_OUT_vertexLightData
  light_col_amb += light_calc_heroLight(I.vlColor);
  light_col_amb += light_calc_vertexlighting(nrm,I.vlColor,I.vlNormal);
#endif
	
  // lighting
	s2half3 l_dir = normalize(I.lightDist.xyz);
	s2half3 c_dir_ts = normalize(I.camDist_ts.xyz);
	s2half3 half_vec = normalize(c_dir_ts + l_dir);
	s2half dot_l_n = dot(l_dir, nrm);
  s2half dot_c_n = dot(c_dir_ts, nrm);
  
  // skin shading
	// calc sub-surface
	s2half sublamb = smoothstep(-0.4, 1.0, dot_l_n) - smoothstep(0.0, 1.0, dot_l_n);
	float3 subsurface = light_col_diff.xyz * tex3.xyz * tex0.xyz * saturate(sublamb);
	
	// calc special he magic factor
 #ifdef SM2_0
	s2half cosine = 0.5;
	s2half sine = 0.5;
 #else
	s2half3 c_dir_ws = normalize(I.camDist_ws.xyz);
	s2half cosine = saturate(dot(normalize(s2half3(c_dir_ws.xy, 0.0)), normalize(s2half3(nrm_ws.xy, 0.0))));
	s2half sine = sqrt(1.0 - cosine * cosine);
 #endif
	
	// magic cloth intensity
	s2half magic_int = tex2.a;
	
	// interpolate!
	float3 magic_col = lerp(tex0.xyz, tex1.xyz, magic_int * pow(sine, 4.0));

	// calc sun diffuse
	float3 diffuse = light_col_diff.xyz * magic_col * saturate(dot_l_n);

  // calc moon diffuse
  float3 moon_diff = light_col_amb.xyz * magic_col * (0.5 + saturate(dot_c_n));

  // calc glow
  float3 glow_amb = tex1.a * tex0 + 0.1 * tex1.xyz * pow(sine, 4.0);
  
	// calc specular
	float3 specular = light_col_diff.xyz * tex1.xyz * pow(saturate(dot(half_vec, nrm)), 20);
	// no specular in magic parts!
	specular *= (1.0 - magic_int);
	
	// calc base color
	float3 base_color = diffuse + specular + subsurface * tex3.a;

	// prepare output color
	float4 out0 = float4(glow_amb + moon_diff + shadow.z * base_color, tex0.a);
	float4 out1 = float4(0.5 * shadow.z * specular + glow_amb, tex0.a);
	
#ifdef S2_FOG
  float2 fog_tmp = { I.tan_to_wrld0.w, I.tan_to_wrld1.w };
  fogDiffuse( out0.xyz, fog_texture, fog_tmp, fog_color );
  fogGlow( out1.xyz, fog_texture, fog_tmp );
#endif

  // und raus damit	
	O.col[0] = out0;
	O.col[1] = out1;

	return O;
} 


#endif
