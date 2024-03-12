#include "extractvalues.shader"
// splinewurms

struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float2 texcoord   : TEXCOORD0;
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
    uniform float4   vtx_data_array[34])
{
	pixdata O;

  // position comes from input data array
	float4 pos4 = float4(vtx_data_array[I.normal.x].xyz, 1.0);

	// transform from fx-space into proj-space
	O.hposition = mul(pos4, worldViewProjMatrix);

  // calc(!) texcoords
	O.texcoord = float4(vtx_data_array[I.normal.x].w, I.texcoord.x , 0.0, 0.0);

	return O;
}

fragout_t mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler3D   textureVolume,
    uniform float4    light_col_amb,
   	uniform float4 param
)
{
	fragout_t O;
	s2half timer = param.x;
	
  // use gradient texture
	s2half4 gradient_col = tex2D(texture0, I.texcoord.xy);

	s2half4 volCol = tex3D(textureVolume, float3(I.texcoord.xy / 5.0 + float2(timer / 1.0,0), timer * .5)* 2.0);

  set_out_color(float4(volCol.xyz *  gradient_col.xyz * light_col_amb.xyz, 1.0));
  set_out_glow(float4(0.4 * volCol.xyz * gradient_col.xyz * light_col_amb.xyz, 0.0));
	return O;
} 
