// fur
//#OptDef:SPASS_G
//#OptDef:S2_FOG
//#OptDef:LAYER_BIT0
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
  float  shell       : TEXCOORD2;
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
};



pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 worldViewMatrix,
  uniform float4x4 invWorldMatrix,
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
  float anz_shells = param.x;
  float lowest_shell_darkness = param.y;
  float weight = param.w;
  float thickness = param.z;

  // modify thickness?
#if LAYER_BIT0
  thickness *= I.data.y;
#endif

  // shells
  float shell = I.shell.x / anz_shells;

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

  float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
                    pos4.y*worldViewMatrix[1][2] + 
                    pos4.z*worldViewMatrix[2][2] + 
                    worldViewMatrix[3][2];

#ifdef SPASS_G

  // calc texturecoords for rg(b)-depth encoding
  O.depthUV = float4(0,0,0, -camSpaceZ*zfrustum_data.w);

	// texture coords
	O.texcoord0 = float4(I.texcoord.xy, shell, 0.0);

#else

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

#ifdef SM1_1
#else

  #ifdef SPASS_G
    struct fragout {
	    float4 col0      : COLOR;
    };
  #else
    struct fragout {
	    float4 col0      : COLOR0;
	    float4 col1      : COLOR1;
    };
  #endif


  fragout mainPS(pixdata I,
      uniform sampler2D   texture0,
      uniform sampler2D   texture1,
      uniform sampler2D   texture2,
      uniform sampler3D   textureVolume,
      uniform sampler2D   shadow_texture,
      uniform sampler2D   gradient_texture,
      uniform sampler2D   fog_texture,
      uniform float4      fog_color,
      uniform float4      light_col_amb,
      uniform float4      light_col_diff)
  {
    fragout O;

  #ifdef SPASS_G

    // needed cause of alpha!
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

    // sample from fur texture
    s2half4 fur_mask = tex3D(textureVolume, float3(5.0 * I.texcoord0.xy, I.texcoord0.z));
    clip(fur_mask.a*tex0.a-0.9f);
	  O.col0           = float4(I.depthUV.w,0,0,1);

  #else

	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

    // sample from fur texture
    s2half4 fur_mask = tex3D(textureVolume, float3(5.0 * I.texcoord0.xy, I.texcoord0.z));
    clip(fur_mask.a*tex0.a-0.1f);

	  s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	  s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));

    // ambient color
    s2half4 amb_col = light_col_amb * tex0;

    // diffuse color
    s2half4 diff_col = (I.lighting.x + I.lighting.z) * light_col_diff * tex0 + I.lighting.yyyy * tex1;


    // final color
    float3 final_col = 2.0 * I.texcoord0.w * (amb_col.xyz + I.lighting.w * diff_col.xyz);

    /*

	  // get shadow term from shadow texture
	  s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

	  // get normal vector from bumpmap texture
  //	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	  s2half3 nrm = tex2;

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

	  // set output color
	  O.col[0].rgb = glow_amb + moon_diff + shadow.z * (sun_diff + specular);
	  O.col[0].a = tex0.a;
	  O.col[1].rgb = 0.5 * shadow.z * specular + glow_amb;
	  O.col[1].a = tex0.a;
    */

/*
  #ifdef S2_FOG
    fogDiffuse( final_col.xyz, fog_texture, I.depthFog, fog_color );
  #endif
*/

    // out
	  O.col0 = float4(final_col, fur_mask.a * tex0.a);
	  O.col1 = float4(0.0, 0.0, 0.0, 0.0);
  #endif

	  return O;
  } 

#endif
