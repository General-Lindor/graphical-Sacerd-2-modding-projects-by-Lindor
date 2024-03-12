#include "extractvalues.shader"
// splinewurms

struct appdata {
	float3 position   : POSITION;
	float4 texcoord   : TEXCOORD0;
	float4 data       : TEXCOORD1;
	float4 color      : COLOR0;
};

struct pixdata {
	float4 hposition  : POSITION;
	float4 texcoord0  : TEXCOORD0;
};

struct fragout {
	float4 col[2]      : COLOR;
};

#define PI 3.1415926535897932384626433832795

pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 worldMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4   vtx_data_array[16],
   	uniform float4   vtx_data2_array[16],
    uniform float4   camera_pos,
    uniform float4   weather_pos,
    uniform float4   param)
{
	pixdata O;

	// give usefull names
	float shrinkStartEnd = weather_pos.x;
	float shrinkStartEndStr = weather_pos.y;

	// how many knots are there?
	float knot_scale = param.x - 1.1;

	// where on spline? find knot and fraction
	float knot_id = knot_scale * saturate(-param.y * I.data.y + param.w);
	float t = frac(knot_id);
	// get knot points and tangents and put'em in matrix
	float4x4 pt;
	pt[0] = vtx_data_array[knot_id];
	pt[1] = vtx_data_array[knot_id + 1.0];
	pt[2] = vtx_data2_array[knot_id];
	pt[3] = vtx_data2_array[knot_id + 1.0];
#ifdef PS3_IMPL
        pt=transpose(pt); //TB:HACK!
#endif
	// "powers" vector
	float4 powers = float4(t * t * t, t * t, t, 1.0);
	// evaluate point
	float4 pnt0 = mul(powers, worldMatrix);
	pnt0 = mul(pnt0, pt);

	
	// now we need another point to determine the spline normal
	// !!! DAMN! NO IDEA HOW TO DO THIS THE RIGHT WAY!!!
	knot_id = knot_scale * saturate(-param.y * I.data.y + 0.05 + param.w);
	t = frac(knot_id);
	pt[0] = vtx_data_array[knot_id];
	pt[1] = vtx_data_array[knot_id + 1.0];
	pt[2] = vtx_data2_array[knot_id];
	pt[3] = vtx_data2_array[knot_id + 1.0];
#ifdef PS3_IMPL
        pt=transpose(pt); //TB:HACK!
#endif

	powers = float4(t * t * t, t * t, t, 1.0);
	float4 pnt1 = mul(powers, worldMatrix);
	pnt1 = mul(pnt1, pt);

	float4 c_pos_obj = mul(camera_pos, invWorldMatrix);
	// compute offset, which must be perpendicular to viewer and spline-tangent
	float3 pnt_offset = cross(c_pos_obj.xyz - pnt0.xyz, pnt1.xyz - pnt0.xyz);
	pnt_offset = normalize(pnt_offset);
	
	// calc extension
	float ext = param.z * I.data.x * lerp(1.0, pow(sin(PI * I.data.y), shrinkStartEndStr), shrinkStartEnd);
	
	// this is it!
	float4 pos4 = float4(pnt0.xyz + ext * pnt_offset, 1.0);

	// transform into proj-space
	O.hposition = mul(pos4, worldViewProjMatrix);

	// pass texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout_t mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform float4    light_col_amb,
    uniform float4    param)
{
	fragout_t O;
	
	// tex
#ifdef SM1_1
  	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  O.col0 = tex0/* * light_col_amb*/;
#else
  	s2half4 tex0 = tex2D(texture0, float2(1.0, param.x) * I.texcoord0.xy + float2(0.0, param.y));
	  O.col0 = tex0 * light_col_amb;
	  O.col1 = 0.4 * param.z * tex0 * light_col_amb;
#endif

	return O;
} 
