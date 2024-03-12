// spell he kristallhaut
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
	float4 camDist_ts   : TEXCOORD2;
	float4 camDist_ws   : TEXCOORD3;
	float4 lightDist    : TEXCOORD4;
  float4 tan_to_wrld0 : TEXCOORD5;
  float4 tan_to_wrld1 : TEXCOORD6;
  float4 tan_to_wrld2 : TEXCOORD7;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 worldMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4   light_pos,
  uniform float4   camera_pos
#ifdef XENON_IMPL
 ,uniform float4   viewport_data
#endif
  )
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
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

  O.screenCoord = O.hposition;
//   #ifndef PS3_IMPL //TB:Not sure what this is supposed to do...	
//     // vertex-position in screen space
// 	  O.screenCoord.x = O.hposition.w + O.hposition.x;
// 	  O.screenCoord.y = O.hposition.w - O.hposition.y;
// 	  O.screenCoord.z = O.hposition.z;
// 	  O.screenCoord.w = 2.0 * O.hposition.w;
// 	  O.screenCoord.xy *= target_data.xy;
//     #ifdef CONSOLE_IMPL
//       O.screenCoord.xy /= O.screenCoord.w;
//       O.screenCoord.xy  = (O.screenCoord.xy - viewport_data.xy) * viewport_data.zw;
//       O.screenCoord.xy *= O.screenCoord.w;
//     #endif
//   #else
// 	  O.screenCoord=float4(O.hposition.x,-O.hposition.y,O.hposition.z,1);
// 	  O.screenCoord.xyz/=2*O.hposition.w;
// 	  O.screenCoord.xyz+=float3(0.5f,0.5f,0.5f);
// 	  O.screenCoord.xyzw*=O.hposition.wwww;
//   #endif	

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

  // convert camPosition into world-space and make it direction
  O.camDist_ws = camera_pos - mul(pos4, worldMatrix);

	// pass texture coords (pre multi here!)
	O.texcoord = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata     I,
               float2      vPos : VPOS,
       uniform sampler2D   texture0,
       uniform sampler2D   texture2,
       uniform sampler2D   texture4,
       uniform sampler2D   texture5,
       uniform samplerCUBE textureCube,
       uniform float4      light_col_amb,
       uniform float4      light_col_diff,
       uniform float4      param)
{
	fragout O;

  // names
  float elapsedTime = param.w;
	
	// diffuse color & opacity from texture0
//	s2half4 tex0 = tex2D(texture0, I.texcoord.xy);
	
	// nrm from bump-map
	s2half4 tex2 = tex2D(texture2, I.texcoord.xy);
	// get out of half-space to -1..1
	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));

    // screenpos of this pixel, zw is refracted
    float4 ofs_scr_pos = RefractionOffsets(false, vPos.xy, 20, nrm.xy);
    float depth = DEPTH_SAMPLE(texture5, ofs_scr_pos.zw).x;
       
    // offset'ed background
    float surfaceZ = I.screenCoord.w;
    s2half4 bgr = tex2D(texture4, (depth<surfaceZ) ? ofs_scr_pos.xy : ofs_scr_pos.zw );


// 	// offset
// 	float2 scr_offset = (I.screenCoord.z / I.screenCoord.w) * target_data.zw * nrm.xy;
// 	// screenpos of this pixel
// 	float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;
// 	// offset due to refraction and distance!
// 	float2 offs_scr_pos = scr_pos + 5.0 * scr_offset;
// 	
// 	// transparency <-> opaque mask
//   #ifdef CONSOLE_IMPL
//     float surfaceZ = I.screenCoord.w/2.0;
//     float depth = DEPTH_SAMPLE(texture5, offs_scr_pos).x;
//     s2half4 t_mask = (depth<surfaceZ) ? 0 : 1;      
//   #else	    
// 	  s2half4 t_mask = tex2D(texture5, offs_scr_pos);
//   #endif		
// 	
// 	// offset'ed background
// 	s2half4 offs_bgr = tex2D(texture4, offs_scr_pos);
// 	// non-offset'ed background
// 	s2half4 nonoffs_bgr = tex2D(texture4, scr_pos);
// 	
// 	// lerp with mask
// 	s2half4 bgr = lerp(nonoffs_bgr, offs_bgr, t_mask.x);

  // transform color into grey...
  s2half grey = dot(bgr.xyz, float3(0.222, 0.707, 0.071));
  // ...and then colorize it via parameter
  bgr = lerp(grey * param, bgr, 0.4);

  // lighting
	s2half3 l_dir = normalize(I.lightDist.xyz);
	s2half3 c_dir_ts = normalize(I.camDist_ts.xyz);
  s2half3 c_dir_ws = normalize(I.camDist_ws.xyz);
	s2half3 half_vec = normalize(c_dir_ts + l_dir);
	
  // build matrix to tranform from tangent to world-space
  float3x3 tangent_to_world;
  tangent_to_world[0] = I.tan_to_wrld0.xyz;
  tangent_to_world[1] = I.tan_to_wrld1.xyz;
  tangent_to_world[2] = I.tan_to_wrld2.xyz;
  // convert normal to world-space
  s2half3 nrm_wrld = mul(nrm, tangent_to_world);

  // calc reflection
  s2half3 env = saturate(light_col_diff.xyz + light_col_amb.xyz) * texCUBE(textureCube, reflect(-c_dir_ws, nrm_wrld)).xyz;
  env *= 0.2;
	
  // calc specular
	float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * tex2.a * saturate(light_col_diff.xyz + light_col_amb.xyz);

  // final calc for "build-up"/"build-down" (is via alpha!)
  float alpha = step(saturate(I.texcoord.y), elapsedTime);

  // out
	O.col[0] = float4(env + bgr + specular, alpha);
	O.col[1] = float4(0.5 * specular, 1);
	
	return O;
} 

