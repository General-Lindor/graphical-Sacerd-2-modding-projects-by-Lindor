 sampler2D pos_scale_tex  : register(s0);
 sampler2D scale_rot_tex  : register(s1);
 sampler2D rot_sgn_ID_tex : register(s2);

struct instancedata {
	float3x4 positionTransform;
	float3x3 directionTransform;
	float2   variationUVOffset;
};

instancedata extractInstanceData(	float  instanceID,
									float  instanceTextureWH,
									float2 variationsWH
									)
{
	instancedata result;
	
	// Calculate the texture coords for the samples
	float numRows, rowFraction;
	rowFraction = modf(instanceID/instanceTextureWH,numRows);
	
	float4 uv = float4(rowFraction + 0.5f/instanceTextureWH, (numRows + 0.5f)/instanceTextureWH,0.f,0.f);
	float4 t0 = tex2Dlod(pos_scale_tex, uv);
	float4 t1 = tex2Dlod(scale_rot_tex, uv);
	float4 t2 = tex2Dlod(rot_sgn_ID_tex, uv);
	
	// xy of first 2 rotation rows are as-is
	float3 rot0, rot1;
	rot0.xy = t1.zw;
	rot1.xy = t2.xy;
	
	// z is computed using Pythag + encoded sign
	rot0.z = sqrt(1.f - dot(rot0.xy,rot0.xy));
	rot1.z = sqrt(1.f - dot(rot1.xy,rot1.xy));
	
	// encoding is 0-3, MSB for rot0, LSB for rot1
	float rot0sgn = t2.z < 1.5 ? -1.f : 1.f;
	float rot1sgn = (t2.z - 1.f - rot0sgn) < 0.5 ? -1.f : 1.f;
	rot0.z *= rot0sgn;
	rot1.z *= rot1sgn;
	
	float3 rot2 = cross(rot0,rot1);
	
	float3 scale;
	scale.x = t0.w;
	scale.yz = t1.xy;
	
	// The positional transform
	result.positionTransform[0].xyz = scale * rot0;
	result.positionTransform[1].xyz = scale * rot1;
	result.positionTransform[2].xyz = scale * rot2;
	result.positionTransform[0].w = t0.x;
	result.positionTransform[1].w = t0.y;
	result.positionTransform[2].w = t0.z;
	
	// Note that we use the usual rule for rotating directions i.e. transpose(inverse(T))
	float3 invScale = 1.f/scale;
	result.directionTransform[0] = invScale * rot0;
	result.directionTransform[1] = invScale * rot1;
	result.directionTransform[2] = invScale * rot2;
	
	// Variation offset
	float wholeRows;
	result.variationUVOffset.x = modf(t2.w/variationsWH.x, wholeRows);
	result.variationUVOffset.y = wholeRows/variationsWH.y;
	
	return result;
}
