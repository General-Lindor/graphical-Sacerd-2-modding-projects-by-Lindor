// Sonic
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
  uniform float4   param
#ifdef XENON_IMPL
 ,uniform float4    viewport_data
#endif   
  )
{
	pixdata O;

  // position
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float extrusion = param.x;
  float height = param.y;
  float intensity = param.z;

  // extrude along normal to give obj the right size
  pos4 += float4(extrusion * I.normal, 0.0);
  pos4 *= float4(height ,1.0, 1.0, 1.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * I.tangent;
	objToTangentSpace[1] = -1.0 * I.binormal;
	objToTangentSpace[2] = I.normal;
	
  #ifdef CONSOLE_IMPL //TB:Not sure what this is supposed to do...	
    O.screenCoord = O.hposition;
  #else
    // vertex-position in screen space
    O.screenCoord.x = O.hposition.w + O.hposition.x;
    O.screenCoord.y = O.hposition.w - O.hposition.y;
    O.screenCoord.z = O.hposition.z;
    O.screenCoord.w = 2.0 * O.hposition.w;
    O.screenCoord.xy *= target_data.xy;
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
	O.camDist = float4(c_dir_tan, 0.0);
	
	// pass texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
          float2      vPos : VPOS,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform sampler2D   texture4,
  uniform sampler2D   texture5,
  uniform float4      param
  )
{
	fragout O;

	s2half fader = param.x;
	
	// diffuse color & opacity from texture0
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	// specular color from texture1
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	
	// refraction offset from bump-map
	s2half4 tex2 = tex2D(texture2, I.texcoord0.xy);
	// get out of half-space to -1..1
	s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
	
	// screenpos of this pixel, zw is refracted
	float4 ofs_scr_pos = RefractionOffsets(false, vPos.xy, 20, nrm.xy);

	// offset'ed background
	s2half4 bgr = tex2D(texture4, lerp(ofs_scr_pos.xy, ofs_scr_pos.zw, fader) );
  
//	// offset
//	float2 scr_offset = (I.screenCoord.z / I.screenCoord.w) * target_data.zw * nrm.xy;
//	// screenpos of this pixel
//	float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;
//	// offset due to refraction and distance!
//	float2 offs_scr_pos = scr_pos + 20.0 * scr_offset;
//	
//	// offset'ed background
//	s2half4 offs_bgr = tex2D(texture4, offs_scr_pos);
//	// non-offset'ed background
//	s2half4 nonoffs_bgr = tex2D(texture4, scr_pos);
//	
//	// lerp with mask
//	s2half4 bgr = lerp(nonoffs_bgr, offs_bgr, fader);

  // lerp with opacity
  float3 amb = lerp(bgr.xyz, tex0.xyz,  0.2f * fader);

  // out
	O.col[0] = float4(amb , 1.0);
	O.col[1] = float4(0.1,0.1,0.1, 0.0);
	
	return O;
} 

