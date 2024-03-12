// trail

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

struct fragout {
	float4 col[2]      : COLOR;
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
  
  /*
  // calc direction vector from vertex position to camera-position
  c_dir_obj -= pos4;
  // calc "horizon" per-vertex
  float horizon_strength = 0.5 + 0.5 * abs(dot(normalize(c_dir_obj.xyz), normalize(I.normal)));
*/

  // transform
  O.hposition = mul(pos4, worldViewProjMatrix);

  // pass
  O.texcoord = float4(I.texcoord.xy, 0.0, 0.0);

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform float4      param,
  uniform float4      system_data)
{
	fragout O;
	
	// time
	float time = param.y;
	
	// along the way
	float a_way = 1.6 * (1.0 - I.texcoord.x);
	float b_way = 1.6 * (1.0 - I.texcoord.x + 0.4);
	
	// fader
	float d_way = (1.0 - I.texcoord.x / 0.4) + (1.0 - (time / 1.6)) / 0.4;
	
	// alpha
	float alpha1 = step(a_way, time);
	float alpha2 = step(time, b_way);
  float alpha = alpha1 * alpha2;	
 
  // test
  float2 tc1 = float2(I.texcoord.y, saturate(d_way));
  
  // color
	s2half4 tex0 = tex2D(texture0, tc1);

  // move noise entry coords
  float2 noise_coords = float2(5.0, 0.5) * I.texcoord.xy;

  // calc noise
  float2 lup = float2(0.13, 0.13) * noise_coords;
	float2 lup1 = lup + 0.009 * system_data.xx;
	float2 lup2 = lup - 0.009 * system_data.xx;
	float4 noi1 = tex2D(texture1, lup1);
	float4 noi2 = tex2D(texture1, lup2);
	// halfspace
	float noi = abs((noi1.x + noi2.x) - 1);
	// make slimmer
	float pl = pow((1.0 - noi), 10.0 * (1.0 - tc1.y));

  // get plasma color from tex0
  float3 plasma_col_a = pow(tc1.y, 0.8) * pl * tex0.xyz;
  float3 plasma_col_g = tex0.a * plasma_col_a;
	
	O.col[0] = float4(alpha * plasma_col_a, 1.0);
	O.col[1] = float4(alpha * plasma_col_g, 0.0);


  

  return O;
} 
