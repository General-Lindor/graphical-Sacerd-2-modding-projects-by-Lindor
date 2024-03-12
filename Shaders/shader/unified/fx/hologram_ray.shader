// hologram ray

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
  uniform float4   target_data,
  uniform float4   param)
{
	pixdata O;

  // position
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float height = abs(sin(param.w / 10.0)) * 45.f ;

  // extrude along normal to give obj the right size
  if(pos4.y > 0.f) //spread startpoint
  {
	  pos4.y = 0.f;
	  pos4 += float4(0.0, 0.0,height / 13.0, 0.0);
  }
  else
  {
	  if(pos4.x > 0.5f)
 		  pos4 += float4(param.x -1.f,param.y,param.z + height, 0.0);
      else
 		  pos4 += float4(param.x + 1.f,param.y,param.z + (height+1.0) , 0.0);
  }

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	


	// pass texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D   texture0,
  uniform sampler2D   texture1,
  uniform float4      target_data,
  uniform float4      param,
  uniform float4 light_col_amb
  )
{
	fragout O;

	s2half fader = param.x;
	s2half pulse = param.y;
	float2 texcoord = I.texcoord0.xy + float2(0, param.y / 3.0);
	
	// diffuse color & opacity from texture0
	s2half4 tex0 = tex2D(texture0, texcoord);
	
	s2half4 alpha = tex2D(texture1,I.texcoord0.xy);

  // out
	O.col[0] = float4(tex0.xyz, alpha.a / 5.0);
//	O.col[0] = float4(alpha.a,alpha.a,alpha.a,alpha.a *  fader);
//	O.col[1] = float4(1.0f,1.0f,1.0f,1.0f);
	O.col[1] = float4(alpha.aaaa * fader * 2.0) * float4(tex0.xyz,1.0);


//	O.col[0] = 1.0;//float4(tex0.xyz, 0.0);
//	O.col[1] = 1.0;//float4(tex0.xyz, 0.0);
	
	return O;
} 

