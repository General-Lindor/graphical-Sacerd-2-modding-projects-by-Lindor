// render a gr2 in the gui

#define VERT_XVERTEX
#include "extractvalues.shader"

DEFINE_VERTEX_DATA


struct pixdata {
	float4 hposition   : POSITION;
	float4 texcoord0   : TEXCOORD0;
	float4 texcoord1   : TEXCOORD1;
};

struct fragout {
	float4 col         : COLOR;
};

pixdata mainVS(appdata I,
	uniform float4    light_pos,
    uniform float4x4  worldViewProjMatrix,
	uniform float4x4  invWorldMatrix,
    uniform float4x4  vtx_matrix_array[1])
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

	// build object-to-tangent space matrix
	float3x3 objToTangentSpace;
	objToTangentSpace[0] = -1.0 * I.tangent;
	objToTangentSpace[1] = -1.0 * I.binormal;
	objToTangentSpace[2] = I.normal;

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);
	// convert light direction vector from worldspace to objectspace
	float4 l0_dir_obj = mul(light_pos, invWorldMatrix);
	// convert light direction vector from objectspace to tangentspace
	float3 l0_dir_tan = mul(objToTangentSpace, l0_dir_obj.xyz);

	// store light vector in texcoord1
	O.texcoord1 = float4(l0_dir_tan, 0.0);

	
	// texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform float4    light_col_amb,
    uniform float4    light_col_diff,
    uniform sampler2D texture0,
    uniform sampler2D texture1)
{
	fragout O;

	// get texture values
	float4 tex0 = tex2D(texture0, I.texcoord0.xy);
/*	float4 tex1 = tex2D(texture1, I.texcoord0.xy);

  // lighting
	s2half3 l0_dir   = normalize(I.texcoord1.xyz);
	s2half3 c_dir    = s2half3(0,0,1);
	s2half3 half_vec = normalize(c_dir + l0_dir);

	// get normal vector from bumpmap texture
	s2half3 nrm = normalize(tex1.xyz - s2half3(0.5, 0.5, 0.5));

	// calc sun diffuse
	s2half diff_fact = saturate(dot(l0_dir, nrm));
	light_col_diff   *= diff_fact;
	float4 sun_diff  = tex0 * light_col_amb + tex0 * light_col_diff;
	sun_diff.a = tex0.a * light_col_amb.a;

	// set output color
	O.col = sun_diff;*/
	O.col = tex0;
	return O;
} 
