// lightray

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
	float4 screenCoord : TEXCOORD1;
	float4 camDist     : TEXCOORD2;
	float4 lightDist   : TEXCOORD3;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4   light_pos,
  uniform float4   camera_pos,
  uniform float4   param)
{
	pixdata O;

  // position
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float extrusion = param.x;
  float height = param.y;
  float intensity = param.z;

  // extrude along normal to give obj the right size
  pos4 *= float4(extrusion ,height, 1.0, 1.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * I.tangent;
	objToTangentSpace[1] = -1.0 * I.binormal;
	objToTangentSpace[2] = I.normal;
	
	// vertex-position in screen space
  O.screenCoord = calcScreenToTexCoord(O.hposition);

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
	
	// pass texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform sampler2D   texture4,
  uniform sampler2D   texture5,
  uniform float4      param,
  uniform float4 light_col_amb
  )
{
	fragout O;

	s2half fader = param.x;
	float2 texcoord = I.texcoord0.xy + float2(0, param.y);
	
	// diffuse color & opacity from texture0
	s2half4 tex0 = tex2D(texture0, texcoord);
	// specular color from texture1
	s2half4 tex1 = tex2D(texture1, texcoord);
	
	s2half4 alpha = tex2D(texture1,I.texcoord0.xy) * fader;

  // out
	O.col[0] = float4(tex0.xyz * light_col_amb, alpha.a);
//	O.col[0] = float4(alpha.a,alpha.a,alpha.a,alpha.a);
//	O.col[0] = float4(1.0f,1.0f,1.0f,1.0f);
	O.col[1] = float4(0.1,0.1,0.1, 0.0);
	
	return O;
} 

