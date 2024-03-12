// post render blit for godspell1
#include "s2types.shader"

struct appdata {
	float3 position   : POSITION;
	float2 texcoord0  : TEXCOORD0;
	float2 texcoord1  : TEXCOORD1;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoordCol   : TEXCOORD0;
	float4 texcoordGlow  : TEXCOORD1;
	float4 scrcoord      : TEXCOORD2;
};

struct fragout {
	float4 col        : COLOR;
};


pixdata mainVS(appdata I)
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = float4(I.position.xy, 0.0, 1.0);
	// pass texture coord
	O.texcoordGlow   = I.texcoord0.xyyy;
	O.texcoordCol    = I.texcoord0.xyyy;
	O.texcoordCol.xy = (O.texcoordCol.xy-viewport_data.xy)*viewport_data.zw;
	// pass screen coord
	O.scrcoord = I.position.xyyy;

	return O;
}



fragout mainPS(pixdata I,
  uniform sampler2D texture0,
  uniform sampler2D texture1,
  uniform sampler2D texture3,
  uniform sampler3D textureVolume,
  uniform float4    pix_data_array[2])
{
	fragout O;
	
	// get usefull names
	float streamStrength = pix_data_array[0].x;
	float streamLength = pix_data_array[0].y;
	float falloutPower = pix_data_array[0].z;
	float flashPower = pix_data_array[0].w;
	
	// colorize
	float4 spell_color = pix_data_array[1];
    
  // get original color
	s2half4 org_color = tex2D(texture0, I.texcoordCol.xy);
	org_color        += tex2D(texture1, I.texcoordGlow.xy);

#ifdef SM1_1
  O.col = org_color;
#else
  // "stream" out with offset from special texture
  s2half4 offset_tex = tex2D(texture3, I.texcoordCol.xy);
  s2half2 offset_dir = streamLength * (offset_tex.xy - float2(0.5, 0.5));
  
  offset_dir *= offset_tex.a;
  
  int i;
  float4 res = 0.0;
  float2 lup = I.texcoordCol.xy;
  for(i = 0; i < 10; i++)
  {
    lup += offset_dir;
    res += tex2D(texture0, lup);
  }
  res /= 10.0;
  
  // colorize it
  res *= spell_color;
  
  // make it grey!
  float4 res_bw = dot(res.xyz, float3(0.222, 0.707, 0.071)).xxxx;
  
  float4 new_color = streamStrength * offset_tex.a * res_bw + org_color;
  
  // apply "fallout"
  new_color = lerp(new_color, dot(res.xyz, float3(0.222, 0.707, 0.071)), falloutPower); 
  // apply "flash"
  new_color *= flashPower;

  // out
  O.col = tex3D(textureVolume, new_color);
#endif

	return O;
} 

