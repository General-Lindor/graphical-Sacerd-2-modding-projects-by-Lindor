// tenergy
#include "S2Types.shader"

struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float4 texcoord1  : TEXCOORD0;
	float2 texcoord2  : TEXCOORD1;

};

struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
};

struct fragout {
	float4 col[2]      : COLOR;
#ifdef PS3_IMPL
        s2half4 colCopy   : COLOR2;
#endif
};


pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
	uniform float4 param,
	uniform float4   vtx_data_array[16])
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// pass texture coords (two channels for this shader!)
	O.texcoord0 = I.texcoord1.xyyy;
	O.texcoord0 += float4(0.5f,0.5f,0,0);

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
	  uniform float4      system_data,
	  uniform float4      param
	)
{
	fragout O;
	
	// get mask
	float4 tex0 = tex2D(texture0, saturate(I.texcoord0.xy));
	float alpha = tex0.a * tex0.x;
	// overlay burst (radial!)
	float dist = length(I.texcoord0.xy);
	float4 ob_col = tex2D(texture0, float2(dist - 0.3 * system_data.x, 0.0));
	// push_up
	float4 ob_col2 = 3.0 * ob_col + ob_col.wwww;
	
	// compose color & glow
	O.col[0] = float4(ob_col2.xyz + 0.5 * ob_col.xyz, alpha );
	O.col[0].xyz *= param.x * tex0.xyz;
	O.col[1] = float4(0.4 * ob_col2.xyz + 0.3 * ob_col.xyz, alpha );
	O.col[1].xyz *= param.x * tex0.xyz;

#ifdef PS3_IMPL
        O.colCopy=O.col[0];
#endif
	return O;
} 

