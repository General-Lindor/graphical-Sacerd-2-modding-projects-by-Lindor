#include "extractvalues.shader"
// plasma

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

  // pass
  O.texcoord = float4(I.texcoord.xy, horizon_strength, 0.0);

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
    uniform sampler2D   texture1,
    uniform float4      param,
    uniform float4      system_data)
  {
	  fragout2 O;

    // give usefull names
    float plasma_size = param.x;
    float plasma_speed = param.y;
    float plasma_sharpness = param.z;

	  // get noise from texture
	  // determine lookup points
	  float2 lup = plasma_size * I.texcoord.xy;
	  float2 lup1 = lup + plasma_speed * system_data.xx;
	  float2 lup2 = lup - plasma_speed * system_data.xx;
	  float4 noi1 = tex2D(texture0, lup1);
	  float4 noi2 = tex2D(texture0, lup2);
	  // halfspace
	  float noi = abs(2 * (noi1.x + noi2.x) / 2 - 1);
	  // make slimmer
	  float pl = saturate(pow((1.0 - noi), plasma_sharpness));

    // plasma color is via lookup
    float4 plasma_col = tex2D(texture1, pl.xx);

    // horizon color is via lookup
    float4 horizon_col = tex2D(texture1, I.texcoord.zz);
  	
    // out
	  O.col[0] = float4(plasma_col.xyz + horizon_col.xyz, 1.0);
	  O.col[1] = float4(0.5 * (plasma_col.xyz + horizon_col.xyz), 0.0);

	  return O;
  } 
#endif