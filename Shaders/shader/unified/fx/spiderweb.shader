// Spinnennetz

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
  pos4 += float4(extrusion * I.normal, 0.0);
  pos4 *= float4(height ,1.0, 1.0, 1.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	
	// pass texture coords
	O.texcoord0 = I.texcoord.xyyy;

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
	
	// diffuse color & opacity from texture0
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	

  // out
	O.col[0] = float4(tex0.xyz , tex0.a* fader);
	O.col[1] = float4(0.1,0.1,0.1, 0.0);
	
	return O;
} 

