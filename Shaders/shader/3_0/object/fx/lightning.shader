#include "extractvalues.shader"

// lightning

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
};

struct pixdata {
	float4 hposition    : POSITION;
	float4 texcoord0    : TEXCOORD0;
	float4 lightDir     : TEXCOORD1;
	float4 camDir_ws    : TEXCOORD2;
	float4 tan_to_wrld0 : TEXCOORD3;
	float4 tan_to_wrld1 : TEXCOORD4;
	float4 tan_to_wrld2 : TEXCOORD5;
	float4 screenCoord  : TEXCOORD6;
};

struct fragout {
	float4 col[2]      : COLOR;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4x4 worldMatrix,
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
	
	// need matrix to convert from tangentspace to worldspace
	float3x3 tangent_to_world;
	tangent_to_world = mul(objToTangentSpace, worldMatrix);
	
	// pass to fragment
	O.tan_to_wrld0 = float4(tangent_to_world[0], 0.0);
	O.tan_to_wrld1 = float4(tangent_to_world[1], 0.0);
	O.tan_to_wrld2 = float4(tangent_to_world[2], 0.0);
	
	// convert light direction vector from worldspace to objectspace
	float4 l0_dir_obj = mul(light_pos, invWorldMatrix);
	// convert light direction vector from objectspace to tangentspace
	float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz);
	// store light vector
	O.lightDir = float4(l0_dir_tan, 0.0);

	// convert camPosition into world-space and make it direction
	O.camDir_ws = camera_pos - mul(pos4, worldMatrix);

	// texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler2D   texture3,
    uniform samplerCUBE textureCube,
    uniform float4      light_col_amb,
    uniform float4      light_col_diff)
{
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	s2half4 tex2 = decode_normal( tex2D(texture2, I.texcoord0.xy) );
	
	// get trans mask value
	s2half4 tex3 = tex2Dproj(texture3, I.screenCoord);
	
	// build matrix to tranform from tangent to world-space
	float3x3 tangent_to_world;
	tangent_to_world[0] = I.tan_to_wrld0.xyz;
	tangent_to_world[1] = I.tan_to_wrld1.xyz;
	tangent_to_world[2] = I.tan_to_wrld2.xyz;
	
	// normal!
  s2half3 nrm = tex2.xyz;
	s2half3 nrm_wrld = mul(nrm, tangent_to_world);
	s2half3 c_dir_ws = normalize(I.camDir_ws.xyz);

	// calc to-face-lightning
	float is2Lightning = step(0.2, dot(nrm, I.lightDir.xyz));
	
	// wet
	float3 wet_color = saturate(nrm_wrld.z) * light_col_diff.w * light_col_diff.xyz * texCUBE(textureCube, reflect(-c_dir_ws, nrm_wrld)).xyz;
	
	// apply wet only, where there is no transparency!!
	wet_color *= 1.0 - tex3.r;
	
  // lightning
	float3 lit_color_0 = is2Lightning * light_col_amb.w;
	float3 lit_color_1 = is2Lightning * light_col_amb.w * light_col_amb.xyz;
	
	O.col[0] = float4(wet_color + lit_color_0, tex0.a);
	O.col[1] = float4(lit_color_1, 0.0);

	return O;
} 
