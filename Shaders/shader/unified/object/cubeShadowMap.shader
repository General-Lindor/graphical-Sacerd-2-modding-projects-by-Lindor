// granny2 object cubeshadowmap

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
	float4 li_to_pix_w : TEXCOORD1;
};

struct fragout {
	float4 col        : COLOR;
};

pixdata mainVS(appdata I,
    uniform float4x4 lightMatrix,
    uniform float4x4 worldMatrix,
    uniform float4   light_pos)
{
	pixdata O;
	float4 pos4 = float4(I.position, 1.0);
	float4 nrm4 = float4(I.normal, 0.0);

	// vertex pos
	O.hposition = mul(pos4, lightMatrix);

	// convert vertex pos from objspace to worldspace
	float4 v_pos_w = mul(pos4, worldMatrix);
	// pass light-to-pixel to fragment shader
	O.li_to_pix_w = v_pos_w - light_pos;

	// pass texcoords to fragment shader
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform float4    light_data)
{
	fragout O;

	
	// need opacity-channel, since this is shadowmapping!
	float opacity;
#ifndef IS_OPAQUE
	float4 tex0 = tex2D(texture0, I.texcoord0.xy);
	opacity     = tex0.a;
  clip(opacity-0.5f);
#else
  opacity = 1.0;
#endif


#ifdef SM1_1
  // pass it to texture
	O.col = float4(1.0, 1.0, 1.0, opacity);
#else


  // square distance of scaled
	float3 li_to_pix_w_s = light_data.z * I.li_to_pix_w.xyz;
	float sq_dist = saturate(dot(li_to_pix_w_s, li_to_pix_w_s));

	// endcode it in rgb!!
	float3 depth_encoded = sq_dist * float3(1.0, 256.f, 256.f * 256.f);
	// do not put the .x component through the frac, this gives 0.0 for 1.0 -> ERRORs
	depth_encoded.yz = frac(depth_encoded.yz);

	// pass it to texture
	O.col = float4(depth_encoded, opacity);

#endif
	return O;
} 
