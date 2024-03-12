// Portal

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

  // position
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float extrusion = param.x;
  float height = param.y;
  float intensity = param.z;

  // extrude along normal to give obj the right size
//  pos4 += float4(extrusion * I.normal, 0.0);
  pos4 *= float4( height, extrusion, height,  1.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// pass texture coords
	O.texcoord0 = I.texcoord.xyyy * float4(1,1,1,1);

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform sampler2D   texture2,
  uniform sampler2D   texture4,
  uniform sampler2D   texture5,
  uniform float4      param
  )
{
	fragout O;
	s2half fader = param.x;
	s2half faderm1 = 1.0 - fader;
	s2half timer = param.y;
	
	// diffuse color & opacity from texture0
	float2 texcoordFadeIn = I.texcoord0.xy + float2(-timer / 3.0,0);
	float2 texcoordFadeIn2 = texcoordFadeIn;
	texcoordFadeIn.x = texcoordFadeIn.x + ((faderm1 + 0.15) * sin(((texcoordFadeIn.y + timer * 3.0) * 6.28) )) / 3.0;
	texcoordFadeIn2.x = texcoordFadeIn2.x + ((fader + 0.15) * sin(((texcoordFadeIn.y + timer * 3.0) * 6.28) )) / 3.0;
	s2half4 tex0 = tex2D(texture0, texcoordFadeIn);
	s2half4 tex1 = tex2D(texture1, texcoordFadeIn2);
	s2half4 alpha = tex2D(texture2, I.texcoord0.xy + float2(-timer ,0.0));
	s2half alpha2 = 1.0 - alpha.x;
	s2half g1 = alpha.a;
	s2half g2 = tex2D(texture2, float2(I.texcoord0.x + timer / 3.0,1.0 - I.texcoord0.y)).a;
	
	g1 = g1* g2;
	
	tex0 = tex0 * fader + tex1 * faderm1;

  // out
//	if(alpha.x < 0.05)
//	O.col[0] = float4(tex0.xyz , .75 * (alpha.x));
//		else
	O.col[0] = float4(tex0.xyz , .75);
	O.col[1] = float4(g1.x * 0.22, g1.x * 0.62, g1.x * 0.72,g1.x);
	
	return O;
} 

