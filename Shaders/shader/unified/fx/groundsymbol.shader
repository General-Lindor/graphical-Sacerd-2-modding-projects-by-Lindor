// groundsymbol

struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float2 texcoord   : TEXCOORD0;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 data0      : TEXCOORD0;
	float4 data1      : TEXCOORD1;
};

#if defined(SM1_1)
  struct fragout {
	  float4 col        : COLOR;
  };
#else
  struct fragout {
	  float4 col[2]      : COLOR;
  };
#endif


pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4 vtx_data_array[3])
{
	pixdata O;

  // position comes from input data array
	float4 pos4 = float4(I.position, 1.0);

  // give usefull names
  float size = vtx_data_array[0].x;
  float angle = vtx_data_array[0].y;
  float layer_dist = vtx_data_array[0].z;
  float anz_layer = vtx_data_array[0].w;
  float2 color_offset = vtx_data_array[1].xy;
  float intensity = vtx_data_array[1].z;
  float2 pos_offset = vtx_data_array[2].xy;

  // size up
  pos4.xy *= size;
  pos4.z *= layer_dist;

	// rotate this offset to get rotated groundsymbol
	float2x2 gsRotation;
	gsRotation[0] = float2(cos(angle), sin(angle));
	gsRotation[1] = float2(-sin(angle), cos(angle));
	pos4.xy = mul(pos4.xy, gsRotation);

  // offset
  pos4.xy += pos_offset;

	// transform
	O.hposition = mul(pos4, worldViewProjMatrix);

  // pass texcoords and intensity as data
  O.data0 = float4(I.texcoord.xy, intensity * (saturate(3.0 * (1.0 - I.position.z) / anz_layer + 0.35 * pow(1.0 - I.position.z, 30.0))), 0.0);
  O.data1 = float4(0.2 * I.texcoord.xy + color_offset, 0.0, 0.0);

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D texture1)
{
	fragout O;

	// symbol
	s2half4 tex0 = tex2D(texture0, I.data0.xy);

  // coloring
  s2half4 tex1 = tex2D(texture1, I.data1.xy);

  // out
#if defined(SM1_1)
  O.col = I.data0.z * tex1 * tex0;
#else
	O.col[0] = I.data0.z * tex1 * tex0;
	O.col[1] = I.data0.z * tex1 * tex0;
	//O.col[1] = float4(0.0, 0.0, 0.0, 0.0);
#endif

	return O;
} 
