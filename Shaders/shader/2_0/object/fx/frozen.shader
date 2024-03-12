// glass

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
  float extruSize = param.x;

  // extrude
  pos4.xyz += extruSize * I.normal;
	
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * I.tangent;
	objToTangentSpace[1] = -1.0 * I.binormal;
	objToTangentSpace[2] = I.normal;
	
	// vertex-position in screen space
	O.screenCoord.x = O.hposition.w + O.hposition.x;
	O.screenCoord.y = O.hposition.w - O.hposition.y;
	O.screenCoord.z = O.hposition.z;
	O.screenCoord.w = 2.0 * O.hposition.w;
	O.screenCoord.xy *= target_data.xy;

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
  uniform sampler2D   texture5,
  uniform float4      light_col_amb,
  uniform float4      light_col_diff,
  uniform float4      param)
{
	fragout O;

  // names
  float elapsedTime = param.w;
	
	// diffuse color & opacity from texture0
	s2half4 tex0 = tex2D(texture0, I.texcoord.xy);
	// specular color from texture1
	s2half4 tex1 = tex2D(texture1, I.texcoord.xy);
	
	// refraction offset from bump-map
	s2half4 tex2 = tex2D(texture2, I.texcoord.xy);
	// get out of half-space to -1..1
	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	
	// offset
	float2 scr_offset = (I.screenCoord.z / I.screenCoord.w) * target_data.zw * nrm.xy;
	// screenpos of this pixel
	float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;
	// offset due to refraction and distance!
	float2 offs_scr_pos = scr_pos + 20.0 * scr_offset;
	
	// transparency <-> opaque mask
	s2half4 t_mask = tex2D(texture5, offs_scr_pos);
	
	// offset'ed background
	s2half4 offs_bgr = tex2D(texture4, offs_scr_pos);
	// non-offset'ed background
	s2half4 nonoffs_bgr = tex2D(texture4, scr_pos);
	
	// lerp with mask
	s2half4 bgr = lerp(nonoffs_bgr, offs_bgr, t_mask.x);

  // transform color into grey...
  s2half grey = dot(bgr.xyz, float3(0.222, 0.707, 0.071));
  // ...and then colorize it via parameter
  bgr = lerp(grey * param, bgr, 0.4);

  // lerp with opacity
  float3 amb = lerp(bgr.xyz, tex0.xyz, saturate(tex0.a + pow(I.texcoord.z, 2.0)));

  // lighting
	s2half3 l_dir = normalize(I.lightDist.xyz);
	s2half3 c_dir = normalize(I.camDist.xyz);
	s2half3 half_vec = normalize(c_dir + l_dir);

  // calc specular
	float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * tex1.xyz * light_col_diff.xyz;

  // final calc for "build-up"/"build-down" (is via alpha!)
  float alpha = step(saturate(I.texcoord.y), elapsedTime);

  // out
	O.col[0] = float4(amb + specular, alpha);
	O.col[1] = float4(specular, 0.0);
	
	return O;
} 

