// spell: he nebelform

#define VERT_XVERTEX
#include "extractvalues.shader"


#ifdef SM1_1
#else //SM1_1

  ////////////////////////////////////////////////////////////////
  // >SM20 code path
  ////////////////////////////////////////////////////////////////
  struct appdata {
	  float3 position    : POSITION;
	  float3 normal      : NORMAL;
	  float3 tangent     : TANGENT;
	  float3 binormal    : BINORMAL;
	  float2 texcoord    : TEXCOORD0;
	  float2 data        : TEXCOORD1;
  };

  struct pixdata {
    float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float4 fogPos      : TEXCOORD4;
  };

  struct fragout {
    float4 col[2]      : COLOR;
  };

  pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldMatrix)
  {
    pixdata O;
  	
    float4 pos4 = float4(I.position, 1.0);
  	
    // vertex pos
    O.hposition = mul(pos4, worldViewProjMatrix);
    
    // "fog" pos is needed by fragment shader
    O.fogPos = mul(pos4, worldMatrix);
    O.fogPos.z = pos4.z;
    O.fogPos = pos4;
      	
    // pass texture coords
    O.texcoord0 = I.texcoord.xyyy;

    return O;
  }

  fragout mainPS(pixdata I,
    uniform sampler2D   texture0,
    uniform sampler3D   textureVolume,
    uniform float4      system_data)
  {
    fragout O;
 	
    
    // give usefull names
    float time = system_data.x;
    
    // must convert xy to only x
    float uFog;
    
    // always some col at ground
    float4 gf_col = float4(0.0, 0.0, 0.0, 0.0);
    
    uFog = abs(sin(0.5 * time) * I.fogPos.x + cos(0.5 * time) * I.fogPos.y);
    // somewhere moving
    gf_col += tex3D(textureVolume, float3(frac(0.03 * uFog) - 0.5, -1.0 * saturate(0.013 * I.fogPos.z + 1.0 - 2.0 * frac(0.31 * time)), 0.328 * time));
    gf_col += tex3D(textureVolume, float3(frac(0.04 * uFog) - 0.5, -1.0 * saturate(0.015 * I.fogPos.z + 1.0 - 2.0 * frac(0.21 * time + 0.25)), 0.246 * time));
    gf_col += tex3D(textureVolume, float3(frac(0.02 * uFog) - 0.5, -1.0 * saturate(0.016 * I.fogPos.z + 1.0 - 2.0 * frac(0.25 * time + 0.50)), 0.146 * time));
    gf_col += tex3D(textureVolume, float3(frac(0.01 * uFog) - 0.5, -1.0 * saturate(0.014 * I.fogPos.z + 1.0 - 2.0 * frac(0.28 * time + 0.75)), 0.446 * time));
    gf_col /= 4.f;
    
    // need original texture
    s2half4 diff = tex2D(texture0, I.texcoord0.xy);
    // intensity & contrast
  #ifdef SM3_0
    float3 fogFac = pow(diff.xyz, 0.4);
  #else
    float3 fogFac = float3(1.0, 1.0, 1.0);
  #endif

    // out
    float3 final_color = fogFac * gf_col;
    float3 final_glow = gf_col.a * gf_col;

    // out
    O.col[0] = float4(final_color, 1.0);
    O.col[1] = float4(final_glow, 0.0);
  	
    return O;
  } 
#endif