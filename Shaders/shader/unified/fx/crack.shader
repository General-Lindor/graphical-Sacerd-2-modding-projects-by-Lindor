// crack in ground


#define VERT_XVERTEX
#include "extractvalues.shader"


struct pixdata {
	float4 hposition   : POSITION;
  float4 texcoord    : TEXCOORD0;
  float4 groundPos   : TEXCOORD1;
	float4 screenCoord : TEXCOORD2;
};

#if defined(SM1_1)
  //////////////////////////////////////////////////////////
  //SM1_1 code path
  //////////////////////////////////////////////////////////

  DEFINE_VERTEX_DATA

  struct fragout {
	  float4 col      : COLOR;
  };

  pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4   zfrustum_data,
    uniform float4   camera_pos,
    uniform float4   param)
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

    // height if crack glow
    pos4 *= float4(1.0, 1.0, height, 1.0);

	  // convert camera direction vector from worldspace to objectspace
	  float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	  // calc direction vector from vertex position to camera-position
	  c_dir_obj -= pos4;
    // calc "horizon" per-vertex
    float horizon_strength = 1.0 - abs(dot(normalize(c_dir_obj.xyz), I.normal));

	  // transform
	  O.hposition = mul(pos4, worldViewProjMatrix);

	  // vertex-position in screen space
    O.screenCoord = calcScreenToTexCoord(O.hposition);

    // pass
    O.texcoord = float4(I.texcoord.xy, horizon_strength,0);
    O.groundPos = float4(pos4.xy, 0.0, intensity);

	  return O;
  }

  // ----------------------------------------------------------------------------

  fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   depth_map,
    uniform float4      param,
    uniform float4      system_data)
  {
	  fragout O;

  /*  // give usefull names
    float plasma_size = param.x;
    float plasma_speed = param.y;
    float plasma_sharpness = param.z;
    float fader = param.w;

	  // get noise from texture
	  // determine lookup points
	  float2 lup = plasma_size * I.groundPos.xy;
	  float2 lup1 = lup + plasma_speed * system_data.xx;
	  float2 lup2 = lup - plasma_speed * system_data.xx;
	  float4 noi1 = tex2D(texture0, lup1);
	  float4 noi2 = tex2D(texture0, lup2);
	  // halfspace
	  float noi = abs(2 * (noi1.x + noi2.x) / 2 - 1);
	  // make slimmer
	  float pl = saturate(pow((1.1 - noi), plasma_sharpness));

    // plasma color is via lookup
    float4 plasma_col = tex2D(texture1, pl.xx);

    // get delta intensity
	  float current_delta = abs(tex2Dproj(depth_map, I.screenCoord).x - I.texcoord.w);
    float delta_intensity = saturate((50.0 / I.texcoord.w) * current_delta);

    // get height color
    float4 height_color = tex2D(texture1, float2(delta_intensity, I.texcoord.y));

    // horizon factor
    float horizon_factor = 1.0 + 3.0 * pow(I.texcoord.z, 6.0);

    // fader in/out factor
    float fader_factor = step(2.0 * abs(I.texcoord.x - 0.5), fader);

    // out
	  O.col = float4(I.groundPos.w * fader_factor * horizon_factor * pl * height_color.xyz, 1.0);*/

	  float4 noi1 = tex2D(texture0, I.groundPos.xy);
	  O.col = float4(noi1.xyz, 1.0);

	  return O;
  } 

#else
  //////////////////////////////////////////////////////////
  // >SM2_0 code path
  //////////////////////////////////////////////////////////
  struct appdata {
	  float3 position    : POSITION;
	  float3 normal      : NORMAL;
	  float3 tangent     : TANGENT;
	  float3 binormal    : BINORMAL;
	  float2 texcoord    : TEXCOORD0;
	  float2 data        : TEXCOORD1;
  };
  struct fragout {
	  float4 col[2]      : COLOR;
  };


  pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldViewMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4   camera_pos,
    uniform float4   zfrustum_data,
    uniform float4   param)
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

    // height if crack glow
    pos4 *= float4(1.0, 1.0, height, 1.0);

	  // convert camera direction vector from worldspace to objectspace
	  float4 c_dir_obj = mul(camera_pos, invWorldMatrix);
	  // calc direction vector from vertex position to camera-position
	  c_dir_obj -= pos4;
    // calc "horizon" per-vertex
    float horizon_strength = 1.0 - abs(dot(normalize(c_dir_obj.xyz), I.normal));

	  // transform
	  O.hposition = mul(pos4, worldViewProjMatrix);
    float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
                      pos4.y*worldViewMatrix[1][2] + 
                      pos4.z*worldViewMatrix[2][2] + 
                      worldViewMatrix[3][2];

	  // vertex-position in screen space
    O.screenCoord = calcScreenToTexCoord(O.hposition);

    // pass
    O.texcoord = float4(I.texcoord.xy, horizon_strength, -camSpaceZ*zfrustum_data.w);
    O.groundPos = float4(pos4.xy, 0.0, intensity);

	  return O;
  }

  // ----------------------------------------------------------------------------
  // decode depth from 2-channel-encoded-depthbuffer
  float getDepth(float2 encoded)
  {
    return dot(encoded, float2(1.0, 1.0 / 256.0));
  }


  fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   depth_map,
    uniform float4      param,
    uniform float4      system_data)
  {
	  fragout O;

    // give usefull names
    float plasma_size = param.x;
    float plasma_speed = param.y;
    float plasma_sharpness = param.z;
    float fader = param.w;

	  // get noise from texture
	  // determine lookup points
	  float2 lup = plasma_size * I.groundPos.xy;
	  float2 lup1 = lup + plasma_speed * system_data.xx;
	  float2 lup2 = lup - plasma_speed * system_data.xx;
	  float4 noi1 = tex2D(texture0, lup1);
	  float4 noi2 = tex2D(texture0, lup2);
	  // halfspace
	  float noi = abs(2 * (noi1.x + noi2.x) / 2 - 1);
	  // make slimmer
	  float pl = saturate(pow((1.1 - noi), plasma_sharpness));

    // plasma color is via lookup
    float4 plasma_col = tex2D(texture1, pl.xx);

    // get delta intensity
	  float current_delta = abs(tex2Dproj(depth_map, I.screenCoord).x - I.texcoord.w);
    float delta_intensity = saturate((50.0 / I.texcoord.w) * current_delta);

    // get height color
    float4 height_color = tex2D(texture1, float2(delta_intensity, I.texcoord.y));

    // horizon factor
    float horizon_factor = 1.0 + 3.0 * pow(I.texcoord.z, 6.0);

    // fader in/out factor
    float fader_factor = step(2.0 * abs(I.texcoord.x - 0.5), fader);

    // out
	  O.col[0] = float4(I.groundPos.w * fader_factor * horizon_factor * pl * height_color.xyz, 1.0);
	  O.col[1] = float4(0.5 * I.groundPos.w * fader_factor * horizon_factor * pl * height_color.xyz, 0.0);

	  return O;
  } 
#endif
