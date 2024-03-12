// terrain t-energy
#define VERT_XVERTEX
#include "extractvalues.shader"

struct small_appdata
{
	float	height:position;
	float4	uvn:color;
};

  struct appdata {
	  float3 position   : POSITION;
	  float3 normal     : NORMAL;
	  float3 tangent    : TANGENT;
	  float3 binormal   : BINORMAL;
	  float2 texcoord   : TEXCOORD0;
	  float2 data       : TEXCOORD1;
  };

  struct pixdata {
	  float4 hposition   : POSITION;
	  float4 texcoord    : TEXCOORD0;
	  float4 worldpos    : TEXCOORD1;
  };

  struct fragout {
	  float4 col0      : COLOR0;
	  float4 col1      : COLOR1;
#ifdef PS3_IMPL
	  float4 col2      : COLOR2;
#endif
  };

  pixdata mainVS(small_appdata sI,
	  uniform float4    weather_pos,
	  uniform float4x4 worldViewProjMatrix)
  {
	  pixdata O;
  	
		appdata I;
		// Do all the decompression here, compiler will optimize and remove unused calculations

		// Please do not change this code, as it has been carefully reordered to trick the optimizer
		// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
		float4 scaler = sI.uvn.xyxy * float4(weather_pos.zw * 42.5, 42.5, 42.5);	// Rescale from 0/255..6/255 to 0..1
		I.position = float3(scaler.xy + weather_pos.xy, sI.height);
		I.data.xy = I.texcoord.xy = scaler.zw;	
		// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

		I.normal.xy = sI.uvn.zw*2-1;
		I.normal.z = sqrt(1-dot(I.normal.xy,I.normal.xy));
		
		I.binormal = normalize(cross(float3(I.normal.z, 0, -I.normal.x), I.normal));
		I.tangent  = normalize(cross(I.normal, float3(0, I.normal.z, -I.normal.y)));

	  float4 pos4 = float4(I.position, 1.0);

	  // vertex pos
	  O.hposition = mul(pos4, worldViewProjMatrix);

	  // pass tc's
	  O.texcoord = I.texcoord.xyyy;
	  O.worldpos = I.position.xyyy * 0.01;

	  return O;
  }


  fragout mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D texture1,
      uniform sampler2D texture2,
      uniform sampler2D texture3,
      uniform sampler3D textureVolume,
      uniform float4    param,
      uniform float4    system_data)
  {
	  fragout O;

	  // need blend texture
	  s2half4 blend_tex = tex2D(texture2, I.texcoord.xy);
    // mask blend texture
    s2half4 final_blend = blend_tex * param;
    // add to final intensity
    s2half final_intensity = saturate(final_blend.x + final_blend.y + final_blend.z + final_blend.w);

    // t-energy power lines ================================================================================
	  float2 lup = 0.018 * I.worldpos.xy;
	  float2 lup1 = lup + 0.0007 * system_data.xx;
	  float2 lup2 = lup - 0.0007 * system_data.xx;
	  float4 noi1 = tex2D(texture3, lup1);
	  float4 noi2 = tex2D(texture3, lup2);
	  // halfspace
	  float noi = abs(2 * (noi1.x + noi2.x) / 2 - 1);
	  // make slimmer
	  float power_line = saturate(pow((1.0 - noi), 80.0));

    // t-energy ============================================================================================
	  int i, octaves = 3;
	  float ampi = 0.652;
	  float ampm = 0.408;
	  float freqi = 0.94;
	  float freqm = 2.88;
  	
	  float freq = freqi;
	  float amp = ampi;
  	
	  float4 sum_col = float4(0.0, 0.0, 0.0, 0.0);
  	
	  for(i = 0; i < octaves; i++)
	  {
		  sum_col += amp * tex3D(textureVolume, float3(freq * I.worldpos.xy, 0.03 * system_data.x));
		  freq *= freqm;
		  amp *= ampm;	
	  }
  	
	  // look up in color-fade texture
	  float4 perlin_col = tex2D(texture1, 0.9 * sum_col.xy);

    // border glow =========================================================================================
    s2half border_glow = 3.0 * pow(sin(pow(final_intensity, 0.4) * 3.14159), 30.0);
  	
	  // compose color & glow ================================================================================
	  // overlay burst from power_lines
	  float dist = length(I.texcoord.xy);
	  float4 ob_col = float4(power_line.xxx + border_glow.xxx, 0.5);
	  // push_up
	  float4 ob_col2 = 3.0 * ob_col + ob_col.wwww;

	  O.col0 = float4(perlin_col.xyz * ob_col2.xyz + 0.5 * ob_col.xyz, 1.0);
	  O.col0.xyz *= final_intensity;
	  O.col1 = float4(0.4 * perlin_col.xyz * ob_col2.xyz + 0.3 * ob_col.xyz, 1.0);
	  O.col1.xyz *= final_intensity;
#ifdef PS3_IMPL
	  O.col2 = O.col0;
#endif
	  return O;
  } 
