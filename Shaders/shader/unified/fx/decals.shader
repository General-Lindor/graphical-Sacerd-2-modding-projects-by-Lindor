//#OptDef:SPASS_AMBDIF
//#OptDef:SPASS_PNT
//#OptDef:S2_FOG
//#OptDef:ENABLE_VERTEXLIGHTING

// standard

#include "extractvalues.shader"
#include "shadow.shader"
#include "lighting.shader"




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
	float4 camDist     : TEXCOORD1;
	float4 lightDist   : TEXCOORD2;
	float4 screenCoord : TEXCOORD3;
	float4 decalData   : TEXCOORD4; //float4(age,agefact,1-agefact,intensity);
#ifdef SPASS_PNT
  float4 incident_light_ws: TEXCOORD5;
#endif
#ifdef S2_FOG
  float2 depthFog    : TEXCOORD6; 
#endif
  float4 vlColor      : COLOR0;
};

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
  uniform float4   vtx_data_array[32],
  uniform float4   light_pos,
  uniform float4   camera_pos,
  uniform float4   fog_data )
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

    O.vlColor = computeVertexLightingColor(pos4,nrm4);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

#ifdef SPASS_PNT
  O.incident_light_ws = mul( pos4, worldMatrix ) - light_pos;
#endif
#ifdef S2_FOG
  O.depthFog = getFogTCs( O.hposition.w, fog_data );
#endif

//	float4 projTex = mul(pos4,projMatrix);
//	projTex.xyz *= 1.0f/projTex.w;
	

	// vertex-position in screen space
  O.screenCoord = calcScreenToTexCoord(O.hposition);

	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * I.tangent; 
	objToTangentSpace[1] = -1.0 * I.binormal;
	objToTangentSpace[2] = I.normal;

	// convert light direction vector from worldspace to objectspace
	float4 l0_dir_obj = mul(light_pos, invWorldMatrix);
	// convert light direction vector from objectspace to tangentspace
#ifdef SPASS_PNT
  float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz - I.position);
#endif

#ifdef SPASS_AMBDIF
	float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz);
#endif
  
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


#ifdef SPASS_AMBDIF
fragout mainPS(pixdata I,
    uniform sampler3D textureVolume,
    uniform sampler3D textureVolume1,
    uniform sampler2D shadow_texture,
    uniform sampler2D fog_texture,
    uniform float4    fog_color,
    uniform float4    light_col_amb,
    uniform float4    light_col_diff)
{
	fragout O; 

	// get texture values
	s2half4 tex0 = tex3D(textureVolume, I.texcoord0);
	s2half4 tex1 = tex3D(textureVolume1, I.texcoord0);

    light_col_amb     += light_calc_heroLight(I.vlColor);
    light_col_amb.rgb += I.vlColor.rgb;

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

  float3 final_color = moon_diff + shadow.z * (sun_diff + specular);
#ifdef S2_FOG
  fogDiffuse( final_color, fog_texture, I.depthFog, fog_color );
#endif

	// set output color
	O.col[0].rgb = final_color;
	O.col[0].a   = tex0.a*intensity;
	O.col[1]     = float4(0.0, 0.0, 0.0, 0.0);
	return O;
} 
#endif


/*
#ifdef SPASS_PNT
fragout mainPS(pixdata I,
    uniform sampler3D   textureVolume,
    uniform sampler3D   textureVolume1,
    uniform samplerCUBE textureCube,
    uniform sampler2D   fog_texture,
    uniform float4      fog_color,
    uniform float4      light_col_diff,
    uniform float4      light_data )
{
	fragout O; 

  	// calc distance of light
	float dist_to_light = dot(I.incident_light_ws.xyz, I.incident_light_ws.xyz);
	// build intensity from distance to light using light radius
  s2half temp_dist  = saturate(dist_to_light * light_data.z * light_data.z);
	s2half intensity = (1.0 - temp_dist) * (1.0 - temp_dist); // 1.0 - sin(1.5708 * temp_dist);
	// multiply it by intensity of ight source
	intensity *= light_data.y;
  //early out!
  clip(intensity-0.01);
#ifdef S2_FOG
  fogPnt( intensity, fog_texture, I.depthFog );
#endif

 	// shadow
  s2half shadow = 1.0;
#ifndef NO_SHADOWS
  shadow = calcPntFadeShadow( textureCube, I.incident_light_ws.xzy * light_data.z, light_data.w );
#endif


	// get normal vector from bumpmap texture

  // lighting
  s2half4 tex1    = tex3D(textureVolume1, I.texcoord0);
	s2half3 nrm     = normalize(tex1.xyz - s2half3(0.5, 0.5, 0.5));
	s2half3 l0_dir  = normalize(I.lightDist.xyz);
  s2half  theta   = saturate( dot( nrm, l0_dir ) );

  // calc lighting
  s2half4 tex0     = tex3D(textureVolume, I.texcoord0);
	tex0.a          *= I.decalData.z; 
  s2half3 sun_diff = theta * tex0 * light_col_diff.xyz;

	// calc specular
  s2half3 c_dir    = normalize(I.camDist.xyz);
	s2half3 half_vec = normalize(c_dir + l0_dir);
	float3 specular  = pow(saturate(dot(half_vec, nrm)), 20) * tex1.a * light_col_diff.xyz;

  float alpha = I.decalData.w;
        alpha = saturate(1.0f-(pow(alpha,4)));

	// set output color
	O.col[0].rgb = (sun_diff + specular) * intensity * shadow;
	O.col[0].a   = tex0.a * alpha;
	O.col[1]     = float4(0.0, 0.0, 0.0, 0.0);
	return O;
} 
#endif

*/