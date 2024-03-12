#ifndef ITEMPREVIEW_STD_H
#define ITEMPREVIEW_STD_H
  struct item_pixdata {
    float4 hposition   : POSITION;
    float4 texcoord0   : TEXCOORD0;
    float3 tan_to_view0 : TEXCOORD5;
    float3 tan_to_view1 : TEXCOORD6;
    float3 tan_to_view2 : TEXCOORD7;
  };
  item_pixdata mainVS(appdata I,
    uniform float4x4 worldViewProjMatrix,
    uniform float4x4 invWorldMatrix,
    uniform float4   light_pos,
    uniform float4   camera_pos,
    uniform float4   zfrustum_data,
    uniform float4   fog_data,
    uniform float4x4 lightMatrix )
  {
	  item_pixdata O;
  	
	  float4 pos4 = float4(I.position, 1.0);
	  float4 nrm4 = float4(I.normal, 0.0);

	  // vertex pos
	  O.hposition = mul(pos4, worldViewProjMatrix);

	  // build object-to-tangent space matrix
	  float3x3 objToTangentSpace;
	  objToTangentSpace[0] = -1.0 * I.tangent;
	  objToTangentSpace[1] = -1.0 * I.binormal;
	  objToTangentSpace[2] = I.normal;
	  
	  objToTangentSpace = mul(objToTangentSpace,lightMatrix);

    // build tangent to view matrix
    O.tan_to_view0 = objToTangentSpace[0];
    O.tan_to_view1 = objToTangentSpace[1];
    O.tan_to_view2 = objToTangentSpace[2];

	  // texture coords
	  O.texcoord0 = I.texcoord.xyyy;

	  return O;
  }

  struct item_out {
    float4 col[2]      : COLOR;
  };

  item_out mainPS(item_pixdata I,
    uniform sampler2D texture0,
    uniform sampler2D texture1,
    uniform sampler2D texture2,
    uniform sampler2D texture3,
    uniform float4    pix_data_array) 
  {
	  item_out O;
	  // get texture values
	  s2half4 tex3 = tex2D(texture3, I.texcoord0.xy);
#ifdef ITEMPREVIEW_CFG_CLIPSKIN
    // if this item is not equipped then skip drawing the skin
    if( pix_data_array.x )
  	  clip( - tex3.a );
#endif
	  s2half4 tex0 = tex2D(texture0, I.texcoord0.xy);
	  s2half4 tex1 = tex2D(texture1, I.texcoord0.xy);
	  s2half4 tex2 = decode_normal(tex2D(texture2, I.texcoord0.xy));
#ifdef IS_OPAQUE
    tex0.a = 1;
#endif
#ifdef ITEMPREVIEW_CFG_GLAS
  #ifdef LAYER_BIT0
    tex0.a = 1;
  #endif
  #ifdef LAYER_BIT1
    tex0.a = 1;
  #endif
#endif

    clip(tex0.a-0.1);

    O.col[0] = calcItemPreviewColor(I.tan_to_view0,I.tan_to_view1,I.tan_to_view2,
                                    tex0,tex1,tex2);
    O.col[1] = float4(0,0,0,1);
	  return O;
  } 
#endif //ITEMPREVIEW_STD_H
