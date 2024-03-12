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
	float4 texcoord1   : TEXCOORD1;
	float4 decalData   : TEXCOORD3;
};

struct fragout {
	s2half4 col[2]    : COLOR;
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
	

	int decalType    = ((int)I.texcoord1.z);
	float startTime  = I.texcoord1.w;
	float intensity  = I.texcoord2.x;

	float4 decalMapping = vtx_data_array[decalType];
	float age           = param.x-startTime;
	float agefact		    = age*decalMapping.w; 
	float agefact_rev   = 1.0-agefact;
	
	float fade_out     = min(1,agefact_rev*decalMapping.z);
	float anim_fact    = min(1,age*decalMapping.y);

	// pass texture coords (two channels for this shader!)
	O.texcoord0 = I.texcoord1.xyyy;
	O.texcoord0 += float4(0.5f,0.5f,0,0);
	O.texcoord1 = I.texcoord2.xyyy;
	O.decalData  = float4(age,agefact,fade_out,0);


	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler3D   textureVolume,
    uniform float4      system_data,
    uniform float4 param
	)
{
	fragout O;
	

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
		sum_col += amp * tex3D(textureVolume, float3(freq * I.texcoord0.xy, 0.03 * system_data.x));
		freq *= freqm;
		amp *= ampm;	
	}
	
//    sum_col = tex3D(textureVolume, float3(I.texcoord0.xy, 0.03 * system_data.x ) );

	// look up in color-fade texture
	float4 perlin_col = tex2D(texture2, 0.9 * sum_col.xy);

	// get mask
	float4 tex0 = tex2D(texture0, saturate(I.texcoord0.xy));
	float alpha = tex0.a * I.decalData.z * tex0.x;
	// overlay burst (radial!)
	float dist = length(I.texcoord0.xy);
	float4 ob_col = tex2D(texture0, float2(dist - 0.3 * system_data.x, 0.0));
	// push_up
	float4 ob_col2 = 3.0 * ob_col + ob_col.wwww;
	
	// compose color & glow
//	O.col[0] = float4(tex0.xyz, 1.0);
	O.col[0] = float4(perlin_col.xyz * ob_col2.xyz + 0.5 * ob_col.xyz, alpha );
	O.col[0].xyz *= alpha;
	O.col[1] = float4(0.4 * perlin_col.xyz * ob_col2.xyz + 0.3 * ob_col.xyz, alpha );
	O.col[1].xyz *= alpha;
	
#ifdef CONSOLE_IMPL
  O.col[0].xyz *= 2.f;
  O.col[1].xyz *= 2.f;
#endif	
#ifdef PS3_IMPL
        O.colCopy=O.col[0];
#endif
	return O;
} 

