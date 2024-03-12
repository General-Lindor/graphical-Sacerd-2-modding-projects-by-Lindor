// 2nd shell sfx

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
  uniform float4x4 worldViewProjMatrix)
{
	pixdata O;

  // position
  float4 pos4 = float4(I.position, 1.0);
  
  // offset by normal
  pos4.xyz += 0.85f * I.normal.xyz;
  
  // transform
  O.hposition = mul(pos4, worldViewProjMatrix);
  // tc's
  O.texcoord = I.texcoord.xyyy;

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
  float plasma_size = 0.2;
  float plasma_speed = 0.01;
  float plasma_sharpness = 1.4;

  // get noise from texture
	// determine lookup points
	float2 lup = plasma_size * I.texcoord.xy;
	float2 lup1 = lup + plasma_speed * system_data.xx;
	float2 lup2 = lup - plasma_speed * system_data.xx;
	float4 noi1 = tex2D(texture2, lup1);
	float4 noi2 = tex2D(texture2, lup2);
	// halfspace
	float noi = abs(2 * (noi1.x + noi2.x) / 2 - 1);
	// make slimmer
	float pl = saturate(pow((1.0 - noi), plasma_sharpness));

	// just sample at given location
//	s2half4 diff_col = float4(92.0 / 255.0, 214.0 / 255.0, 6.0 / 255.0, 1.0);
	s2half4 diff_col = tex2D(texture0, I.texcoord.xy);
	s2half4 glow_int = tex2D(texture1, I.texcoord.xy);

	// color
	float3 col = 3.0 * diff_col.xyz * glow_int.xyz * pl;
	
  // out
  O.col[0] = float4(col, 1.0);
  O.col[1] = float4(0.3 * col, 1.0);

  return O;
} 
