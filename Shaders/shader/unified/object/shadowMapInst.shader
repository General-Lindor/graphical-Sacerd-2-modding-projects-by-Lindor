// granny2 object shadowmap

#include "instancing.shader"

struct appdata {
	float4 position_ID : POSITION;
	float4 binml_tan   : NORMAL;
	float2 texcoord    : TEXCOORD0;
	float4 sgn         : TEXCOORD1;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
};

struct fragout {
	float4 col        : COLOR;
};

pixdata mainVS(appdata I,
    uniform float4x4 lightMatrix,
    uniform float4   instanceTextureWH
    )
{
	pixdata O;

#ifdef INSTANCED_DEBRIS
	instancedata ID = extractInstanceData(I.position_ID.w, instanceTextureWH.x, instanceTextureWH.yz);
	float3 instancedPos = mul(ID.positionTransform,float4(I.position_ID.xyz, 1.0));
#else
	float3 instancedPos = I.position_ID.xyz;
#endif
	
	float4 pos4 = float4(instancedPos, 1.0);

	// vertex pos
	O.hposition = mul(pos4, lightMatrix);

	// pass texcoords to fragment shader
	#ifdef INSTANCED_DEBRIS
	  O.texcoord0 = I.texcoord.xyyy + ID.variationUVOffset.xyyy;
	#else
	  O.texcoord0 = I.texcoord.xyyy;
	#endif

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform float4 shadow_data)
{
	fragout O;
#ifdef IS_OPAQUE 
	O.col = float4( 0,0,0,1 );
#else
  #ifdef SM1_1
	  O.col = float4(shadow_data.zzz, tex2D(texture0, I.texcoord0.xy).a);
  #else
    O.col = tex2D(texture0, I.texcoord0.xy);
    clip(O.col.a-0.5f);
  #endif
#endif
	return O;
} 
