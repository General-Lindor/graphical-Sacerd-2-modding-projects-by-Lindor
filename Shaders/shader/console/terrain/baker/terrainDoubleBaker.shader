// terrain baker
#include "S2Types.shader"


struct appdata {
	float3 position   : POSITION;
	float3 normal     : NORMAL;
	float3 tangent    : TANGENT;
	float3 binormal   : BINORMAL;
	float2 texcoord   : TEXCOORD0;
	float2 data       : TEXCOORD1;
};

struct small_appdata 
{
    float height : position ;
    float4 uvn : color ;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord   : TEXCOORD0;
};

struct fragout {
	float4 col[2] : COLOR;
};


pixdata mainVS(small_appdata sI,
			   uniform float4   param)
{
	appdata I;
	// Do all the reformatting here, compiler will optimize
	float3 rUV = float4(sI.uvn.xy * 42.5f,1,0);	// Rescale from 0/255..6/255 to 0..1
	
	I.position = float3(0,0,0);
	
	I.data.xy = I.texcoord.xy = rUV.xy;
	
	I.normal.xy = sI.uvn.zw*2-1;
	I.normal.z = sqrt(1-dot(I.normal.xy,I.normal.xy));
	
	I.binormal = normalize(cross(I.normal, float3(I.normal.z, 0, -I.normal.x)));
	I.tangent  = normalize(cross(I.normal, float3(0, I.normal.z, -I.normal.y))); 

	pixdata O;
 	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

  // do not use ::position but use ::texcoord for vertex-pos, since we do this one planar!!
  float2 planar_pos = float2(2.0, -2.0) * (I.texcoord.xy - float2(0.5, 0.5));
	O.hposition = float4(planar_pos, 0.0, 1.0);

  // calc steigung for aufbrechen
#ifdef PS3_IMPL
  float steigung = saturate(nrm4.z);
#else
  float steigung = saturate(dot(nrm4.xyz, float3(0.0, 0.0, 1.0)));
#endif

  // pass texcoords
	O.texcoord = float4(I.texcoord.xyy, steigung);
	O.texcoord.x = O.texcoord.x*param.x+param.y;
	O.texcoord.y = O.texcoord.y*param.x+param.y;

	return O;
}

#include "normalmap.shader"

fragout mainPS(pixdata I,
		uniform sampler2D texture0,		// Diff
		uniform sampler2D texture1,
		uniform sampler2D texture2,
		uniform sampler2D texture3,
		uniform sampler2D texture4,
		uniform sampler2D texture5,		// Nrm
		uniform sampler2D texture6,
		uniform sampler2D texture7,
		uniform sampler2D texture8,
		uniform sampler2D texture9,
		uniform sampler2D texture10,	// alpha
		uniform sampler2D texture11)	// relax
{
	fragout O;

	// sample all needed
	s2half4 t0_diff = tex2D(texture0, I.texcoord.xy);
	s2half4 t1_diff = tex2D(texture1, I.texcoord.xy);
	s2half4 t2_diff = tex2D(texture2, I.texcoord.xy);
	s2half4 t3_diff = tex2D(texture3, I.texcoord.xy);
	s2half4 sb_diff = tex2D(texture4, I.texcoord.xy);
	s2half4 t0_nrm = ReadNormalMap2D(texture5, I.texcoord.xy);
	s2half4 t1_nrm = ReadNormalMap2D(texture6, I.texcoord.xy);
	s2half4 t2_nrm = ReadNormalMap2D(texture7, I.texcoord.xy);
	s2half4 t3_nrm = ReadNormalMap2D(texture8, I.texcoord.xy);
	s2half4 sb_nrm = ReadNormalMap2D(texture9, I.texcoord.xy);
	s2half4 alpha_mask = tex2D(texture10, I.texcoord.xy);
	s2half4 relax_limit = tex2D(texture11, I.texcoord.xy);

  // standard or sub for base layer?
	float4 spec_comp;
	if(I.texcoord.w > relax_limit.w)
	{
		O.col[0] = t0_diff;
		O.col[1] = t0_nrm;
		spec_comp = float4(t0_diff.w, t1_diff.w, t2_diff.w, t3_diff.w);
	}
	else
	{
		O.col[0] = sb_diff;
		O.col[1] = sb_nrm;
		spec_comp = float4(sb_diff.w, t1_diff.w, t2_diff.w, t3_diff.w);
	}

	O.col[0] *= alpha_mask.x;
	O.col[1] *= alpha_mask.x;
	
	// add all other normals
	O.col[1] += alpha_mask.y * t1_nrm + alpha_mask.z * t2_nrm + alpha_mask.w * t3_nrm;
	// add all other layers
	O.col[0] += alpha_mask.y * t1_diff + alpha_mask.z * t2_diff + alpha_mask.w * t3_diff;
	
	// Specular!
	O.col[1].w = dot(alpha_mask, spec_comp);

	// re-normalize and 'intensify'
	O.col[1].xyz = normalize(O.col[1].xyz - float3(0.0, 0.0, 0.2)); 

	// put back in half-space
	O.col[1].xyz = 0.5 * (O.col[1].xyz + float3(1.0, 1.0, 1.0));
		
  return O;
}

