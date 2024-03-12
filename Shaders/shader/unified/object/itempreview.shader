// itempreview

#include "extractvalues.shader"

struct appdata {
	float3 position     : POSITION;
	float3 normal       : NORMAL;
	float3 tangent      : TANGENT;
	float3 binormal     : BINORMAL;
	float2 texcoord     : TEXCOORD0;
	float2 data         : TEXCOORD1;
};

struct pixdata {
	float4 hposition    : POSITION;
	float4 texcoord0    : TEXCOORD0;
	float4 tan_to_view0 : TEXCOORD1;
	float4 tan_to_view1 : TEXCOORD2;
	float4 tan_to_view2 : TEXCOORD3;
};

struct fragout {
	float4 col         : COLOR;
};

pixdata mainVS(appdata I,
  uniform float4x4 worldViewProjMatrix,
	uniform float4x4 lightMatrix)
{
	pixdata O;
	
	float4 pos4 = float4(I.position, 1.0);

	// vertex pos
	O.hposition = mul(pos4, worldViewProjMatrix);

	// build tangentToObject space
	float4x4 tangentToObj;
	tangentToObj[0] = float4(-1.0 * I.tangent, 0.0);
	tangentToObj[1] = float4(-1.0 * I.binormal, 0.0);
	tangentToObj[2] = float4(I.normal, 0.0);
	tangentToObj[3] = float4(0.0, 0.0, 0.0, 1.0);

  // build tangent to view matrix
	float4x4 tangentToView;
  tangentToView = mul(tangentToObj, lightMatrix);

	// pass to fragment
	O.tan_to_view0 = tangentToView[0];
	O.tan_to_view1 = tangentToView[1];
	O.tan_to_view2 = tangentToView[2];

	// texture coords
	O.texcoord0 = I.texcoord.xyyy;

	return O;
}

fragout mainPS(pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D texture1,
    uniform sampler2D texture2,
    uniform sampler2D texture3, 
    uniform float4    pix_data_array[2])
{  
	fragout O;

	// get texture values
	s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));
	s2half4 tex3 = tex2D(texture3, I.texcoord0.xy);

  // if this item is not equipped then skip drawing the skin
  clip( - tex3.a*pix_data_array[0].x ); 
   // build matrix to tranform from tangent to view-space
  float3x3 tangent_to_view;
  tangent_to_view[0] = normalize(I.tan_to_view0.xyz);
  tangent_to_view[1] = normalize(I.tan_to_view1.xyz);
  tangent_to_view[2] = normalize(I.tan_to_view2.xyz);

  // build normal
//  s2half3 nrm = normalize(tex2.xyz - s2half3(0.5, 0.5, 0.5));
  s2half3 nrm      = tex2;
  s2half3 nrm_wrld = mul(nrm, tangent_to_view);

  // build color from normal
  s2half3 nem_col = 0.5 * (nrm_wrld + s2half3(1.0, 1.0, 1.0));

  // 1st preview texture (rgb=diffuse, a=alpha)
  clip(tex0.a-0.1);

  O.col = tex0;
#if LAYER_BIT0
  // 2nd preview texture (rgb=nrmal, a=glow)
//  O.col = float4(nem_col, tex1.a);
  O.col = float4(nem_col, tex1.a);
#endif
#if LAYER_BIT1
  // 3nd preview texture (r=const diffuse, g=specular)
  O.col = float4(0.2 + 0.5 * saturate(dot(nrm_wrld, normalize(float3(0.5, 0.5, 1.0)))), dot(tex1.xyz, float3(0.222, 0.707, 0.071)), 0.0, 0.0);
#endif

	return O;
} 
