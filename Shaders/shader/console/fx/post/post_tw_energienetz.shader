// post render blit
#include "s2types.shader"

struct appdata {
	float3 position     : POSITION;
	float2 texcoord0    : TEXCOORD0;
	float2 texcoord1    : TEXCOORD1;
};

struct pixdata {
	float4 hposition    : POSITION;
	float4 frustumEdge  : TEXCOORD0;
	float4 camPos       : TEXCOORD1;
};

pixdata mainVS(appdata I,
               uniform float4   vtx_data_array[8])
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = float4(I.position.xy, 0.0, 1.0);

	// edge vectors
	int index  = I.texcoord1.x;
	O.frustumEdge = vtx_data_array[index];
	O.camPos = vtx_data_array[index + 4];
	return O;
}

s2half4 mainPS(pixdata   I,
               float2    vPos : VPOS,
       uniform sampler2D depth_map,
       uniform sampler2D texture0,
       uniform sampler2D texture1,
       uniform sampler3D textureVolume) : COLOR
{
	s2half2 vTexCoord = (vPos+s2half2(0.5,0.5))*target_data.zw;

	s2half4 org_color   = tex2D(texture0, vTexCoord);

	//apply glow
	s2half4 glow = tex2D(texture1, vTexCoord);
	org_color.rgb = org_color*glow.a+glow;
	
	float  depth_val = tex2D(depth_map, vTexCoord.xy).x;
	float4 wpos = I.frustumEdge * depth_val + I.camPos;

	float4 final_color = tex3D( textureVolume, org_color );
	
	// out 
	return float4(frac(0.05 * wpos.xyz), 1);
} 

