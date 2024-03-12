// standard
#include "extractvalues.shader"

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
};

struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
	float4 camDist     : TEXCOORD1;
	float4 lightDist   : TEXCOORD2;
	float4 screenCoord : TEXCOORD3;
};

struct fragout {
	float4 col[2]      : COLOR;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4   light_pos,
  uniform float4   camera_pos)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

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
    uniform sampler2D shadow_texture,
    uniform sampler3D textureVolume,
    uniform float4    light_col_amb,
    uniform float4    light_col_diff,
    uniform float4    system_data)
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));

	// get shadow term from shadow texture
	s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

  // get animated normal
  s2half4 tex_v = tex3D(textureVolume, float3(6.0 * I.texcoord0.xy, 0.08 * system_data.x));

	// get normal vector from bumpmap texture
  s2half3 nrm_tex = tex1.xyz;
	s2half3 nrm_anim = normalize(tex_v.xyz - s2half3(0.5, 0.5, 0.5));

  // lighting
	s2half3 l0_dir = normalize(I.lightDist.xyz);
	s2half3 c_dir = normalize(I.camDist.xyz);
	s2half3 half_vec = normalize(c_dir + l0_dir);

  // calc "undead" texture color
  s2half3 tex0_undead = lerp(dot(tex0.rgb, float3(0.222, 0.707, 0.071)).xxx, tex0.rgb, 0.6);

	// calc sun diffuse
	float3 sun_diff = light_col_diff.xyz * tex0_undead * saturate(dot(l0_dir, nrm_tex));

  // calc moon diffuse
  float3 moon_diff = light_col_amb.xyz * tex0_undead * (0.5 + saturate(dot(c_dir, nrm_tex)));

  // calc glow
  float3 glow_amb = tex1.a * tex0;

	// calc specular
	float3 specular_tex = pow(saturate(dot(half_vec, nrm_tex)), 20) * tex1.xyz * light_col_diff.xyz;
	float3 specular_anim = pow(saturate(dot(half_vec, nrm_anim)), 20) * float3(0.8, 0.8, 0.9) * light_col_diff.xyz;

  // lerp between goo and normal
  float3 out0 = lerp(shadow.z * specular_anim, glow_amb + moon_diff + shadow.z * (sun_diff + specular_tex), tex_v.a);
  float3 out1 = lerp(0.5 * shadow.z * specular_anim, 0.5 * shadow.z * specular_tex + glow_amb, tex_v.a);

	// set output color
	O.col[0].rgb = out0;
	O.col[0].a = tex0.a;
	O.col[1].rgb = out1;
	O.col[1].a = tex0.a;







/*

	// get texture values
	s2half4 tex2 = tex2D(texture2, I.texcoord0.xy);

  // get caust values
  s2half4 tex0 = tex3D(textureVolume, float3(8.0 * I.texcoord0.xy, 0.08 * system_data.x));

	// get shadow term from shadow texture
	s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

	// get normal vector from bumpmap texture and from animated texture
	s2half3 nrm_map = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	s2half3 nrm_anim = normalize(tex0.xyz - s2half3(0.5, 0.5, 0.5));

  // find angle between animated normal and perpendicular
  float angle = dot(nrm_anim, float3(0.0, 0.0, 1.0));
  // use this angle to lerp between original nrm and animted
  s2half3 nrm = normalize(lerp(nrm_anim, nrm_map, angle));

  nrm = nrm_anim;

	// lighting
	s2half3 l0_dir = normalize(I.lightDist.xyz);
	s2half3 c_dir = normalize(I.camDist.xyz);
	s2half3 half_vec = normalize(c_dir + l0_dir);

	// calc specular
	float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * float3(0.7, 0.7, 0.8) * light_col_diff.xyz;

	// set output color
	O.col[0].rgb = shadow.z * specular;
	O.col[0].a = 1.0;
	O.col[1].rgb = 0.5 * shadow.z * specular;
	O.col[1].a = 0.0;
*/
	return O;
} 
