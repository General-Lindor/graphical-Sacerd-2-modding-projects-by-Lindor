// fur
//#OptDef:SPASS_G
//#OptDef:S2_FOG
//#OptDef:LAYER_BIT0
//#OptDef:CONSOLE_IMPL

#include "extractvalues.shader"

#ifdef SM1_1 // no fog in shader model 1
#ifdef S2_FOG
#undef S2_FOG
#endif
#endif

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
#ifdef CONSOLE_IMPL
#else
    float  shell       : TEXCOORD2;
#endif
};

struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
#ifdef SPASS_G
  float4 depthUV     : TEXCOORD1;
#else
	float4 screenCoord : TEXCOORD1;
  float4 lighting    : TEXCOORD2;
#ifdef S2_FOG
  float2 depthFog    : TEXCOORD3;
#endif
#endif
#ifdef CONSOLE_IMPL
  float4 posInLight  : TEXCOORD4;
#endif
};


#ifdef SM1_1
struct fragout {
	float4 col         : COLOR;
};
#else
struct fragout {
	s2half4 col[2]      : COLOR;
#if defined(PS3_IMPL)
    s2half4 colCopy     : COLOR2;
#endif
};
#endif

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
#ifdef CONSOLE_IMPL
  uniform float4x4 lightMatrix,
#endif
  uniform float4   light_pos,
  uniform float4   camera_pos,
  uniform float4   param,
  uniform float4   zfrustum_data,
  uniform float4   fog_data )
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

  // names
#ifdef CONSOLE_IMPL
#else
  float anz_shells = param.x;
#endif
  float lowest_shell_darkness = param.y;
  float weight = param.w;
  float thickness = param.z;

  // modify thickness?
#if LAYER_BIT0
  thickness *= I.data.y;
#endif

#ifdef CONSOLE_IMPL
  O.posInLight = mul( pos4, lightMatrix );
#endif

  // shells
#ifdef CONSOLE_IMPL
  float shell = param.x;
#else
  float shell = I.shell.x / anz_shells;
#endif

  // calculate gravity
  float4 gravity = float4(0.0, 0.0, -weight, 0.0);
	float4 gravity_obj = mul(gravity, invWorldMatrix);
  float4 gravity_bend = gravity_obj - (dot(gravity_obj, nrm4) * nrm4);

  // calculate bending and extrusion
  float d2 = shell * shell;
  float f2 = weight * weight;
  float wf = (0.861986 * weight) - (0.176676 * f2);
  float hf = 1.0 - (0.04743 * weight) - (0.36726 * f2);
  hf = (hf * d2) + (shell * (1 - shell));
  wf = wf * d2;

  // apply displacement
  pos4 += thickness * hf * nrm4 + thickness * wf * gravity_bend;

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

#ifdef SPASS_G

	// put (normalized!) distance
  float distance = (O.hposition.w - zfrustum_data.x) * zfrustum_data.z;
  // calc texturecoords for rg(b)-depth encoding
  O.depthUV = float4(distance * float2(1.0, 256.0), 0.0, 0.0);

	// texture coords
	O.texcoord0 = float4(I.texcoord.xy, shell, 0.0);

#else

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
	float4 l_dir_obj = mul(light_pos, invWorldMatrix);
  float3 l_dir_obj_nrm = normalize(l_dir_obj.xyz);

	// convert camera direction vector from worldspace to objectspace
	float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	// calc direction vector from vertex position to camera-position
	c_dir_obj -= pos4;
  float3 c_dir_obj_nrm = normalize(c_dir_obj.xyz);

  // standard phong shading
  float phong = saturate(dot(l_dir_obj_nrm, nrm4.xyz));

  // calc fur-shading color
  float3 n = l_dir_obj_nrm - (dot(nrm4.xyz, l_dir_obj_nrm) * nrm4.xyz);
  float3 halfway_vec = normalize(l_dir_obj_nrm + c_dir_obj_nrm);

  // calc diffuse
  float diff = saturate(dot(n, l_dir_obj_nrm));

  // calc specular
  float spec = pow(dot((halfway_vec - (dot(nrm4.xyz, halfway_vec) * nrm4.xyz)), halfway_vec), 30);

  // calc selfshadowning
  float FoFSP = 1.0 - saturate(dot(nrm4.xyz, l_dir_obj_nrm));
  float density = 1.0;
  float FoFS = saturate(((4 * (shell / density)) - (3 * FoFSP)) / FoFSP);
  float self_shadow = min(FoFS, saturate(dot(nrm4.xyz, l_dir_obj_nrm) + 0.5));
  float depth_shadow = shell * (1.0 - lowest_shell_darkness) + lowest_shell_darkness;

  // store
  O.lighting = float4(diff * 0.35, spec * 0.25, phong * 0.2, self_shadow);

	// texture coords
	O.texcoord0 = float4(I.texcoord.xy, shell, depth_shadow);
#endif

	return O;
}

#ifdef CONSOLE_IMPL
  #include "normalmap.shader"
#endif
#ifdef CONSOLE_IMPL
  #include "shadow.shader"
#endif
#if defined(CONSOLE_IMPL) && defined(SPASS_G) 
  fragout1 mainPS(pixdata I,
      uniform sampler2D   texture0,
      uniform sampler2D   texture1,
      uniform sampler2D   texture2,
      uniform sampler3D   textureVolume,
      uniform sampler2D   shadow_texture,
      uniform sampler2D   gradient_texture,
      uniform sampler2D   fog_texture,
      uniform float4      light_col_amb,
      uniform float4      light_col_diff)
  {
	  fragout1 O;

    // needed cause of alpha!
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
    // sample from fur texture
    s2half4 fur_mask = tex3D(textureVolume, float3(5.0 * I.texcoord0.xy, I.texcoord0.z));

    clip( floor(fur_mask.a * tex0.a) - 0.5f );
	  O.col = float4(0,0,0, 1);

	  return O;
  } 
#else
fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler3D   textureVolume,
#ifdef CONSOLE_IMPL
    uniform sampler2D   shadow_map,
    uniform float2      vPos : VPOS,
	uniform float4      shadow_data,
    
#endif
    uniform sampler2D   shadow_texture,
    uniform sampler2D   gradient_texture,
    uniform sampler2D   fog_texture,
    uniform float4      light_col_amb,
    uniform float4      light_col_diff)
{
	fragout O;

#ifdef SPASS_G

  // needed cause of alpha!
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

  #ifdef SM1_1
  	O.col = tex0;
  #else
    // sample from fur texture
    s2half4 fur_mask = tex3D(textureVolume, float3(5.0 * I.texcoord0.xy, I.texcoord0.z));

    // depthUV.x is depth * 1.0
    // depthUV.y is depth * 256.0
    // texturelookup endcodes this!!
    s2half4 ramp = tex2D(gradient_texture, I.depthUV.xy);

	  O.col[0] = float4(tex0.xyz, floor(fur_mask.a * tex0.a));
    O.col[1] = float4(ramp.xy, 0.0, 0.0);
  #endif
#else

#ifdef SM1_1

  // get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	O.col = tex0;

#else
	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
#ifdef CONSOLE_IMPL
#else
	s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));
#endif

  // sample from fur texture
  s2half4 fur_mask = tex3D(textureVolume, float3(5.0 * I.texcoord0.xy, I.texcoord0.z));

  // ambient color
  s2half4 amb_col = light_col_amb * tex0;

  // diffuse color
  s2half4 diff_col = (I.lighting.x + I.lighting.z) * light_col_diff * tex0 + I.lighting.yyyy * tex1;
#ifdef CONSOLE_IMPL
  s2half shadow = calcShadowSimple( shadow_map, I.posInLight );
  diff_col *= shadow;
#endif

  // final color
  s2half3 final_col = 2.0 * I.texcoord0.w * (amb_col.xyz + I.lighting.w * diff_col.xyz);
  
/*
	
	// get shadow term from shadow texture
	s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

	// get normal vector from bumpmap texture
#ifdef CONSOLE_IMPL
    s2half3 nrm = ReadNormalMap2D(texture2, I.texcoord0.xy).xyz;
#else
//	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	s2half3 nrm = tex2;
#endif

  // lighting
	s2half3 l0_dir = normalize(I.lightDist.xyz);
	s2half3 c_dir = normalize(I.camDist.xyz);
	s2half3 half_vec = normalize(c_dir + l0_dir);

	// calc sun diffuse
	s2half3 sun_diff = light_col_diff.xyz * tex0.rgb * saturate(dot(l0_dir, nrm));

  // calc moon diffuse
  s2half3 moon_diff = light_col_amb.xyz * tex0.rgb * (0.5 + saturate(dot(c_dir, nrm)));

  // calc glow
  s2half3 glow_amb = tex1.a * tex0;

	// calc specular
	s2half3 specular = pow(saturate(dot(half_vec, nrm)), 20) * tex1.xyz * light_col_diff.xyz;

	// set output color
	O.col[0].rgb = glow_amb + moon_diff + shadow.z * (sun_diff + specular);
	O.col[0].a = tex0.a;
	O.col[1].rgb = 0.5 * shadow.z * specular + glow_amb;
	O.col[1].a = tex0.a;
  */

#ifdef S2_FOG
  fogDiffuse( final_col.xyz, fog_texture, I.depthFog, light_col_diff );
#endif

  // out
	O.col[0] = float4(final_col, fur_mask.a * tex0.a);
	O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
#endif
#endif

#if defined(PS3_IMPL)
	O.colCopy=O.col[0];
#endif

	return O;
} 
#endif

