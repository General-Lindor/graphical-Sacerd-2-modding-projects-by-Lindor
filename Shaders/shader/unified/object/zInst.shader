//#OptDef:SPASS_G
//#OptDef:NORMALFORMAT_88
//#OptDef:LAYER_BIT0
// z

#include "instancing.shader"

struct appdata {
	float4 position_ID : POSITION;
	float4 binml_tan   : NORMAL;
	float2 texcoord    : TEXCOORD0;
	float4 sgn         : TEXCOORD1;
};


#ifdef SM1_1
  struct pixdata {
    float4 hposition  : POSITION;
    float4 texcoord0  : TEXCOORD0;
    float4 depthUV    : TEXCOORD1;
    float4 posInLight : TEXCOORD2;
  };
  #define VS_OUT_depthUV
  #define VS_OUT_posInLight

#else

  struct pixdata {
    float4 hposition  : POSITION;
    float4 texcoord0  : TEXCOORD0;
    float4 depthUV    : TEXCOORD1;
  };
  #define VS_OUT_depthUV

#endif



#include "shadow.shader"

pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldMatrix,
    uniform float4x4 worldViewMatrix,
    uniform float4x4 lightMatrix,
    uniform float4   zfrustum_data,
    uniform float4   instanceTextureWH )
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
	O.hposition = mul(pos4, worldViewProjMatrix);

  float camSpaceZ = pos4.x*worldViewMatrix[0][2] +  
                    pos4.y*worldViewMatrix[1][2] + 
                    pos4.z*worldViewMatrix[2][2] + 
                    worldViewMatrix[3][2];

	// only have one texture, so pass texture coords...
	#ifdef INSTANCED_DEBRIS
	  O.texcoord0 = I.texcoord.xyyy + ID.variationUVOffset.xyyy;
	#else
	  O.texcoord0 = I.texcoord.xyyy;
	#endif
  
  #ifdef VS_OUT_posInLight
    // vertex pos in light-space
    O.posInLight = mul(pos4, lightMatrix);
  #endif
  #ifdef VS_OUT_depthUV
    O.depthUV = float4(0,0,0, -camSpaceZ*zfrustum_data.w);
  #endif

	return O;
}

#ifdef SM1_1
  struct fragout {
	  float4 col        : COLOR;
  };

  ////////////////////////////////////////////////////////////////
  //SPASS_G SM1_1 codepath
  ////////////////////////////////////////////////////////////////
  fragout mainPS(pixdata I,
      uniform sampler2D texture0,
      uniform sampler2D shadow_map,
      uniform sampler3D textureVolume,
      uniform int anzIterations,
      uniform float4 shadow_data,
      uniform sampler2D gradient_texture)
  {
	  fragout O;

	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);

    // calc shadow
  #if LAYER_BIT0
    s2half shadow = 1.0;
  #else
	  s2half shadow = calcShadow(shadow_map, textureVolume, I.posInLight, float2(0.0, 0.0), shadow_data.y, shadow_data.x, anzIterations);
  #endif 
    //O.col = tex0;
    O.col.rgb = float3(0.0f, 0.0f, 0.0f);
    O.col.a = tex0.a;
	  return O;
  } 

#else
  ////////////////////////////////////////////////////////////////
  //SM20 code path
  ////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////
  //SPASS_G 
  ////////////////////////////////////////////////////////////////
  struct fragout {
    float4 col     : COLOR;
  };
  fragout mainPS(pixdata I,
                 uniform sampler2D texture0)
  {
    fragout O;
#ifndef IS_OPAQUE
    s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
    clip(tex0.a-0.5f);
#endif
  	O.col        = float4(I.depthUV.w,0,0,1);
    return O;
  } 
#endif














