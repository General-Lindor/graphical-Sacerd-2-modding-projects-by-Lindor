// tenergy
#include "extractvalues.shader"

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
	float4 screenCoord : TEXCOORD1;
	float4 decalData   : TEXCOORD3;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
	uniform float4 param,
	uniform float4   vtx_data_array[16])
{
	pixdata O;
	
  // position
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float extrusion = param.x;
  float height = param.y;
  float intensity  = param.z;
  float timer  = param.w;

  // extrude along normal to give obj the right size
  pos4 *= float4(extrusion ,height, 1.0, 1.0);
	
	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// vertex-position in screen space
#ifdef CONSOLE_IMPL
	O.screenCoord = O.hposition;
#else	
	O.screenCoord.x = O.hposition.w + O.hposition.x;
	O.screenCoord.y = O.hposition.w - O.hposition.y;
	O.screenCoord.z = O.hposition.z;
	O.screenCoord.w = 2.0 * O.hposition.w;
	O.screenCoord.xy *= target_data.xy;
#endif

	// pass texture coords (two channels for this shader!)
	O.texcoord0 = I.texcoord1.xyyy;
//	O.texcoord0 = float4(0.5f,0.5f,0,0);
	O.decalData  = float4(timer,0,intensity,0);


	return O;
}

fragout mainPS(pixdata I,
            float2      vPos : VPOS,
    uniform sampler2D   texture0,
    uniform sampler2D   texture1,
    uniform sampler2D   texture2,
    uniform sampler2D   texture4,
    uniform sampler3D   textureVolume,
    uniform sampler3D   textureVolume1,
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
	float system_datax = I.decalData.x;//param.x;
	
	float4 sum_col = float4(0.0, 0.0, 0.0, 0.0);
	
	for(i = 0; i < octaves; i++)
	{
		sum_col += amp * tex3D(textureVolume, float3(freq * I.texcoord0.xy, 0.03 * system_datax));
		freq *= freqm;
		amp *= ampm;	
	}
	
//    sum_col = tex3D(textureVolume, float3(I.texcoord0.xy, 0.03 * system_datax ) );

	// look up in color-fade texture
	float4 perlin_col = tex2D(texture2, 0.9 * sum_col.xy);

	// get mask
	float4 tex0 = tex2D(texture0, I.texcoord0.xy - float2(system_datax * 0.05, system_datax * 0.2));
	float justAlpha = tex2D(texture0, I.texcoord0.xy).a;
	float alpha = tex0.x * justAlpha;
	// overlay burst (radial!)
	float dist = length(I.texcoord0.xy);
	float4 ob_col = tex2D(texture0, float2(dist - 0.3 * system_datax, 0.0));
	// push_up
	float4 ob_col2 = 3.0 * ob_col + ob_col.wwww;
	
//refraction
//	s2half4 tex6 = tex2D(texture6, I.texcoord0.xy + float2(system_datax * 0.05, system_datax * 0.08));
	s2half4 tex6 = tex3D(textureVolume1, float3(I.texcoord0.xy ,0.05 * system_datax));
	// get out of half-space to -1..1
	s2half3 nrm = normalize(tex6.xyz - s2half3(0.5, 0.5, 0.5));
	
	// screenpos of this pixel, zw is refracted
	float4 ofs_scr_pos = RefractionOffsets(false, vPos.xy, 40, nrm.xy);

	// offset'ed background
	s2half4 bgr = tex2D(texture4, lerp(ofs_scr_pos.xy, ofs_scr_pos.zw, (1.0 - alpha) * 0.8 + 0.2) );
  
//	// offset
//	float2 scr_offset = (I.screenCoord.z / I.screenCoord.w) * target_data.zw * nrm.xy;
//	// screenpos of this pixel
//	float2 scr_pos = I.screenCoord.xy / I.screenCoord.w;
//	// offset due to refraction and distance!
//	float2 offs_scr_pos = scr_pos + 40.0 * scr_offset;
//	
//	// offset'ed background
//	s2half4 offs_bgr = tex2D(texture4, offs_scr_pos);
//	// non-offset'ed background
//	s2half4 nonoffs_bgr = tex2D(texture4, scr_pos);
//
//	// lerp with mask
//	s2half4 bgr = lerp(nonoffs_bgr, offs_bgr  , (1.0 - alpha) * 0.8 + 0.2);

  // lerp with opacity
  float3 amb = lerp(bgr.xyz, tex0.xyz,  0.05f * 1.0);


	// compose color & glow
//	O.col[0] = float4(amb, 1.0);
//	O.col[0] = float4(1.0,1.0,1.0, 1.0);

	O.col[0] = float4(amb, justAlpha);
	O.col[1] = float4((0.4 * perlin_col.xyz * ob_col2.xyz + 0.3 * ob_col.xyz) * I.decalData.z, alpha );
	O.col[1].xyz *= alpha;
	
	return O;
} 

