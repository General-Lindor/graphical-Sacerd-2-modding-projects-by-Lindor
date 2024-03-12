// skorpionshield

#include "extractvalues.shader"

struct appdata {
	float3 position     : POSITION;
	float3 normal       : NORMAL;
	float3 tangent      : TANGENT;
	float3 binormal     : BINORMAL;
	float2 texcoord     : TEXCOORD0;
	float2 data         : TEXCOORD1;
};

struct pixdata {
	float4 hposition    : POSITION;
	float4 texcoord     : TEXCOORD0;
	float4 screenCoord  : TEXCOORD1;
	float4 camDist      : TEXCOORD2;
	float4 lightDist    : TEXCOORD3;
	float  v_alpha      : TEXCOORD4;
	float  v_glow       : TEXCOORD5;
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
	
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float timer = param.x / 2.0 ;

	

  float currentHeightAlpha =  1960.0 * timer ;
  currentHeightAlpha = (currentHeightAlpha - (pos4.y )) / 1960.0;
  currentHeightAlpha = saturate(currentHeightAlpha);
  if(currentHeightAlpha > 0.098 && currentHeightAlpha < 0.1)
	O.v_glow = 1.0;
  else
	O.v_glow = 0.0;
  if(currentHeightAlpha > 0.1)
  currentHeightAlpha = 1.0;
	O.v_alpha = currentHeightAlpha;

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

  // calc "horizon" per-vertex
  float horizon_strength = 1.0 - abs(dot(normalize(c_dir_obj.xyz), I.normal));
	
	// pass texture coords (pre multi here!)
	O.texcoord = float4(I.texcoord.xy, horizon_strength, 0.0);

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform sampler2D   texture4,
  uniform sampler3D   textureVolume,
  uniform float4      light_col_amb,
  uniform float4      light_col_diff,
  uniform float4      param)
{
	fragout O;

  // names
  float elapsedTime = param.w;
  float depthscroll = param.x;
	
	// diffuse color & opacity from texture0
	s2half4 tex0 = tex2D(texture0, I.texcoord.xy * 5.0);
	s2half tex0a = tex2D(texture0, I.texcoord.xy * 2.2 - depthscroll).a;
	s2half tex1a = tex2D(texture1, I.texcoord.xy + depthscroll / 4.0 ).a;
	// specular color from texture1
	s2half4 tex1 = tex2D(texture1, I.texcoord.xy);
	
	// refraction offset from bump-map
	s2half4 tex2 = tex2D(texture1, I.texcoord.xy * 5.0);
	// get out of half-space to -1..1
	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	

  // lighting
	s2half3 l_dir = normalize(I.lightDist.xyz);
	s2half3 c_dir = normalize(I.camDist.xyz);
	s2half3 half_vec = normalize(c_dir + l_dir);

  // calc specular
	float3 specular = pow(saturate(dot(half_vec, nrm)), 8) ;

  // final calc for "build-up"/"build-down" (is via alpha!)
  float alpha = I.v_alpha;

  // out
  float glowAlpha = pow(1.0 - tex0a,10);
	O.col[0] = float4( tex0.xyz * specular ,tex0a * I.v_alpha*(alpha * 5.0 + I.v_glow) / 5.0);;//float4(amb + specular,I.v_alpha*(alpha * 5.0 + I.v_glow));

  //glowing rimm on edge to "hard" shield
  if(glowAlpha < 0.01 && glowAlpha > 0.008)
  {
	glowAlpha = 1.0;
	O.col[1] =  float4(float3(0.4,0.2,0.6) + I.v_glow / 2.0, I.v_alpha * (glowAlpha + I.v_glow));//((1.0 - gloawAlpha) / 5.0 * (alpha + (I.v_glow ))));
  }
  else
	O.col[1] =  float4(tex0.xyz + I.v_glow / 1.3, I.v_alpha * (glowAlpha * 1.3 + I.v_glow));//((1.0 - gloawAlpha) / 5.0 * (alpha + (I.v_glow ))));
	
	return O;
} 

