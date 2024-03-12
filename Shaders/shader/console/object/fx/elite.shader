// skorpionshield
#include "S2Types.shader"

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
	float  globalAlpha  : TEXCOORD4;
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
 ,uniform float4   viewport_data
#endif  
  )
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float extruSize = param.x;
  float currentHeightAlpha = param.y;
  
  
  currentHeightAlpha = abs(pos4.z - currentHeightAlpha) ;
  
  currentHeightAlpha = 1.0 - saturate(currentHeightAlpha / 10.f);
  O.globalAlpha = currentHeightAlpha * 4.0f ;
  

  // extrude
  pos4.xyz += extruSize * I.normal;
	
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * I.tangent;
	objToTangentSpace[1] = -1.0 * I.binormal;
	objToTangentSpace[2] = I.normal;
	
  #ifndef PS3_IMPL //TB:Not sure what this is supposed to do...	
    // vertex-position in screen space
	  O.screenCoord.x = O.hposition.w + O.hposition.x;
	  O.screenCoord.y = O.hposition.w - O.hposition.y;
	  O.screenCoord.z = O.hposition.z;
	  O.screenCoord.w = 2.0 * O.hposition.w;
	  O.screenCoord.xy *= target_data.xy;
    #ifdef CONSOLE_IMPL
      O.screenCoord.xy /= O.screenCoord.w;
      O.screenCoord.xy  = (O.screenCoord.xy - viewport_data.xy) * viewport_data.zw;
      O.screenCoord.xy *= O.screenCoord.w;
    #endif
  #else
	  O.screenCoord=float4(O.hposition.x,-O.hposition.y,O.hposition.z,1);
	  O.screenCoord.xyz/=2*O.hposition.w;
	  O.screenCoord.xyz+=float3(0.5f,0.5f,0.5f);
	  O.screenCoord.xyzw*=O.hposition.wwww;
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
  float pulsar = param.y;
	
	// diffuse color & opacity from texture0
	s2half4 tex0 = tex2D(texture0, I.texcoord.xy + float2(depthscroll * -6.0, depthscroll * -3.0));
	s2half mask = tex2D(texture0, I.texcoord.xy * 2.0 ).w;//+ float2(depthscroll * 5.0, depthscroll * 2.0));
#ifdef PS3_IMPL
    clip(I.globalAlpha * elapsedTime * mask -0.5f);
#endif
  // out
	O.col[0] = float4(tex0.xyz ,I.globalAlpha * elapsedTime * mask ); //+ (tex1.xyz * specAlpha)
	O.col[1] = float4(tex0.xyz * mask,(I.globalAlpha + 0.2) * elapsedTime * mask);
	
	return O;
} 

