// standard
//#OptDef:SPASS_AMBDIF
#include "S2Types.shader"


#include "shadow.shader"

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float4 texcoord0   : TEXCOORD0; //u,v,decaltype,starttime
	float2 texcoord1   : TEXCOORD1; //intensity,dummy
};


#ifdef SPASS_AMBDIF
    struct pixdata {
	    float4 hposition   : POSITION;
	    float4 texcoord0   : TEXCOORD0; //u,v,decaltype,starttime
	    float4 decalData   : TEXCOORD1; //float4(age,agefact,1-agefact,intensity);
	    float4 camDist     : TEXCOORD2;
	    float4 lightDist   : TEXCOORD3;
	    float4 screenCoord : TEXCOORD4;
    };
    #define PS_SPASS_AMBDIF_20

#endif


struct fragout {
	float4 col[2]      : COLOR;
};


//NOTE:
//every entry in vtx_data_array  -> float4(maxAge,scaleSpeed,depth,1/maxage);
//param                          -> float4(curTime,0,0,0); 
//I.data                         -> float2(decalType,startTime)
pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 worldMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4x4 projMatrix,
  uniform float4   param,
  uniform float4   vtx_data_array[16],
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
	

	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * I.tangent;
	objToTangentSpace[1] = -1.0 * I.binormal;
	objToTangentSpace[2] = I.normal;

#ifdef SPASS_AMBDIF
	// vertex-position in screen space
	O.screenCoord.x = O.hposition.w + O.hposition.x;
	O.screenCoord.y = O.hposition.w - O.hposition.y;
	O.screenCoord.z = 0.0;
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
	
#endif

	int decalType    = ((int)I.texcoord0.z);
	float startTime  = I.texcoord0.w;
	float intensity  = I.texcoord1.x;

	float4 decalMapping = vtx_data_array[decalType];
	float age           = param.x-startTime;
	float agefact		    = age*decalMapping.w; 
	float agefact_rev   = 1.0-agefact;
	
	float fade_out     = min(1,agefact_rev*decalMapping.z);
	float anim_fact    = min(1,age*decalMapping.y);
	
	
 

	// texture coords
	O.texcoord0  = float4(I.texcoord0.xy,anim_fact,1);
	O.texcoord0 += float4(0.5f,0.5f,0,0);
	O.decalData  = float4(age,agefact,fade_out,0);
	return O; 
}
 
 
#ifdef PS_SPASS_AMBDIF_20
  fragout mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D texture1,
      uniform sampler2D texture3,
      uniform sampler3D textureVolume,
      uniform sampler2D shadow_texture,
      uniform float4    system_data,
      uniform float4    light_col_amb,
      uniform float4    light_col_diff) 
  {
	  fragout O;

	  // get texture values
	  s2half4 tex0 = tex2D(texture0, I.texcoord0);
	  s2half4 tex1 = tex2D(texture1, I.texcoord0);
	  s2half4 crack = tex3D(textureVolume, I.texcoord0);

	  // get shadow term from shadow texture
	  s2half4 shadow = tex2Dproj(shadow_texture, I.screenCoord);


    // decode the normal from the normal map (move range from [0;1] to [-0.5;0.5] and normalize)
    s2half2 enc_normal = (2.0 * tex1.xy) - float2( 1,1 );
	  s2half3 nrm = float3( enc_normal, sqrt( 1.0 - dot( enc_normal, enc_normal ) ) );
    nrm         = normalize( nrm );
    
    s2half lava_mask = tex1.z;
    
    
    // calc lava
	  float fnoise;
	  float rnd = 0.0;
	  float f = 1.0;
	  float2 coord = I.texcoord0.xy + (system_data.xx * 0.015);
	  for(int i = 0; i < 4; i++)
	  {
		  fnoise = tex2D(texture3, coord * 0.2 * f).a;
		  fnoise -= 0.5;
		  fnoise *= 4.0;
		  rnd += fnoise / f; 
		  f *= 4.17;	
	  }
	  coord = I.texcoord0.xy - (system_data.xx * 0.015);
	  coord -= rnd * 0.02;
	  float4 lava_noise = tex2D(texture3, coord);
    	
    // add terms to get final lava color
    float4 lava_color = float4(lava_noise.xyz * float4(1,0.5,0,0) * (rnd + 1.0) + 0.3 * tex0.xyz, tex0.a);
    float4 lava_glow = float4(saturate(lava_color - float3(0.9, 0.9, 0.9)), 0.0);


    // lighting
	  s2half3 l0_dir   = normalize(I.lightDist.xyz);
	  s2half3 c_dir    = normalize(I.camDist.xyz);
	  s2half3 half_vec = normalize(c_dir + l0_dir);

	  // calc sun diffuse
	  float3 sun_diff  = light_col_diff.xyz * tex0.rgb * saturate(dot(l0_dir, nrm));

    // calc moon diffuse
    float3 moon_diff = light_col_amb.xyz * tex0.rgb * (0.5 + saturate(dot(c_dir, nrm)));

    // calc glow
    float3 glow_amb = tex1.a * tex0;
	  // calc specular
	  float3 specular = pow(saturate(dot(half_vec, nrm)), 20) * tex0.xyz * light_col_diff.xyz;
  	
	  float crackval = crack.a;
	  if(crackval < 0.5)
	    crackval = 0;
	  else
	    crackval = I.decalData.z;
  	  
  	
	  float transparency = tex0.a*crackval;

	  // set output color
	  O.col[0].rgb = moon_diff + shadow.z * (sun_diff + specular) + lava_color*lava_mask;
	  O.col[0].a   = transparency;

	  O.col[1].rgb = 0.5 * shadow.z * specular + glow_amb + lava_glow * lava_mask;
	  O.col[1].a   = transparency;

	  return O;
  } 
#endif

