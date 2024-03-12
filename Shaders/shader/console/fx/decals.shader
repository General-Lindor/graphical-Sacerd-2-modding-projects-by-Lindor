//#OptDef:CONSOLE_IMPL

#include "S2Types.shader"

// standard
struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float4 texcoord0   : TEXCOORD0; //u,v,decaltype,starttime
	float2 texcoord1   : TEXCOORD1; //intensity,dummy
};

struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0; //u,v,decaltype,starttime
#ifdef CONSOLE_IMPL
	float4 decalData   : TEXCOORD1; //float4(age,agefact,1-agefact,intensity);
#else
	float4 camDist     : TEXCOORD1;
	float4 lightDist   : TEXCOORD2;
	float4 screenCoord : TEXCOORD3;
	float4 decalData   : TEXCOORD4; //float4(age,agefact,1-agefact,intensity);
#endif
};

#if defined(SM1_1)
  struct fragout {
	  float4 col        : COLOR;
  };
#elif defined(CONSOLE_IMPL)
  struct fragout {
	  s2half4 diffuse  : COLOR0;
	  s2half4 specular : COLOR1;
  };
#else
  struct fragout {
	  float4 col[2]      : COLOR;
  };
#endif


//NOTE:
//every entry in vtx_data_array  -> float4(maxAge,scaleSpeed,depth,1/maxage);
//param                          -> float4(curTime,0,0,0); 
//I.data                         -> float2(decalType,startTime)
pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4x4 projMatrix,
  uniform float4   param,
  uniform float4   vtx_data_array[32],
  uniform float4   light_pos,
  uniform float4   camera_pos)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);


	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

//	float4 projTex = mul(pos4,projMatrix);
//	projTex.xyz *= 1.0f/projTex.w;
	
#ifndef CONSOLE_IMPL
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
#endif
	int decalType    = ((int)I.texcoord0.z);
	float startTime  = I.texcoord0.w;
	float intensity  = I.texcoord1.x;

	float4 decalMapping = vtx_data_array[decalType];
	float age           = param.x-startTime;
	float agefact		    = age*decalMapping.w; 
	agefact             = pow(agefact,3);
	float scale         = 1.0f/min(age*decalMapping.y,1);

	// texture coords
	O.texcoord0  = float4(I.texcoord0.xy*scale,decalMapping.z,1);
	O.texcoord0 += float4(0.5f,0.5f,0,0);
	O.decalData  = float4(age,agefact,1-agefact,intensity);
	return O;
}

/*
fragout mainPS(pixdata I,
    uniform sampler2D shadow_texture,
	uniform sampler3D textureVolume,
    uniform float4    light_col_amb,
    uniform float4    light_col_diff)
{
	fragout O;
	// get texture values
	s2half4 tex0  = tex3D(textureVolume, I.texcoord0);
	tex0.a       *= I.decalData.z;
	O.col[0] = tex0;
	O.col[1] = float4(0,0,0,tex0.a);

	O.col[0] = float4(1,0,1,1);

	return O;
} 
*/
#ifdef CONSOLE_IMPL
#include "DeferredMaterials.shader"
fragout mainPS(pixdata I,
    uniform sampler3D textureVolume,
    uniform sampler3D textureVolume1,
    uniform float4    light_col_amb,
    uniform float4    light_col_diff)
{
	fragout O; 

	s2half4 tex0 = tex3D(textureVolume, I.texcoord0);
	s2half4 tex1 = tex3D(textureVolume1, I.texcoord0);

	tex0.a       *= I.decalData.z; 

	float intensity = I.decalData.w;
	
	float intensityPow    = saturate(1.0f-(pow(intensity,4)));
	
	O.diffuse  = s2half4(tex0.xyz,              tex0.a * intensityPow); // for fade out
	O.specular = s2half4(s2half3(1,1,1)*tex1.a, 0.f ); // !No Glow! was: tex0.a * intensityPow * 0.5f);

	return O;
}
#else
fragout mainPS(pixdata I,
    uniform sampler3D textureVolume,
    uniform sampler3D textureVolume1,
    uniform sampler2D shadow_texture,
    uniform float4    light_col_amb,
    uniform float4    light_col_diff)
{
	fragout O; 

	// get texture values
	s2half4 tex0 = tex3D(textureVolume, I.texcoord0);
	s2half4 tex1 = tex3D(textureVolume1, I.texcoord0);

	tex0.a       *= I.decalData.z; 
	// get shadow term from shadow texture
	s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);

	// get normal vector from bumpmap texture
	s2half3 nrm = normalize(tex1.xyz - s2half3(0.5, 0.5, 0.5));

  // lighting
	s2half3 l0_dir   = normalize(I.lightDist.xyz);
	s2half3 c_dir    = normalize(I.camDist.xyz);
	s2half3 half_vec = normalize(c_dir + l0_dir);

  float  diff_fact  = saturate(dot(l0_dir, nrm));
	// calc sun diffuse
	float3 sun_diff = light_col_diff.xyz * tex0.rgb * diff_fact;

  float  amb_fact  = (0.5 + saturate(dot(c_dir, nrm)));
  // calc moon diffuse
  float3 moon_diff = light_col_amb.xyz * tex0.rgb * amb_fact;

	// calc specular
	float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * tex1.a * light_col_diff.xyz;

  float intensity = I.decalData.w;
  intensity       = saturate(1.0f-(pow(intensity,4)));
#if defined(SM1_1)
	O.col.rgb = tex0.rgb;
	O.col.a = tex0.a * intensity;
#else
	// set output color
	O.col[0].rgb = moon_diff + shadow.z * (sun_diff + specular);
	O.col[0].a = tex0.a*intensity;
	O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
#endif
	return O;
} 
#endif//CONSOLE_IMPL