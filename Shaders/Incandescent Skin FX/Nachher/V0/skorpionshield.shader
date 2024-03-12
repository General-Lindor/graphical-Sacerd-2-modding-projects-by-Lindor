// skorpionshield

#include "extractvalues.shader"

struct appdata {
	float3 position     : POSITION;
	float3 normal       : NORMAL;
	float3 tangent      : TANGENT;
	float3 binormal     : BINORMAL;
	float2 texcoord     : TEXCOORD0;
	float2 data         : TEXCOORD1;
};

struct pixdata {
	float4 hposition    : POSITION;
	float2 texcoord     : TEXCOORD0;
	float4 screenCoord  : TEXCOORD1;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4   light_pos,
  uniform float4   camera_pos,
  uniform float4   param)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// vertex-position in screen space
	O.screenCoord = calcScreenToTexCoord(O.hposition);
	
	// pass texture coords (pre multi here!)
	O.texcoord = I.texcoord.xy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform float4      param,
  uniform float4      system_data)
{
	fragout O;

  // names
  float elapsedTime = param.w;
  float depthscroll = param.x;
  float time = system_data.x;
	
	// diffuse color & opacity from texture0
	s2half4 tex0 = tex2D(texture0, I.texcoord.xy + time * float2(0.05f, 0.05f));
    
    // glow
    //float intensity = sin(I.texcoord.x * 0.05f) * sin((I.texcoord.y + time) * 0.05f);
    //intensity *= intensity;
    //intensity = pow(intensity, 20.0f);
    //float glow = max(tex0.x, max(tex0.y, tex0.z));
    //glow = lerp(1.0f, 1.0f / glow, intensity);

  // out
	O.col[0] = float4(tex0.xyz, tex0.w);
	O.col[1] =  float4(tex0.xyz * (0.5f + 0.5f * cos(time)), tex0.w);
	//O.col[1] =  float4(tex0.xyz * glow, tex0.w);
	
	return O;
} 

