#include "extractvalues.shader"
// deflector

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
};

struct pixdata {
	float4 hposition  : POSITION;
  float4 texcoord   : TEXCOORD0;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4   camera_pos,
  uniform float4   param)
{
	pixdata O;

  // position
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float extrusion = param.x;
  float impact_size = param.y;
  float impact_rot = param.z;

  // extrude along normal to give sphere the right size
  pos4 += float4(extrusion * I.normal, 0.0);

	// convert camera direction vector from worldspace to objectspace
	float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	// calc direction vector from vertex position to camera-position
	c_dir_obj -= pos4;
  // calc "horizon" per-vertex
  float horizon_strength = 1.0 - abs(dot(normalize(c_dir_obj.xyz), I.normal));

	// transform
	O.hposition = mul(pos4, worldViewProjMatrix);

  // calc impact texcoords at ecuador:
  // center:
  float2 itc = I.texcoord.xy - float2(0.5, 0.5);
  // rotate:
	float2x2 tcRotation;
	tcRotation[0] = float2(cos(impact_rot), sin(impact_rot));
	tcRotation[1] = float2(-sin(impact_rot), cos(impact_rot));
	itc = mul(itc, tcRotation);
	// scale:
	itc *= impact_size;
	// re-offset:
	itc += float2(0.5, 0.5);

  O.texcoord = float4(itc, horizon_strength, 0.0);

	return O;
}

#if defined(SM1_1)
  //////////////////////////////////////////////////////////
  //SM1_1 code path
  //////////////////////////////////////////////////////////
  fragout1 mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform float4      param,
    uniform float4      system_data)
  {
	  fragout1 O;
	  float4 noi1 = tex2D(texture0, I.texcoord.xy);
	  O.col = float4(noi1.xyz, 1.0);
	  return O;
  } 
#else
  //////////////////////////////////////////////////////////
  // >SM2_0 code path
  //////////////////////////////////////////////////////////
  fragout2 mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform float4      param,
    uniform float4      system_data)
  {
	  fragout2 O;
	  
    // give usefull names
    float impact_intensity = param.x;
    float horizon_intensity = param.y;
	  
	  // lightning at impact
	  s2half4 tex0 = tex2D(texture0, I.texcoord.xy);

    // horizon color is via lookup
    float4 horizon_col = float4(I.texcoord.zzz, 0.0);
    
    // calc out
    float3 c_out = impact_intensity * tex0.xyz + horizon_intensity * horizon_col.xyz;
  	
    // out
	  O.col[0] = float4(c_out, 1.0);
	  O.col[1] = float4(tex0.a * c_out, 0.0);

	  return O;
  } 
#endif