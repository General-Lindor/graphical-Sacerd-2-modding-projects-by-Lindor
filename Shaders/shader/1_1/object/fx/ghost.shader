// plasma

#define VERT_XVERTEX
#include "extractvalues.shader"

DEFINE_VERTEX_DATA


struct pixdata {
	float4 hposition  : POSITION;
  float4 texcoord   : TEXCOORD0;
};

struct fragout {
	float4 col      : COLOR;
};


pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4   camera_pos)
{
	pixdata O;

  // position
  float4 pos4 = float4(I.position, 1.0);

  // convert camera direction vector from worldspace to objectspace
  float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
  // calc direction vector from vertex position to camera-position
  c_dir_obj -= pos4;
  // calc "horizon" per-vertex
  float horizon_strength = 0.5 + 0.5 * abs(dot(normalize(c_dir_obj.xyz), I.normal));

  // transform
  O.hposition = mul(pos4, worldViewProjMatrix);

  // pass
  O.texcoord = float4(I.texcoord.xy, horizon_strength, 0.0);

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform float4      system_data)
{
	fragout O;

  // give usefull names
  float plasma_size = 0.015;
  float plasma_speed = 0.001;
  float plasma_sharpness = 3.5;

  // get noise from texture
  // determine lookup points
  float4 noi1 = tex2D(texture0, I.texcoord.xy);
  
  O.col.xyz = noi1.rgb;
  O.col.a = 1.0;

  return O;
} 
