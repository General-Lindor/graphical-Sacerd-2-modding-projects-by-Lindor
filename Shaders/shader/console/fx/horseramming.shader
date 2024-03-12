// Spinnennetz
#include "S2Types.shader"

struct appdata {
	float3 position    : POSITION;
	float3 normal      : NORMAL;
	float3 tangent     : TANGENT;
	float3 binormal    : BINORMAL;
	float2 texcoord    : TEXCOORD0;
	float2 data        : TEXCOORD1;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 data0      : TEXCOORD0;
	float4 data1      : TEXCOORD1;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4   param)
{
	pixdata O;
	
  // position comes from input data array
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float sizex = param.x;
  float sizey = param.y;
  float intensity = param.w;

  // size up
  pos4.x *= sizey; 
  pos4.y *= sizex;



	// transform
	O.hposition = mul(pos4, worldViewProjMatrix);

  // pass texcoords and intensity as data
  O.data0 = float4(I.texcoord.xy, intensity , 0.0);
  O.data1 = float4(0.2 * I.texcoord.xy , 0.0, 0.0);

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform float4      param
  )
{
	fragout O;

	s2half timer = param.y;
	
	// diffuse color & opacity from texture0
	s2half4 tex0 = tex2D(texture1, I.data0.xy );
	s2half4 tex1 = tex2D(texture0, I.data0.xy + float2(timer / 5.0 ,timer / 6.0));
	s2half alpha = tex2D(texture0, I.data0.xy + float2(timer / 2.0 ,timer )).a;
	

  // out
	O.col[0] = float4(tex1 * float3(0.0,0.3,0.3 + sin(timer) * 0.3) * tex0.r * alpha, alpha);
//	O.col[0] = float4(0,0,0, 0);
//	O.col[0] = float4(1,1,1, 1);

	O.col[1] = float4(tex1.xyz  * tex0.xyz * alpha , 0.0);

	
	return O;
} 

