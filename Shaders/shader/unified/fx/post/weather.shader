// post render blit
#include "s2types.shader"

struct appdata {
	float3 position     : POSITION;
	float2 texcoord0    : TEXCOORD0;
	float2 texcoord1    : TEXCOORD1;
};

struct pixdata {
	float4 hposition     : POSITION;
	float4 texcoordCol   : TEXCOORD0;
	float4 frustumEdge   : TEXCOORD1;
	float4 camPos        : TEXCOORD2;
	float4 frustumEdge1  : TEXCOORD3;
	float4 camPos1       : TEXCOORD4;
	float4 frustumEdge2  : TEXCOORD5;
	float4 camPos2       : TEXCOORD6;
	float4 camPos_ws     : TEXCOORD7;
};

struct fragout {
	float4 col[2]        : COLOR;
};


pixdata mainVS(appdata I,
  uniform float4   vtx_data_array[24],
  uniform float4   param,
  uniform float4   camera_pos)
{
	pixdata O;

	// vertex pos already transformed
	O.hposition = float4(I.position.xy, 0.0, 1.0);
	// pass texture coord
	O.texcoordCol    = I.texcoord0.xyyy;
	O.texcoordCol.xy = (O.texcoordCol.xy-viewport_data.xy)*viewport_data.zw;
	// edge vectors
	int index  = I.texcoord1.x;
	O.frustumEdge = vtx_data_array[index];
	O.camPos = vtx_data_array[index + 4];
	O.frustumEdge1 = vtx_data_array[index + 8];
	O.camPos1 = vtx_data_array[index + 12];
	O.frustumEdge2 = vtx_data_array[index + 16];
	O.camPos2 = vtx_data_array[index + 20];
	O.camPos_ws = camera_pos;

	return O;
}

fragout mainPS(pixdata I,
  uniform sampler2D depth_map,
  uniform sampler2D texture0,
  uniform float4    param,
  uniform float4    light_col_amb)
{
	fragout O;
	
	// fetch depth values
	float depth_val  = tex2D(depth_map, I.texcoordCol.xy).x;
  

  float depthScale = depth_val-abs(param.x);
  depthScale = 1-abs(depthScale);
  depthScale = pow(depthScale,param.y*10);
  // make to blitz  
  float3 blitz_col = light_col_amb.w * float3(187.0/255, 194.0/255, 238.0/255) * smoothstep(0.4, 0.6,depthScale );

  O.col[0] = float4(blitz_col.xyz * 0.75 * light_col_amb.w,1);
  O.col[1] = O.col[0]; 
  return O;
} 

