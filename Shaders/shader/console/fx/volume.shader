// volume
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
  float4 data2      : TEXCOORD2;
};

struct fragout {
	float4 col[2]      : COLOR;
};


pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
  uniform float4x4 invWorldMatrix,
  uniform float4   camera_pos,
  uniform float4   param)
{
	pixdata O;

  // give usefull names
  float radius = param.x;

  // extrude along normal to give sphere the right size
  float4 pos4 = float4(radius * I.normal, 1.0);

	// convert camera position from worldspace to objectspace
	float4 c_pos_obj = mul(camera_pos, invWorldMatrix);
	// need dir!
	float3 c_pos_dir = normalize(c_pos_obj.xyz);
	
	// calc special x-vector!
	float3 x_vec = pos4.xyz - c_pos_dir * dot(c_pos_dir, pos4.xyz);
	
	// calc special d_vec
	float3 d_vec = 2.0 * (x_vec - pos4.xyz);
	
	// length of x-vector
	float x_length = length(x_vec);
	
	// length of d-vector
	float d_length = length(d_vec);
	
	// transform
	O.hposition = mul(pos4, worldViewProjMatrix);

  // pass
  O.data0 = float4(radius, 0.0, 0.0, 0.0);
  O.data1 = float4(pos4.xyz, 0.0);
  O.data2 = float4(d_vec, 0.0);

	return O;
}

fragout mainPS(pixdata I,
  uniform samplerCUBE textureCube,
  uniform float4      system_data)
{
	fragout O;

  // give usefull names
  float radius = I.data0.x;
  
  // ray-trace start
  float3 entry_pnt = I.data1.xyx;
  float3 ray_vec = I.data2.xyz;
  
  
  
  float4 csm = texCUBE(textureCube, normalize(I.data1.xzy));
	
  // out
	O.col[0] = float4(csm.xyz, 1.0);
	O.col[1] = float4(0.0, 0.0, 0.0, 0.0);

	return O;
} 
