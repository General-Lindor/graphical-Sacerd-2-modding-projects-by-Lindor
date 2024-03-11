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
	float4 camDist     : TEXCOORD1;
	float4 lightDist   : TEXCOORD2;
#ifdef SPASS_G
	float4 depthUV     : TEXCOORD3;
#else
	float4 screenCoord : TEXCOORD3;
	float4 lighting    : TEXCOORD4;
#endif
	float4 camDist_ws  : TEXCOORD5;
	float4 pos_ws      : TEXCOORD6;
	float4 surfNrm_ws   : TEXCOORD7;
};



pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 worldViewMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4x4 worldMatrix,
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
	
	float3 nrm = normalize(I.normal.xyz);
  
    float l_dot = dot(nrm, l_dir_obj_nrm);
    float3 l_cross = cross(nrm, l_dir_obj_nrm);
    float c_dot = dot(nrm, c_dir_obj_nrm);
    float3 c_cross = cross(nrm, c_dir_obj_nrm);
  
    float l_sin = sqrt(dot(l_cross, l_cross));
    float l_cos = l_dot;
    float l_tan = l_sin / (l_cos);
    float c_sin = sqrt(dot(c_cross, c_cross));
    float c_cos = c_dot;
    float c_tan = c_sin / (c_cos);
  
    float3 a_vec = l_cross / (l_sin);
    float3 b_vec = cross(nrm, a_vec);
    float3 l_proj = dot(b_vec, l_dir_obj_nrm) * b_vec;
    float3 c_proj = (dot(a_vec, c_dir_obj_nrm) * a_vec) + (dot(b_vec, c_dir_obj_nrm) * b_vec);
  
    float both_cos = dot(l_proj, c_proj) / (sqrt(dot(l_proj, l_proj) * dot(c_proj, c_proj)));
  
  //complete formula for dynamic roughness/albedo input:
  
	//float r_scal = pow(roughness, 2);
	//float A_scal = 1.0 - 0.5 * (r_scal / (r_scal + 0.33));
	//float B_scal = 0.45 * (r_scal / (r_scal + 0.09));
  
	//float diffuse = (albedo / 3.14159265) * l_cos * (A_scal + (B_scal * max(0.0, both_cos) * max(l_sin, c_sin) * min(l_tan, c_tan)));
	
  //pre-calculated formula, chosen roughness = 0.3, chosen albedo = 0.3:
  
	float A_scal = 0.89285714f;
	float B_scal = 0.225f;
  
	float diffuse = 0.09549297f * l_cos * (A_scal + (B_scal * max(0.0, both_cos) * max(l_sin, c_sin) * min(l_tan, c_tan)));
	float specular = pow(dot(c_dir_obj_nrm, ((2.0 * dot(nrm, l_dir_obj_nrm) * nrm) - l_dir_obj_nrm)), 15);

  // calc selfshadowning
	float FoFSP = 1.0 - saturate(dot(nrm4.xyz, l_dir_obj_nrm));
    float density = 1.0;
	float FoFS = saturate(((4 * (shell / density)) - (3 * FoFSP)) / FoFSP);
	float self_shadow = min(FoFS, saturate(dot(nrm4.xyz, l_dir_obj_nrm) + 0.5));
	float depth_shadow = shell * (1.0 - lowest_shell_darkness) + lowest_shell_darkness;

  // store
	O.lighting = float4(diffuse, specular, 1.0, self_shadow);

  // texture coords
	float4 pos_ws_inp = mul(pos4, worldMatrix);
	O.texcoord0 = float4(I.texcoord.xy, shell, depth_shadow);
	O.surfNrm_ws = mul(nrm4, worldMatrix);
	O.camDist_ws = camera_pos - pos_ws_inp;
	O.pos_ws = pos_ws_inp;
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
	  uniform samplerCUBE textureCube,
      uniform float4      fog_color,
      uniform float4      light_col_amb,
      uniform float4      light_col_diff)
	  //uniform float4      system_data)
	  //uniform float       sc_time)
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
	  
  //float time_current = system_data.x;
  //float time_startofgame = sc_time;

  //get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

  //sample from fur texture
    s2half4 fur_mask = tex3D(textureVolume, float3(5.0 * I.texcoord0.xy, I.texcoord0.z));
    clip(fur_mask.a*tex0.a-0.1f);

    s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);

  //ambient color
    float3 amb_col = light_col_amb.xyz * tex0.xyz;
    float3 amb_glow = light_col_amb.xyz * tex1.xyz;

  //diffuse color
	float3 diff_both = I.lighting.w * I.lighting.x * light_col_diff.xyz;
    float3 diff_col = diff_both * tex0.xyz;
    float3 diff_glow = diff_both * tex1.xyz;
	
  //specular (with gamma correction)
	float spec_both = I.lighting.w * I.lighting.y * dot(float3(0.2126, 0.7152, 0.0722), light_col_diff.xyz) * sqrt(3);
    float3 spec_col = spec_both * max(dot(float3(0.2126, 0.7152, 0.0722), tex0.xyz), 0.5f) * normalize(light_col_diff.xyz + tex0.xyz);
    float3 spec_glow = spec_both * max(dot(float3(0.2126, 0.7152, 0.0722), tex1.xyz), 0.5f) * normalize(light_col_diff.xyz + tex1.xyz);
	
  //compose
	float final_red_col = max(max(amb_col.x, diff_col.x), spec_col.x);
	float final_green_col = max(max(amb_col.y, diff_col.y), spec_col.y);
	float final_blue_col = max(max(amb_col.z, diff_col.z), spec_col.z);

	float final_red_glow = max(max(amb_glow.x, diff_glow.x), spec_glow.x);
	float final_green_glow = max(max(amb_glow.y, diff_glow.y), spec_glow.y);
	float final_blue_glow = max(max(amb_glow.z, diff_glow.z), spec_glow.z);

  //final color
    float3 final_col = 2.0 * I.texcoord0.w * float3(final_red_col, final_green_col, final_blue_col);
    float3 final_glow = 2.0 * I.texcoord0.w * float3(final_red_glow, final_green_glow, final_blue_glow);
	
  //calculate alpha
	float alpha_diff = tex0.a;
	float alpha_glow = tex1.a;

  // out
	O.col0 = float4(final_col, alpha_diff);
	O.col1 = float4(final_glow, alpha_glow);
	
#endif

	  return O;
  } 

#endif
